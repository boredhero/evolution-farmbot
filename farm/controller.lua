-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local S=require('farm.lib.store')
local W=require('farm.lib.world')
local P=require('farm.lib.path')
local C=require('farm.lib.crops')
local N=require('farm.lib.network')
local Seeds=require('farm.lib.seeds')
local Garden=require('farm.lib.garden')
local Metrics=require('farm.lib.metrics')
local Vines=require('farm.lib.vines')
local Performance=require('farm.lib.performance')
local Journal=require('farm.lib.journal')
local Traffic=require('farm.lib.traffic')
local Mailbox=require('farm.lib.mailbox')
local Dashboard=require('farm.dashboard')
local CommandHistory=require('farm.lib.command_history')
local Players=require('farm.lib.players')
local Hardware=require('farm.lib.hardware')
local Help=require('farm.lib.help')
local Batches=require('farm.lib.batches')
local SeedRecipes=require('farm.lib.seed_recipes')
local Compost=require('farm.lib.compost')
local Growth=require('farm.lib.growth')
local Controller={}
function Controller.run(cfg)
  U.openModem()
  local protocol=N.protocol(cfg)
  local state=S.load('farm/data/controller',{active=false,history={},excluded={}})
  local journal=Journal.new('farm/data/controller',state)
  state.history=state.history or {};state.excluded=state.excluded or {}
  state.batches=state.batches or {};state.growth=state.growth or {}
  if state.batches.schema~=2 then state.batches={schema=2} end
  state.batches.inflight={};state.batches.repairs={} -- Lease tokens are renewed after a controller restart; unfinished plants remain pending.
  local garden=Garden.new(state.garden);state.garden=garden.data
  local metrics=Metrics.new(state.metrics,U.now());state.metrics=metrics.data
  local dashboard=Dashboard.new(state.displays);state.displays=dashboard.views
  if not state.allHeightMap then
    for _,v in pairs(state.displays) do if v.role=='map' then v.layer=nil;v.zoom=1;v.cx=nil;v.cz=nil end end
    state.allHeightMap=true
  end
  local installedVersion=Dashboard.installedVersion()
  local dashboardError
  local world=W.new(cfg.center,cfg.radius)
  local jobs,workers,leases,obstacles,responses,cache={},{},{},{},{},{}
  local craftLocks={}
  local function hasCrafter()
    return state.crafters and #state.crafters>0
  end
  local function plantingInventory(inventory)
    local out={};for item,count in pairs(inventory or {}) do out[item]=count end
    if hasCrafter() then
      for seed in pairs(SeedRecipes.recipes) do if SeedRecipes.find(seed,out) then out[seed]=math.max(out[seed] or 0,1) end end
    end
    return out
  end
  local scanAt,lastScan,scanError=0,0,'Waiting for first scan'
  local epoch=0;local hits=0;local scanBusy=false;local lastSave=0
  local stopping=false
  local boot=tostring(U.now());local leaseSerial=0
  local snapshot=S.load('farm/data/map',nil)
  if snapshot and snapshot.radius==cfg.radius and U.equal(snapshot.center,cfg.center) then
    world.packed=snapshot.packed -- No jobs dispatched until a fresh scan succeeds.
  end
  local scanner=peripheral.find('geo_scanner') or peripheral.find('geoScanner')
  assert(scanner,'Attach the Geo Scanner directly to the controller.')
  local scan=scanner.scanBlocks or scanner.scan
  assert(type(scan)=='function','Geo Scanner has no supported scan method.')
  local performance=Performance.new();local profileSaved=U.now()
  local function save()
    local started=U.now()
    metrics:tick(U.now())
    -- Prune long-absent plants so abandoned crops do not fill the disk.
    local cutoff=U.now()-7*86400
    for k,h in pairs(state.history) do if (h.seen or 0)<cutoff then state.history[k]=nil end end
    journal:checkpoint();lastSave=U.now();performance:record('save',started)
  end
  local function persist(job)
    local started=U.now();metrics:tick(U.now());journal:record(job);performance:record('journal',started)
  end
  local function summary()
    local total,unknown,active=0,0,0
    for _,j in pairs(jobs) do total=total+1;if j.mode=='probe' then unknown=unknown+1 end end
    for _,w in pairs(workers) do if U.now()-w.seen<30 then active=active+1 end end
    return {active=state.active,crops=total,unknown=unknown,workers=active,
      scanAge=lastScan>0 and math.floor(U.now()-lastScan) or -1,error=scanError,
      cachedHits=hits,epoch=epoch,center=cfg.center,radius=cfg.radius,debts=garden:debts()}
  end
  local function avoidFor(id,planned)
    local now=U.now();local avoid=Traffic.avoid(workers,id,now,planned)
    for k,untilTime in pairs(obstacles) do
      if untilTime>now then avoid[k]=true else obstacles[k]=nil end
    end
    return avoid
  end
  local function route(id,start,goals)
    local started=U.now()
    local avoid=avoidFor(id,true)
    local parts={U.key(start)};for _,g in ipairs(goals) do parts[#parts+1]=U.key(g) end
    local key=table.concat(parts,'|')
    local cached=cache[key]
    if cached and P.valid(world,start,cached.path,avoid) then hits=hits+1;cached.used=U.now();performance:record('route_cached',started);return cached.path,cached.goal end
    local path,goal,expanded=P.find(world,start,goals,{avoid=avoid,yieldFn=U.yield})
    if not path then
      local relaxed=avoidFor(id,false);local changed=false
      for k in pairs(avoid) do if not relaxed[k] then changed=true;break end end
      if changed then
        local extra;path,goal,extra=P.find(world,start,goals,{avoid=relaxed,yieldFn=U.yield});expanded=(expanded or 0)+(extra or 0)
      end
    end
    performance.expanded=(performance.expanded or 0)+(expanded or 0)
    if U.now()-started>0.25 then
      performance.slowRoutes=performance.slowRoutes or {}
      local recent=performance.slowRoutes
      recent[#recent+1]={start=U.copy(start),goals=goals,expanded=expanded,ms=(U.now()-started)*1000,reason=not path and goal or nil}
      if #recent>8 then table.remove(recent,1) end
    end
    if path then
      if #parts>0 then
        local count=0;for _ in pairs(cache) do count=count+1 end
        if count>=128 and not cache[key] then
          local oldest,used;for k,r in pairs(cache) do if not used or (r.used or 0)<used then oldest,used=k,r.used or 0 end end
          if oldest then cache[oldest]=nil end
        end
      end
      cache[key]={path=path,goal=goal,used=U.now()};performance:record('route',started);return path,goal
    end
    performance:record('route_failed',started);return nil,goal
  end
  local function fresh() return lastScan>0 and U.now()-lastScan<cfg.scanInterval*3 end
  local function release(id)
    Batches.release(state.batches,id)
    for k,l in pairs(leases) do if l.owner==id then leases[k]=nil end end
  end
  local function handle(id,m)
    local d=m.data
    workers[id]=workers[id] or {}
    local w=workers[id];w.seen=U.now()
    metrics:report(id,d.stats,U.now())
    if d.pos and not d.preview then Traffic.update(w,d.pos,U.now()) end
    if d.fuel then w.fuel=d.fuel end
    if d.status then w.status=tostring(d.status):sub(1,120) end
    if d.inventory then w.inventory=d.inventory end
    for _,lock in pairs(craftLocks) do if lock.owner==id then lock.untilTime=U.now()+120 end end
    for k,l in pairs(leases) do if l.owner==id then
      l.untilTime=U.now()+120
      local p=garden.data.plots[k]
      if p and p.intent and p.intent.token==l.token then p.intent.expires=l.untilTime end
    end end
    if m.kind=='heartbeat' then return {ok=true}
    elseif m.kind=='hello' then
      if not world:inside(d.dock) then return nil,'Dock is outside the scanner cube' end
      w.dock=d.dock;w.name=d.name;w.seedBuffer=d.seedBuffer;w.dryRun=d.dryRun
      w.remoteMode=d.remoteMode==true
      if not cfg.sharedStations and d.stations and d.stations.output then
        cfg.sharedStations=d.stations;S.save('farm/config',cfg)
      end
      return {active=state.active,center=cfg.center,radius=cfg.radius}
    elseif m.kind=='seed_plan' then
      local stock=Seeds.stock(cfg.seedSource);local needed={};local living,debts=garden:counts()
      for seed in pairs(garden.data.seeds) do
        local target=math.max(16,math.min(64,(living[seed] or 0)+(debts[seed] or 0)*2))
        needed[seed]=math.max(0,target-(stock[seed] or 0))
      end
      local batch=state.batches.workers and state.batches.workers[tostring(id)]
      local keep=garden:reserves(batch);local seeds={}
      for item in pairs(garden.data.seeds) do seeds[item]=true end
      for _,p in pairs(garden.data.plots) do if p.job.mode=='use' and p.job.item then
        seeds[p.job.item]=true;keep[p.job.item]=1
      end end
      local ingredients={}
      for seed,amount in pairs(keep) do
        if ((w.inventory or {})[seed] or 0)<amount then
          local recipe=SeedRecipes.find(seed,w.inventory or {})
          if recipe then ingredients[recipe.item]=true end
        end
      end
      for item in pairs(ingredients) do seeds[item]=true;keep[item]=math.max(keep[item] or 0,1) end
      local compost=Compost.plan(garden,state.batches,leases,w.inventory or {},keep,stock)
      return {seeds=seeds,needed=needed,keep=keep,compost=compost}
    elseif m.kind=='bank_store' then
      if not w.dock or not U.equal(d.pos,w.dock) then return nil,'Seed storage requires worker at its dock' end
      return Seeds.store(cfg.seedSource,w.seedBuffer)
    elseif m.kind=='recover' then
      local p=d.job and garden.data.plots[d.job.key]
      if p and p.version==d.job.version and p.intent and p.intent.owner==id then
        p.intent=nil;p.updated=U.now();persist(d.job)
      end
      release(id);scanAt=0
      return {ok=true} -- Existing durable debt survives; never resurrect an obsolete crop plan.
    elseif m.kind=='begin' then
      if not state.active or not fresh() then return nil,'Paused or waiting for fresh survey' end
      local l=d.job and leases[d.job.key]
      if not l or l.owner~=id or l.token~=d.token then return nil,'Crop assignment is no longer valid' end
      local answer,why=garden:begin(l.job,id,l.token,(d.inventory[l.job.seed] or 0)>0,U.now())
      if answer then persist(l.job) end -- Write-ahead debt must reach disk BEFORE authorizing a dig.
      return answer,why
    elseif m.kind=='seed' then
      if not w.dock or not U.equal(d.pos,w.dock) then return nil,'Seed delivery requires the worker at its dock' end
      for _,l in pairs(leases) do
        if l.owner==id and l.token==d.token and l.untilTime>=U.now() then
          local item=l.job.seed or l.job.item
          if not item then return nil,'This job does not need a planting/interaction item' end
          return Seeds.deliver(cfg.seedSource,w.seedBuffer,item)
        end
      end
      return nil,'No active crop assignment for seed delivery'
    elseif m.kind=='compost_station' then
      local best,distance
      for _,b in pairs(world.blocks) do if b.name=='minecraft:composter' then
        local dist=U.distance(d.pos,b)
        if not distance or dist<distance then best=b;distance=dist end
      end end
      return best and {pos=U.copy(best)} or {}
    elseif m.kind=='craft_station' then
      local best,distance
      for key,b in pairs(world.blocks) do if b.name=='minecraft:crafter' then
        local lock=craftLocks[key]
        if (not d.target or U.equal(d.target,b)) and (not lock or lock.owner==id or lock.untilTime<U.now()) then
          local dist=U.distance(d.pos,b)
          if not distance or dist<distance then best=b;distance=dist end
        end
      end end
      if not best then return nil,'No available Crafter in scanner coverage' end
      craftLocks[U.key(best)]={owner=id,untilTime=U.now()+120}
      return {pos=U.copy(best)}
    elseif m.kind=='craft_done' then
      for key,lock in pairs(craftLocks) do if lock.owner==id then craftLocks[key]=nil end end
      return {ok=true}
    elseif m.kind=='control' then
      return {recover=cfg.workerRecover and cfg.workerRecover[tostring(id)]}
    elseif m.kind=='step' then return Traffic.claim(workers,id,d.pos,d.target,U.now())
    elseif m.kind=='status' then return summary()
    elseif m.kind=='blocked' then
      if d.block and world:inside(d.block) then
        local moving=Traffic.turtle(d.name)
        obstacles[U.key(d.block)]=U.now()+(moving and 1 or 20);w.nextPos=nil
        if d.name then world:observe(d.block,{name=d.name});cache={};epoch=epoch+1;if not moving then scanAt=0 end end
      end
      return {ok=true}
    elseif m.kind=='route' then
      if not fresh() then return nil,'Waiting for a fresh scanner map' end
      local path,goal=route(id,d.pos,d.goals or {})
      if not path then return nil,goal end
      if not d.preview then w.route=path;w.routeStart=U.copy(d.pos) end
      return {path=path,goal=goal}
    elseif m.kind=='cleared_vine' then
      local l=d.job and leases[d.job.key]
      local j=l and l.job
      if not l or l.owner~=id or not Vines.allowed(j,d.block,{name='minecraft:vine'}) then return nil,'No matching vine-clearance assignment' end
      world:observe(d.block,false);obstacles[U.key(d.block)]=nil;cache={};epoch=epoch+1
      return {ok=true}
    elseif m.kind=='result' then
      local j=d.job
      local l=j and leases[j.key]
      if not l or l.owner~=id or l.token~=d.token then return {ok=true,stale=true} end
      leases[j.key]=nil;Batches.finished(state.batches,id,j)
      if d.after~=nil then
        world:observe(j.pos,d.after)
        if d.outcome=='harvested' and j.mode=='cane' and j.rootY then
          for y=j.rootY+1,j.pos.y do world:observe({x=j.pos.x,y=y,z=j.pos.z},false) end
        end
        epoch=epoch+1 -- Cached routes are checked against current occupancy before reuse.
      end
      garden:finish(j,d.token,d.after,world,cfg.customCrops,U.now())
      local h=state.history[j.key] or {interval=60}
      Growth.record(state.growth,h,j,d,U.now())
      h.seen=U.now();h.name=d.after and d.after.name or j.name;h.outcome=d.outcome;h.detail=d.detail;h.state=d.state
      if d.after~=nil then h.observed=d.after or nil;h.observedAt=U.now() end
      metrics:record(j,d.outcome,d.after,U.now(),d.detail,id)
      if d.outcome=='harvested' then
        h.harvests=(h.harvests or 0)+1
        h.interval=math.max(15,math.floor((h.interval or 60)*0.85))
      elseif d.outcome=='growing' then h.interval=math.min(600,math.floor((h.interval or 60)*1.3)) end
      if d.outcome=='deferred' then h.harvests=(h.harvests or 0)+1;h.due=0 end
      h.due=U.now()+((d.outcome=='unsupported' or d.outcome=='unsupported_rope') and 3600 or h.interval or 60)
      state.history[j.key]=h
      if d.outcome=='deferred' or d.outcome=='changed' then h.due=0
      elseif j.repair then h.due=U.now()+5 end
      if d.outcome=='changed' then jobs[j.key]=nil end
      if d.outcome=='harvested' and (j.mode=='fruit' or j.mode=='cane' or j.mode=='rice' or j.mode=='upper') then jobs[j.key]=nil end
      persist(j);return {ok=true}
    elseif m.kind=='job' then
      if type(d.dryRun)=='boolean' then w.dryRun=d.dryRun end
      local desired=cfg.workerModes and cfg.workerModes[tostring(id)]
      local assigned=false
      for _,l in pairs(leases) do if l.owner==id and l.untilTime>=U.now() then assigned=true end end
      if w.remoteMode and desired~=nil and desired~=w.dryRun and not assigned then
        return {mode=desired and 'dry' or 'live'}
      end
      if not state.active or not fresh() then return {wait=3,reason=scanError or 'Paused',returnHome=not state.active} end
      -- Retries/reconnections recover the existing assignment, never acquire a second.
      for k,l in pairs(leases) do
        if l.untilTime<U.now() then leases[k]=nil;Batches.release(state.batches,l.owner)
        elseif l.owner==id then
          Vines.scan(l.job,world)
          local path,goal=route(id,d.pos,Vines.goals(l.job))
          if path then w.route=path;w.routeStart=U.copy(d.pos);return {job=l.job,path=path,goal=goal,token=l.token} end
          return {wait=10,reason='Assigned crop currently unreachable'}
        end
      end
      local options={};local _,debts=garden:counts()
      local stock=Seeds.stock(cfg.seedSource)
      local fleet={};local inspectOnly=w.dryRun
      for _,other in pairs(workers) do if U.now()-other.seen<30 then
        inspectOnly=inspectOnly or other.dryRun
        for item,count in pairs(other.inventory or {}) do fleet[item]=(fleet[item] or 0)+count end
      end end
      local function due(j,h)
        -- Only physical route failures cool down. Growth timers never hide a plant from its round.
        return not h or h.outcome~='unreachable' or (h.due or 0)<=U.now()
      end
      local all={}
      for _,j in ipairs(garden:tasks(plantingInventory(fleet),stock,U.now(),inspectOnly)) do
        local h=state.history[j.key]
        if not state.excluded[j.key] and not leases[j.key] and due(j,h) then
          local ready=h and h.observed and C.ready(j,h.observed)==true
          all[#all+1]={job=j,ready=ready}
        end
      end
      for _,j in ipairs(garden:tasks(plantingInventory(w.inventory),stock,U.now(),w.dryRun)) do
        local k=j.key
        local h=state.history[k]
        if not state.excluded[k] and not leases[k] and due(j,h) then
          local bonus=j.repair and 10000 or (j.seed and (debts[j.seed] or 0)>0 and 1000 or 0)
          options[#options+1]={job=j,score=U.distance(d.pos,j.pos)-bonus-(d.resume==j.key and 100000 or 0)}
        end
      end
      for key,p in pairs(garden.data.plots) do
        if p.intent and state.batches.pending and state.batches.pending[key] then all[#all+1]={job=p.job} end
      end
      options=Batches.order(state.batches,all,options,id)
      for i=1,math.min(12,#options) do
        local j=options[i].job
        Vines.scan(j,world)
        local path,goal=route(id,d.pos,Vines.goals(j))
        if path then
          leaseSerial=leaseSerial+1
          local token=tostring(id)..':'..boot..':'..leaseSerial..':'..j.key
          leases[j.key]={owner=id,untilTime=U.now()+120,job=j,token=token}
          Batches.assigned(state.batches,id,j)
          w.route=path;w.routeStart=U.copy(d.pos);persist() -- Persist round ownership before the worker leaves or unloads.
          return {job=j,path=path,goal=goal,token=token}
        end
        state.history[j.key]=state.history[j.key] or {interval=60}
        state.history[j.key].due=U.now()+120
        state.history[j.key].seen=U.now()
        state.history[j.key].outcome='unreachable'
        if goal=='Start outside scanner coverage' then Batches.skip(state.batches,j.key) end
      end
      return {wait=3,reason='Waiting for next available crop'}
    elseif m.kind=='release' then release(id);return {ok=true} end
    return nil,'Unknown request'
  end
  -- Answers pairing probes on the fixed discovery protocol, so a worker never
  -- has to be told this farm's network name by hand.
  local function discoverLoop()
    while true do pcall(N.answer,cfg) end
  end
  local mailbox=Mailbox.new({protocol=protocol,allowed=cfg.allowed,handle=handle,performance=performance})
  local function networkLoop() mailbox:receive() end
  local function requestLoop() mailbox:work() end
  local function scanLoop()
    while true do
      if U.now()>=scanAt and not scanBusy then
        scanBusy=true
        local started=U.now()
        local ok,data,err=pcall(scan,cfg.radius)
        if ok and type(data)=='table' and #data>0 then
          local nextWorld=W.new(cfg.center,cfg.radius)
          nextWorld:ingest(data,U.yield)
          local nextJobs=C.discover(nextWorld,cfg.customCrops,U.yield)
          if nextWorld.packed~=world.packed then cache={};epoch=epoch+1
          else nextWorld.components=world.components;nextWorld.revision=world.revision end
          garden:scan(nextWorld,nextJobs,started,U.now(),cfg.customCrops)
          for k,h in pairs(state.history) do
            local p=garden.data.plots[k]
            if p and h.name~=p.job.name then state.history[k]=nil end
          end
          world=nextWorld;jobs=nextJobs;lastScan=U.now();scanError=nil
          state.crafters={}
          for _,b in pairs(world.blocks) do if b.name=='minecraft:crafter' then state.crafters[#state.crafters+1]=U.copy(b) end end
          metrics.data.scans=metrics.data.scans+1
          S.save('farm/data/map',world:snapshot())
          save()
        else scanError=tostring(ok and (err or 'Empty scan rejected') or data) end
        scanAt=U.now()+cfg.scanInterval;scanBusy=false
      end
      if U.now()-lastSave>60 then save() end
      if U.now()-profileSaved>30 then S.save('farm/data/performance',{since=performance.since,untilTime=U.now(),samples=performance.samples,expanded=performance.expanded,slowRoutes=performance.slowRoutes});profileSaved=U.now() end
      sleep(1)
    end
  end
  local function statusLines()
    local s=summary()
    local lines={'EVOLUTION FARMBOT',state.active and 'RUNNING' or 'PAUSED',
      'Crops: '..s.crops..'  Workers: '..s.workers,
      'Remembered replant gaps: '..s.debts,
      'Unknown crop rules: '..s.unknown,'Last scan: '..s.scanAge..'s ago',
      'Cached routes used: '..hits}
    lines[#lines+1]='Cycle '..tostring(state.batches.cycle or 0)..' | crop round '..tostring(state.batches.round or 0)
    lines[#lines+1]='Crafters detected: '..tostring(#(state.crafters or {}))
    if scanError then lines[#lines+1]='Scanner: '..scanError end
    if dashboardError then lines[#lines+1]='Display: '..dashboardError end
    for id,w in pairs(workers) do
      lines[#lines+1]=id..': '..(w.status or 'connected')
      lines[#lines+1]='  Mode: '..(w.dryRun and 'dry' or 'live')..'  Fuel: '..tostring(w.fuel or '?')
      local batch=state.batches.workers and state.batches.workers[tostring(id)]
      if batch then lines[#lines+1]='  Crop batch: '..batch end
      local desired=cfg.workerModes and cfg.workerModes[tostring(id)]
      if desired~=nil and desired~=w.dryRun then lines[#lines+1]='  Pending mode: '..(desired and 'dry' or 'live') end
    end
    return lines
  end
  local playerTracker=Players.new()
  local playerList={}
  -- Polled apart from drawing so detector latency never stalls a monitor redraw.
  local function playerLoop()
    while true do
      local ok,list=pcall(function() return playerTracker:poll(cfg.center,cfg.radius) end)
      playerList=ok and list or {}
      sleep(0.5)
    end
  end
  local function displayModel()
    metrics:tick(U.now())
    local s=summary()
    return {now=U.now(),active=state.active,world=world,center=cfg.center,radius=cfg.radius,version=installedVersion,
      plots=garden.data.plots,history=state.history,growth=state.growth,excluded=state.excluded,workers=workers,
      players=playerList,playerError=playerTracker.error,
      cache=cache,cacheHits=hits,metrics=metrics.data,sessionUptime=U.now()-metrics.started,
      scanAge=s.scanAge,scanError=scanError,freshFor=cfg.scanInterval*3}
  end
  local function displayLoop()
    while true do
      local names=peripheral.getNames();table.sort(names)
      local model=displayModel();dashboardError=nil
      for _,name in ipairs(names) do
        if peripheral.hasType(name,'monitor') then
          local started=U.now()
          local ok,err=pcall(function() dashboard:draw(peripheral.wrap(name),name,model) end)
          performance:record('draw',started)
          if not ok then dashboardError=tostring(err) end
        end
      end
      -- Players move far between frames; only pay for a fast redraw while one is watching.
      sleep(#playerList>0 and 0.5 or 2)
    end
  end
  local function touchLoop()
    while true do
      local _,name,x,y=os.pullEvent('monitor_touch')
      if dashboard:touch(name,x,y,displayModel()) then save() end
    end
  end
  local function drainReason()
    for _,lease in pairs(leases) do
      if lease.untilTime>U.now() then return 'A worker still has a job.' end
    end
    for id,w in pairs(workers) do
      if not w.pos or not w.dock or not U.equal(w.pos,w.dock) then
        return 'Worker '..id..' is not confirmed at its dock.'
      end
    end
  end
  local function stopLoop()
    while true do
      if stopping and not drainReason() then
        save()
        print('FarmBot stopped. Back at CraftOS; run farm start to reopen.')
        return
      end
      sleep(0.5)
    end
  end
  local function consoleLoop()
    local commandHistory=CommandHistory.new()
    print('FarmBot controller #'..os.getComputerID())
    print('Type help for the command list, or help NAME for one command.')
    while true do
      write('farm> ');local line=commandHistory:read();local words={}
      for word in line:gmatch('%S+') do words[#words+1]=word end
      if words[1]=='farm' then table.remove(words,1) end
      local cmd=words[1]
      if not cmd then -- blank line: reprompt without a scolding
      elseif cmd=='help' then for _,l in ipairs(Help.lines(words[2])) do print(l) end
      elseif cmd=='start' then stopping=false;state.active=true;save();print('Workers enabled.')
      elseif cmd=='stop' or cmd=='exit' or cmd=='quit' then
        state.active=false;stopping=true;save()
        print('Stopping: finish current jobs and dock, then return to CraftOS.')
        local why=drainReason();if why then print(why..' Use status to check, or start to cancel stopping.') end
      elseif (cmd=='update' and words[2]=='system') or (cmd=='check' and words[2]=='update') then
        stopping=false
        require('farm.updater').run({beforeInstall=function()
          state.active=false;save()
          local why=drainReason()
          if why then return false,'Farm paused. '..why..' Wait/check status, then run update system again.' end
          stopping=false -- Do not let a prior stop request interrupt staging/install.
          return true
        end,beforeReboot=save})
      elseif cmd=='pause' then state.active=false;save();print('Workers will finish any replant and return to dock.')
      elseif cmd=='scan' then scanAt=0;print('Survey queued.')
      elseif cmd=='status' then
        for _,l in ipairs(statusLines()) do print(l) end
        if stopping then print('Stop requested: '..(drainReason() or 'ready to exit')) end
      elseif cmd=='allow' and tonumber(words[2]) then
        cfg.allowed[tostring(tonumber(words[2]))]=true;S.save('farm/config',cfg);print('Paired worker '..words[2])
      elseif cmd=='worker' then
        local id=tonumber(words[2]);local mode=words[4]
        local recover=words[3]=='recover' and not words[4]
        if not id or id<0 or id%1~=0 or (not recover and (words[3]~='mode' or (mode~='live' and mode~='dry') or words[5])) then
          print('worker ID mode live|dry OR worker ID recover')
        elseif not cfg.allowed[tostring(id)] then print('Pair this worker with allow ID first.')
        elseif workers[id] and workers[id].remoteMode==false then print('Update this worker for remote mode commands.')
        elseif recover then
          cfg.workerRecover=cfg.workerRecover or {}
          cfg.workerRecover[tostring(id)]=(cfg.workerRecover[tostring(id)] or 0)+1
          S.save('farm/config',cfg);print('Worker '..id..': recovery queued between jobs.')
        else
          cfg.workerModes=cfg.workerModes or {};cfg.workerModes[tostring(id)]=mode=='dry'
          S.save('farm/config',cfg)
          print('Worker '..id..': '..mode..' queued between jobs.')
        end
      elseif cmd=='exclude' or cmd=='include' then
        local x,y,z=tonumber(words[2]),tonumber(words[3]),tonumber(words[4])
        if x and y and z then state.excluded[U.key({x=x,y=y,z=z})]=cmd=='exclude' or nil;save();print('Updated.') end
      elseif cmd=='crops' then
        local counts={};for _,j in pairs(jobs) do counts[j.name]=(counts[j.name] or 0)+1 end
        for name,count in pairs(counts) do print(count..' '..name) end
      elseif cmd=='inventories' then
        for _,name in ipairs(peripheral.getNames()) do if peripheral.hasType(name,'inventory') then print(name) end end
      elseif cmd=='screens' then
        for _,name in ipairs(peripheral.getNames()) do
          if peripheral.hasType(name,'monitor') then print(name..' = '..dashboard:view(name).role) end
        end
      elseif cmd=='screen' and words[2] and (words[3]=='map' or words[3]=='stats') then
        dashboard:view(words[2]).role=words[3];dashboard.frames[words[2]]=nil;save();print('Display assignment saved.')
      elseif cmd=='screen' and words[2] and words[3]=='scale' then
        local scale=tonumber(words[4])
        if scale and scale>=0.5 and scale<=2 and scale*2%1==0 then
          dashboard:view(words[2]).scale=scale;dashboard.frames[words[2]]=nil;save();print('Text scale saved.')
        else print('Use screen NAME scale 0.5|1|1.5|2') end
      elseif cmd=='hardware' then
        local ids={};for id in pairs(workers) do ids[#ids+1]=tostring(id) end;table.sort(ids)
        for _,line in ipairs(Hardware.lines(peripheral,{
          monitorRole=function(name) return dashboard:view(name).role end,
          dimension=playerTracker.dimension,players=#playerList,
          gps=U.key(cfg.center),version=installedVersion,group=cfg.group,
          workers=#ids>0 and table.concat(ids,', ') or 'none paired yet'})) do print(line) end
      elseif cmd=='history' then
        for k,h in pairs(state.history) do
          print(k..' '..tostring(h.name)..' '..tostring(h.outcome)..' '..tostring(h.detail or ''))
        end
      else print('No command called '..cmd..'. Type help for the list.') end
    end
  end
  parallel.waitForAny(networkLoop,discoverLoop,scanLoop,displayLoop,playerLoop,consoleLoop,touchLoop,stopLoop,requestLoop)
end
return Controller
