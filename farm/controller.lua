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
local Dashboard=require('farm.dashboard')
local Controller={}
function Controller.run(cfg)
  U.openModem()
  local protocol=N.protocol(cfg)
  local state=S.load('farm/data/controller',{active=false,history={},excluded={}})
  state.history=state.history or {};state.excluded=state.excluded or {}
  local garden=Garden.new(state.garden);state.garden=garden.data
  local metrics=Metrics.new(state.metrics,U.now());state.metrics=metrics.data
  local dashboard=Dashboard.new(state.displays);state.displays=dashboard.views
  local dashboardError
  local world=W.new(cfg.center,cfg.radius)
  local jobs,workers,leases,obstacles,responses,cache={},{},{},{},{},{}
  local scanAt,lastScan,scanError=0,0,'Waiting for first scan'
  local epoch=0;local hits=0;local scanBusy=false;local lastSave=0
  local boot=tostring(U.now());local leaseSerial=0
  local snapshot=S.load('farm/data/map',nil)
  if snapshot and snapshot.radius==cfg.radius and U.equal(snapshot.center,cfg.center) then
    world.packed=snapshot.packed -- No jobs dispatched until a fresh scan succeeds.
  end
  local scanner=peripheral.find('geo_scanner') or peripheral.find('geoScanner')
  assert(scanner,'Attach the Geo Scanner directly to the controller.')
  local function save()
    metrics:tick(U.now())
    -- Prune long-absent plants so abandoned crops do not fill the disk.
    local cutoff=U.now()-7*86400
    for k,h in pairs(state.history) do if (h.seen or 0)<cutoff then state.history[k]=nil end end
    S.save('farm/data/controller',state);lastSave=U.now()
  end
  local function summary()
    local total,unknown,active=0,0,0
    for _,j in pairs(jobs) do total=total+1;if j.mode=='probe' then unknown=unknown+1 end end
    for _,w in pairs(workers) do if U.now()-w.seen<30 then active=active+1 end end
    return {active=state.active,crops=total,unknown=unknown,workers=active,
      scanAge=lastScan>0 and math.floor(U.now()-lastScan) or -1,error=scanError,
      cachedHits=hits,epoch=epoch,center=cfg.center,radius=cfg.radius,debts=garden:debts()}
  end
  local function avoidFor(id)
    local avoid={};local now=U.now()
    for k,untilTime in pairs(obstacles) do
      if untilTime>now then avoid[k]=true else obstacles[k]=nil end
    end
    for other,w in pairs(workers) do
      if other~=id then
        if now-w.seen<30 and w.pos then avoid[U.key(w.pos)]=true end
        if w.dock then avoid[U.key(w.dock)]=true end
      end
    end
    return avoid
  end
  local function route(id,start,goals)
    local avoid=avoidFor(id)
    local parts={U.key(start)};for _,g in ipairs(goals) do parts[#parts+1]=U.key(g) end
    local key=table.concat(parts,'|')
    local cached=cache[key]
    if cached and P.valid(world,start,cached.path,avoid) then hits=hits+1;return cached.path,cached.goal end
    local path,goal=P.find(world,start,goals,{avoid=avoid,yieldFn=U.yield})
    if path then
      if #parts>0 then
        local count=0;for _ in pairs(cache) do count=count+1 end
        if count>=128 then cache={} end
      end
      cache[key]={path=path,goal=goal};return path,goal
    end
    return nil,goal
  end
  local function fresh() return lastScan>0 and U.now()-lastScan<cfg.scanInterval*3 end
  local function release(id)
    for k,l in pairs(leases) do if l.owner==id then leases[k]=nil end end
  end
  local function handle(id,m)
    local d=m.data
    workers[id]=workers[id] or {}
    local w=workers[id];w.seen=U.now()
    if d.pos and not d.preview then w.pos=d.pos end
    if d.fuel then w.fuel=d.fuel end
    if d.status then w.status=tostring(d.status):sub(1,120) end
    if d.inventory then w.inventory=d.inventory end
    for k,l in pairs(leases) do if l.owner==id then
      l.untilTime=U.now()+120
      local p=garden.data.plots[k]
      if p and p.intent and p.intent.token==l.token then p.intent.expires=l.untilTime end
    end end
    if m.kind=='heartbeat' then return {ok=true}
    elseif m.kind=='hello' then
      if not world:inside(d.dock) then return nil,'Dock is outside the scanner cube' end
      w.dock=d.dock;w.name=d.name;w.seedBuffer=d.seedBuffer;w.dryRun=d.dryRun
      return {active=state.active,center=cfg.center,radius=cfg.radius}
    elseif m.kind=='seed_plan' then
      local stock=Seeds.stock(cfg.seedSource);local needed={}
      for seed in pairs(garden.data.seeds) do
        local target=math.max(16,math.min(64,garden:living(seed)+garden:debts(seed)*2))
        needed[seed]=math.max(0,target-(stock[seed] or 0))
      end
      return {seeds=garden.data.seeds,needed=needed}
    elseif m.kind=='bank_store' then
      if not w.dock or not U.equal(d.pos,w.dock) then return nil,'Seed storage requires worker at its dock' end
      return Seeds.store(cfg.seedSource,w.seedBuffer)
    elseif m.kind=='recover' then
      local p=d.job and garden.data.plots[d.job.key]
      if p and p.version==d.job.version and p.intent and p.intent.owner==id then
        p.intent=nil;p.updated=U.now();save()
      end
      release(id);scanAt=0
      return {ok=true} -- Existing durable debt survives; never resurrect an obsolete crop plan.
    elseif m.kind=='begin' then
      if not state.active or not fresh() then return nil,'Paused or waiting for fresh survey' end
      local l=d.job and leases[d.job.key]
      if not l or l.owner~=id or l.token~=d.token then return nil,'Crop assignment is no longer valid' end
      local answer,why=garden:begin(l.job,id,l.token,(d.inventory[l.job.seed] or 0)>0,U.now())
      if answer then save() end -- Write-ahead debt must reach disk BEFORE authorizing a dig.
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
    elseif m.kind=='status' then return summary()
    elseif m.kind=='blocked' then
      if d.block and world:inside(d.block) then obstacles[U.key(d.block)]=U.now()+20 end
      return {ok=true}
    elseif m.kind=='route' then
      if not fresh() then return nil,'Waiting for a fresh scanner map' end
      local path,goal=route(id,d.pos,d.goals or {})
      if not path then return nil,goal end
      if not d.preview then w.route=path end
      return {path=path,goal=goal}
    elseif m.kind=='result' then
      local j=d.job
      local l=j and leases[j.key]
      if not l or l.owner~=id or l.token~=d.token then return {ok=true,stale=true} end
      leases[j.key]=nil
      garden:finish(j,d.token,d.after,world,cfg.customCrops,U.now())
      local h=state.history[j.key] or {interval=60}
      h.seen=U.now();h.name=j.name;h.outcome=d.outcome;h.detail=d.detail;h.state=d.state
      if d.after~=nil then h.observed=d.after or nil;h.observedAt=U.now() end
      metrics:record(j,d.outcome,d.after,U.now(),d.detail)
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
      save();return {ok=true}
    elseif m.kind=='job' then
      if not state.active or not fresh() then return {wait=10,reason=scanError or 'Paused'} end
      -- Retries/reconnections recover the existing assignment, never acquire a second.
      for k,l in pairs(leases) do
        if l.untilTime<U.now() then leases[k]=nil
        elseif l.owner==id then
          local path,goal=route(id,d.pos,C.goals(l.job))
          if path then w.route=path;return {job=l.job,path=path,goal=goal,token=l.token} end
          return {wait=10,reason='Assigned crop currently unreachable'}
        end
      end
      local options={}
      local stock=Seeds.stock(cfg.seedSource)
      for _,j in ipairs(garden:tasks(w.inventory,stock,U.now(),w.dryRun)) do
        local k=j.key
        local h=state.history[k]
        if not state.excluded[k] and not leases[k] and (not h or (h.due or 0)<=U.now()) then
          local bonus=j.repair and 10000 or (j.seed and garden:debts(j.seed)>0 and 1000 or 0)
          options[#options+1]={job=j,score=U.distance(d.pos,j.pos)-bonus}
        end
      end
      table.sort(options,function(a,b)return a.score<b.score end)
      for i=1,math.min(12,#options) do
        local j=options[i].job
        local path,goal=route(id,d.pos,C.goals(j))
        if path then
          leaseSerial=leaseSerial+1
          local token=tostring(id)..':'..boot..':'..leaseSerial..':'..j.key
          leases[j.key]={owner=id,untilTime=U.now()+120,job=j,token=token}
          w.route=path
          return {job=j,path=path,goal=goal,token=token}
        end
        state.history[j.key]=state.history[j.key] or {interval=60}
        state.history[j.key].due=U.now()+120
        state.history[j.key].seen=U.now()
        state.history[j.key].outcome='unreachable'
      end
      return {wait=10,reason='No ready reachable work'}
    elseif m.kind=='release' then release(id);return {ok=true} end
    return nil,'Unknown request'
  end
  local function networkLoop()
    while true do
      local id,m=rednet.receive(protocol)
      if type(m)=='table' and m.v==1 and type(m.seq)=='number' and type(m.data)=='table' then
        local reply={seq=m.seq,session=m.session}
        if not cfg.allowed[tostring(id)] then
          reply.error='Worker '..id..' is not paired. Run allow '..id..' on controller.'
        elseif m.kind=='heartbeat' then
          -- Heartbeats reuse a sentinel sequence and must never be response-cached.
          pcall(handle,id,m)
          reply=nil
        else
          local key=tostring(id)..':'..tostring(m.session)..':'..tostring(m.seq)
          if responses[key] then reply=responses[key]
          else
            local ok,data,err=pcall(handle,id,m)
            if ok then reply.data=data;reply.error=err else reply.error=tostring(data) end
            responses[key]=reply
            local keysCount=0;for _ in pairs(responses) do keysCount=keysCount+1 end
            if keysCount>100 then responses={[key]=reply} end
          end
        end
        if reply then rednet.send(id,reply,protocol) end
      end
    end
  end
  local function scanLoop()
    while true do
      if U.now()>=scanAt and not scanBusy then
        scanBusy=true
        local started=U.now()
        local ok,data,err=pcall(scanner.scan,cfg.radius)
        if ok and type(data)=='table' and #data>0 then
          local nextWorld=W.new(cfg.center,cfg.radius)
          nextWorld:ingest(data,U.yield)
          local nextJobs=C.discover(nextWorld,cfg.customCrops,U.yield)
          if nextWorld.packed~=world.packed then cache={};epoch=epoch+1 end
          garden:scan(nextWorld,nextJobs,started,U.now(),cfg.customCrops)
          for k,h in pairs(state.history) do
            local p=garden.data.plots[k]
            if p and h.name~=p.job.name then state.history[k]=nil end
          end
          world=nextWorld;jobs=nextJobs;lastScan=U.now();scanError=nil
          metrics.data.scans=metrics.data.scans+1
          S.save('farm/data/map',world:snapshot())
          save()
        else scanError=tostring(ok and (err or 'Empty scan rejected') or data) end
        scanAt=U.now()+cfg.scanInterval;scanBusy=false
      end
      if U.now()-lastSave>60 then save() end
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
    if scanError then lines[#lines+1]='Scanner: '..scanError end
    if dashboardError then lines[#lines+1]='Display: '..dashboardError end
    for id,w in pairs(workers) do lines[#lines+1]=id..': '..(w.status or 'connected') end
    return lines
  end
  local function displayModel()
    metrics:tick(U.now())
    local s=summary()
    return {now=U.now(),active=state.active,world=world,center=cfg.center,radius=cfg.radius,
      plots=garden.data.plots,history=state.history,excluded=state.excluded,workers=workers,
      cache=cache,cacheHits=hits,metrics=metrics.data,sessionUptime=U.now()-metrics.started,
      scanAge=s.scanAge,scanError=scanError,freshFor=cfg.scanInterval*3}
  end
  local function displayLoop()
    while true do
      local names=peripheral.getNames();table.sort(names)
      local model=displayModel();dashboardError=nil
      for _,name in ipairs(names) do
        if peripheral.hasType(name,'monitor') then
          local ok,err=pcall(function() dashboard:draw(peripheral.wrap(name),name,model) end)
          if not ok then dashboardError=tostring(err) end
        end
      end
      sleep(2)
    end
  end
  local function touchLoop()
    while true do
      local _,name,x,y=os.pullEvent('monitor_touch')
      if dashboard:touch(name,x,y,displayModel()) then save() end
    end
  end
  local function consoleLoop()
    print('FarmBot controller #'..os.getComputerID())
    print('Commands: status, crops, history, inventories, screens, screen NAME map|stats, start, pause, scan, allow ID, check update, update system, exclude/include X Y Z')
    while true do
      write('farm> ');local line=read();local words={}
      for word in line:gmatch('%S+') do words[#words+1]=word end
      local cmd=words[1]
      if cmd=='start' then state.active=true;save();print('Workers enabled.')
      elseif (cmd=='update' and words[2]=='system') or (cmd=='check' and words[2]=='update') then
        require('farm.updater').run({beforeInstall=function()
          state.active=false;save()
          for _,lease in pairs(leases) do if lease.untilTime>U.now() then
            return false,'Farm paused. A worker still has a job; wait for docking, then run update system again.'
          end end
          for id,w in pairs(workers) do
            if not w.pos or not w.dock or not U.equal(w.pos,w.dock) then
              return false,'Farm paused. Worker '..id..' is not confirmed at its dock; wait/check status, then retry.'
            end
          end
          return true
        end,beforeReboot=save})
      elseif cmd=='pause' then state.active=false;save();print('Workers will finish any replant and return to dock.')
      elseif cmd=='scan' then scanAt=0;print('Survey queued.')
      elseif cmd=='status' then for _,l in ipairs(statusLines()) do print(l) end
      elseif cmd=='allow' and tonumber(words[2]) then
        cfg.allowed[tostring(tonumber(words[2]))]=true;S.save('farm/config',cfg);print('Paired worker '..words[2])
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
      elseif cmd=='history' then
        for k,h in pairs(state.history) do
          print(k..' '..tostring(h.name)..' '..tostring(h.outcome)..' '..tostring(h.detail or ''))
        end
      else print('Use status, crops, start, pause, scan, allow ID, exclude X Y Z, include X Y Z.') end
    end
  end
  parallel.waitForAny(networkLoop,scanLoop,displayLoop,consoleLoop,touchLoop)
end
return Controller
