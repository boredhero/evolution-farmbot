-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- Executes the actual worker loop against a deterministic in-memory turtle/world.
package.path='./?.lua;./?/init.lua;'..package.path
local U=require('farm.lib.util')
local S=require('farm.lib.store')
local N=require('farm.lib.network')
local Worker=require('farm.worker')
local function clone(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=clone(x) end;return t end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local stop={};local now=100000
os.epoch=function() return now end
os.getComputerID=function() return 1 end
os.getComputerLabel=function() return 'test-worker' end
sleep=function(seconds) now=now+seconds*1000 end
parallel={waitForAny=function(f) f() end}
local CompactCraft=require('farm.lib.compact_crafting')
local compactRun=CompactCraft.run
local function run(options)
  local position={x=0,y=1,z=0};local heading=1;local selected=1
  local hiddenPlant
  local grid={['0,1,-1']={name='minecraft:chest'},['0,2,0']={name='minecraft:chest'}}
  if options.station then grid[U.key(options.station)]={name='minecraft:chest'} end
  for k,b in pairs(options.grid or {}) do grid[k]=clone(b) end
  if options.compact then grid['3,1,1']={name='minecraft:crafter',state={orientation='north_up'}} end
  local inv=clone(options.inventory or {});local saved=clone(options.saved or {})
  local results,events={},{};local seedPlans=0;local nextJob=0;local moveCalls=0;local modeSent,configSaved
  local function target(side)
    return U.add(position,U.dirs[side=='Down' and 6 or side=='Up' and 5 or heading])
  end
  local function count(slot) return inv[slot] and inv[slot].count or 0 end
  local function add(name,n)
    if n==0 then return end
    for i=1,16 do if inv[i] and inv[i].name==name then inv[i].count=inv[i].count+n;return end end
    for i=1,16 do if not inv[i] then inv[i]={name=name,count=n};return end end
    error('Mock inventory overflow')
  end
  turtle={getItemDetail=function(i) return clone(inv[i]) end,getItemCount=count,
    getItemSpace=function(i) return 64-count(i) end,
    compareTo=function(i) return inv[selected] and inv[i] and inv[selected].name==inv[i].name or false end,
    transferTo=function(i)
      local n=math.min(count(selected),64-count(i))
      if n==0 then return false end
      inv[i].count=inv[i].count+n;inv[selected].count=inv[selected].count-n
      if inv[selected].count==0 then inv[selected]=nil end
      return true
    end,
    select=function(i) selected=i;return true end,getFuelLevel=function() return options.fuel or 'unlimited' end,
    refuel=function() return false end,
    turnLeft=function() heading=((heading-2)%4)+1;return true end,
    turnRight=function() heading=heading%4+1;return true end}
  for _,side in ipairs({'','Up','Down'}) do
    turtle['inspect'..side]=function()
      local key=U.key(target(side));if hiddenPlant==key then hiddenPlant=nil;return false end
      local b=grid[key];return b~=nil,clone(b)
    end
    turtle['dig'..side]=function()
      local k=U.key(target(side));local b=grid[k]
      assert(b and b.name~='minecraft:stone' and b.name~='minecraft:chest','Tried to dig non-crop!')
      if b.name=='minecraft:wheat' then assert(saved.pending,'Missing local write-ahead journal before dig') end
      events[#events+1]='dig:'..k;grid[k]=nil
      local n=options.drops and options.drops[k] or 0
      add('minecraft:wheat_seeds',n);add('minecraft:wheat',1)
      return true
    end
    turtle['place'..side]=function()
      local k=U.key(target(side))
      if inv[selected] and inv[selected].name=='minecraft:bone_meal' then
        events[#events+1]='bonemeal:'..k
        if not options.rejectBoneMeal then
          inv[selected].count=inv[selected].count-1;grid[k].state.age=math.min(7,grid[k].state.age+3)
        end
        return not options.rejectBoneMeal
      end
      if inv[selected] and inv[selected].name=='actuallyadditions:worm' then
        assert(not grid[k]);events[#events+1]='worm:'..k
        inv[selected].count=inv[selected].count-1;return true
      end
      assert(not grid[k],'Tried to replace occupied crop cell!')
      local below=U.key(U.add(target(side),U.dirs[6]))
      if options.soil and inv[selected] and inv[selected].name=='minecraft:wooden_hoe' then
        assert(grid[below] and grid[below].name=='minecraft:dirt')
        grid[below]={name='minecraft:farmland'};events[#events+1]='till:'..below;return true
      end
      if options.soil and grid[below] and grid[below].name~='minecraft:farmland' then return false,'Invalid soil' end
      assert(inv[selected] and inv[selected].name=='minecraft:wheat_seeds')
      inv[selected].count=inv[selected].count-1;if inv[selected].count==0 then inv[selected]=nil end
      grid[k]={name=options.lateForeign and 'farmersdelight:onions' or 'minecraft:wheat',state={age=0}}
      if options.latePlant or options.lateForeign then hiddenPlant=k end
      events[#events+1]='plant:'..k;return true
    end
    turtle['suck'..side]=function()
      if options.station and U.key(target(side))==U.key(options.station) then
        events[#events+1]='suck'..side
        add('minecraft:dirt',1);return true
      end
      return false
    end
    turtle['drop'..side]=function(n)
      if options.station then
        eq(U.key(target(side)),U.key(options.station));events[#events+1]='drop'..side
      end
      if options.fullChest then error(stop) end
      n=math.min(n or count(selected),count(selected))
      if inv[selected] then inv[selected].count=inv[selected].count-n;if inv[selected].count==0 then inv[selected]=nil end end
      return n>0
    end
  end
  CompactCraft.run=options.compact and function(side,output,recipe,journal,save)
    events[#events+1]='compact';journal.loaded=true;save()
    for i=1,16 do if inv[i] and inv[i].name==recipe.item then inv[i].count=inv[i].count-9;break end end
    add(output,1);return true
  end or compactRun
  local function move(side)
    moveCalls=moveCalls+1;local p=target(side)
    if options.entityBlock and U.key(p)=='1,1,0' then return false,'Movement obstructed' end
    if grid[U.key(p)] then return false,'obstructed' end
    position=p;return true
  end
  turtle.forward=function() return move('') end
  turtle.up=function() return move('Up') end
  turtle.down=function() return move('Down') end
  S.load=function() return clone(saved) end
  S.save=function(path,data)
    if path=='farm/config' then configSaved=clone(data) else saved=clone(data) end
  end
  Worker.calibrate=function() return clone(position),heading end
  local function path(from,to)
    local out={};local p=clone(from)
    if options.grid and p.x==0 and to.x~=0 then p=clone(p);p.x=1;out[#out+1]=p end
    for _,axis in ipairs(options.grid and {'y','x','z'} or {'x','z','y'}) do while p[axis]~=to[axis] do
      p=clone(p);p[axis]=p[axis]+(p[axis]<to[axis] and 1 or -1);out[#out+1]=p
    end end
    return out
  end
  N.client=function()
    return function(kind,data)
      if kind=='access_job' then
        if options.access and not options.accessTaken then
          options.accessTaken=true;assert(not grid[data.job.key],'Access gap must already be empty')
          return {job=clone(options.access),token='access'}
        end
        return {}
      end
      if kind=='craft_done' then return {ok=true} end
      if kind=='craft_station' and options.compact then return {pos={x=3,y=1,z=1}} end
      if kind=='craft_station' then return nil,'No available Crafter in scanner coverage' end
      if kind=='step' then return {ok=true} end
      if kind=='control' then return {recover=options.recover and 1 or nil,growthTools=options.growthTools} end
      if kind=='hello' then return {active=true} end
      if kind=='seed_plan' then seedPlans=seedPlans+1;if options.stopAfterDock and seedPlans==3 then error(stop) end;return options.seedPlan or {seeds={['minecraft:wheat_seeds']=true},needed={}} end
      if kind=='status' then return {active=not options.paused} end
      if kind=='route' then
        if options.noReplan and data.goals[1].x==1 and not data.preview then return nil,'No accessible approach cell' end
        return {path=path(data.pos,data.goals[1]),goal=data.goals[1]}
      end
      if kind=='cleared_vine' then events[#events+1]='cleared_vine';return {ok=true} end
      if kind=='blocked' then events[#events+1]='blocked';return {ok=true} end
      if kind=='recover' then events[#events+1]='recover';return {ok=true} end
      if kind=='begin' then
        events[#events+1]='begin'
        if options.replaceAtBegin then grid[U.key(data.job.pos)]={name='farmersdelight:onions',state={age=0}} end
        return {ok=true}
      end
      if kind=='job' then
        if options.expectedResume then eq(data.resume,options.expectedResume) end
        if options.mode and not modeSent then modeSent=true;return {mode=options.mode} end
        if options.mode then eq(data.dryRun,options.mode=='dry') end
        nextJob=nextJob+1;local j=options.jobs[nextJob];if not j then error(stop) end
        if j.wait then return {wait=0,reason='Waiting for next crop',returnHome=j.returnHome} end
        j=clone(j);local goal=U.add(j.vines and j.vines[1] or j.pos,U.dirs[5])
        if options.soil then grid[U.key(U.add(j.pos,U.dirs[6]))]={name=options.soil} end
        if not j.repair then grid[j.key]={name=j.name,state={age=options.immature and 1 or 7}} end
        if options.blockRoute then grid['1,1,0']={name='minecraft:stone'} end
        return {job=j,goal=goal,path=path(data.pos,goal),token='t'..nextJob}
      end
      if kind=='result' then
        if options.loseResult then return nil,'simulated controller disconnection' end
        results[#results+1]=clone(data)
        if options.fillAfterResult then for slot=3,15 do inv[slot]={name='test:junk_'..slot,count=1} end end
        if options.stopAfterResult then error(stop) end;return {ok=true}
      end
      if kind=='release' then return {ok=true} end
      error('Unexpected RPC: '..kind)
    end
  end
  local cfg={controller=2,dock={x=0,y=1,z=0},dockHeading=1,
    outputBlock='minecraft:chest',fuelBlock='minecraft:chest',fuelReserve=256,dryRun=options.dryRun}
  if options.station then cfg.stations={output=options.station,fuel=options.station} end
  local ok,err=pcall(Worker.run,cfg)
  assert(not ok and (err==stop or options.loseResult),tostring(err))
  return {results=results,events=events,saved=saved,grid=grid,inventory=inv,moves=moveCalls,config=configSaved,seedPlans=seedPlans}
end
local function crop(x,repair)
  return {pos={x=x,y=0,z=0},key=x..',0,0',name='minecraft:wheat',age=7,
    seed='minecraft:wheat_seeds',mode='replant',version=x,repair=repair}
end
local tests={
 {'sugar cane growing into the approach cell raises the target and clears the column without breaking its root',function()
   local name='minecraft:sugar_cane';local grid={}
   for y=0,2 do grid['2,'..y..',0']={name=name} end
   local job={pos={x=2,y=1,z=0},key='2,1,0',name=name,mode='cane',rootY=0,onlyAbove=true}
   local r=run({jobs={job},grid=grid})
   eq(r.results[1].outcome,'harvested');eq(r.grid['2,2,0'],nil);eq(r.grid['2,1,0'],nil)
   eq(r.grid['2,0,0'].name,name)
 end},
 {'column harvest removes every upper cane/cactus block in one visit and preserves the root',function()
   for _,name in ipairs({'minecraft:sugar_cane','minecraft:cactus'}) do
     local grid={};for y=0,2 do grid['2,'..y..',0']={name=name} end
     local job={pos={x=2,y=2,z=0},key='2,2,0',name=name,mode='cane',rootY=0,onlyAbove=true}
     local r=run({jobs={job},grid=grid})
     eq(r.results[1].outcome,'harvested');eq(r.grid['2,2,0'],nil);eq(r.grid['2,1,0'],nil)
     eq(r.grid['2,0,0'].name,name)
   end
 end},
 {'batch unloading exports unrelated planting items and byproducts, keeping only requested reserves',function()
   local r=run({jobs={},seedPlan={seeds={wheat_seed=true,coffee=true,onion=true},needed={coffee=64},keep={wheat_seed=4,onion=1}},
     inventory={[1]={name='wheat_seed',count=40},[2]={name='coffee',count=4},[3]={name='onion',count=4},[4]={name='sprig',count=2}}})
   eq(r.inventory[1].count,4);eq(r.inventory[2],nil);eq(r.inventory[3].count,1);eq(r.inventory[4],nil)
 end},
 {'remote recovery is acknowledged durably without dropping inventory or erasing records',function()
   local r=run({jobs={},recover=true,saved={marker='preserved'}})
   eq(r.config.recoverAck,1);eq(r.saved.marker,'preserved')
 end},
 {'duplicate planting-item stacks export surplus and subsequent string without requiring a bank',function()
   local r=run({jobs={},seedPlan={seeds={['minecraft:carrot']=true},needed={['minecraft:carrot']=64}},
     inventory={[1]={name='minecraft:carrot',count=4},[2]={name='minecraft:carrot',count=7},[3]={name='minecraft:string',count=2}}})
   eq(r.inventory[1].count,4);eq(r.inventory[2],nil);eq(r.inventory[3],nil)
 end},
 {'remote modes are saved and acknowledged before the next crop assignment',function()
   local live=run({jobs={crop(1)},dryRun=true,mode='live',drops={['1,0,0']=1}})
   eq(live.config.dryRun,false);eq(live.results[1].outcome,'harvested')
   local dry=run({jobs={crop(1)},dryRun=false,mode='dry'})
   eq(dry.config.dryRun,true);eq(dry.results[1].outcome,'dry_run')
 end},
 {'output and fuel stations work from all six sides, including returning unwanted fuel items',function()
   for i=1,6 do
     local station=U.add({x=0,y=1,z=0},U.dirs[i])
     local r=run({jobs={},station=station,fuel=9000,inventory={[1]={name='minecraft:wheat',count=2}}})
     local side=i==5 and 'Up' or i==6 and 'Down' or ''
     eq(r.events[1],'drop'..side);eq(r.events[2],'suck'..side);eq(r.events[3],'drop'..side)
     eq(r.inventory[1],nil)
   end
 end},
 {'harvest with empty seed supply, remember hole, harvest next plant, revisit hole',function()
   local r=run({jobs={crop(1),crop(2),crop(1,true)},drops={['1,0,0']=0,['2,0,0']=3}})
   eq(r.results[1].outcome,'deferred');eq(r.results[2].outcome,'harvested');eq(r.results[3].outcome,'replanted')
   eq(r.grid['1,0,0'].state.age,0);eq(r.grid['2,0,0'].state.age,0);eq(r.saved.pending,nil)
 end},
 {'manual crop replacement during authorization is not dug up',function()
   local r=run({jobs={crop(1)},replaceAtBegin=true})
   eq(r.results[1].outcome,'changed');eq(r.grid['1,0,0'].name,'farmersdelight:onions')
   for _,e in ipairs(r.events) do assert(not e:match('^dig:')) end
 end},
 {'inspection mode changes no crops',function()
   local r=run({jobs={crop(1)},dryRun=true});eq(r.results[1].outcome,'dry_run')
   eq(r.grid['1,0,0'].state.age,7)
   for _,e in ipairs(r.events) do assert(not e:match('^dig:') and not e:match('^plant:')) end
 end},
 {'unacknowledged empty harvest retains worker journal',function()
   local r=run({jobs={crop(1)},loseResult=true});assert(r.saved.pending);eq(r.saved.pending.job.key,'1,0,0')
 end},
 {'restart hands off unfinished harvest without requiring seeds or freezing',function()
   local r=run({jobs={crop(2)},saved={pending={job=crop(1),token='old'}},drops={['2,0,0']=2}})
   eq(r.events[1],'recover');eq(r.results[1].outcome,'harvested');eq(r.saved.pending,nil)
 end},
 {'movement obstruction is never dug for a route',function()
   local r=run({jobs={crop(1)},blockRoute=true});eq(r.results[1].outcome,'unreachable')
   eq(r.grid['1,1,0'].name,'minecraft:stone')
   assert(r.results[1].detail:find('Blocked at 1,1,0 by minecraft:stone',1,true))
   for _,e in ipairs(r.events) do assert(not e:match('^dig:')) end
 end},
 {'failed replanning preserves the last obstacle coordinates and block name',function()
   local r=run({jobs={crop(1)},blockRoute=true,noReplan=true})
   assert(r.results[1].detail:find('No accessible approach cell',1,true))
   assert(r.results[1].detail:find('Blocked at 1,1,0 by minecraft:stone',1,true))
 end},
 {'movement failure without an inspectable block reports destination and reason',function()
   local r=run({jobs={crop(1)},entityBlock=true})
   assert(r.results[1].detail:find('Movement failed at 1,1,0: Movement obstructed',1,true))
 end},
 {'pause prevents harvest while permitting homing',function()
   local r=run({jobs={crop(1)},paused=true});eq(r.results[1].outcome,'unreachable')
   eq(r.grid['1,0,0'].state.age,7)
 end},
}
for _,t in ipairs(tests) do
  local ok,err=pcall(t[2]);if not ok then io.stderr:write('FAIL '..t[1]..'\n'..tostring(err)..'\n');os.exit(1) end
  print('PASS '..t[1])
end
print('Passed '..#tests..' worker integration simulations')

do
  local r=run({jobs={crop(2)},soil='minecraft:dirt',inventory={[1]={name='minecraft:wheat_seeds',count=3},[2]={name='minecraft:wooden_hoe',count=1}}})
  eq(r.results[1].outcome,'harvested');eq(r.grid['2,-1,0'].name,'minecraft:farmland');eq(r.grid['2,0,0'].name,'minecraft:wheat')
  assert(r.inventory[2] and r.inventory[2].name=='minecraft:wooden_hoe','Hoe must survive initial unloading')
  local missing=run({jobs={crop(2)},soil='minecraft:dirt',inventory={[1]={name='minecraft:wheat_seeds',count=3}}})
  eq(missing.results[1].outcome,'error');assert(missing.results[1].detail:find('soil at 2,-1,0: minecraft:dirt',1,true))
  print('PASS worker retains hoe, checks dirt beneath empty crop, tills and replants; missing hoe reports both coordinates')
end

do
  local j=crop(2,true);j.vines={{x=2,y=3,z=0},{x=2,y=2,z=0},{x=2,y=1,z=0},{x=2,y=0,z=0}}
  local grid={};for _,p in ipairs(j.vines) do grid[U.key(p)]={name='minecraft:vine'} end
  local r=run({jobs={j},grid=grid,inventory={[1]={name='minecraft:wheat_seeds',count=3}}})
  eq(r.results[1].outcome,'replanted');eq(r.grid['2,0,0'].name,'minecraft:wheat')
  for y=1,3 do assert(not r.grid['2,'..y..',0']) end
  local dry=run({jobs={j},grid=grid,dryRun=true,stopAfterResult=true,inventory={[1]={name='minecraft:wheat_seeds',count=3}}})
  for _,event in ipairs(dry.events) do assert(not event:find('dig:',1,true)) end
  print('PASS worker clears bounded hanging vines top-down, repairs invaded gap and preserves all vines in dry mode')
end

do
  local r=run({jobs={crop(2),{wait=true},crop(3)},inventory={[1]={name='minecraft:wheat_seeds',count=4}}})
  eq(#r.results,2);eq(r.seedPlans,2);assert(r.saved.commissioned)
  local full=run({jobs={crop(2)},fillAfterResult=true,stopAfterDock=true,inventory={[1]={name='minecraft:wheat_seeds',count=4}}})
  eq(full.seedPlans,3)
  local restart=run({jobs={},saved={commissioned=true}});eq(restart.seedPlans,0)
  print('PASS idle crop transitions retain harvest, fifteen occupied slots trigger unload, and commissioned restarts skip unnecessary docking')
end

do
  local r=run({jobs={crop(2)},stopAfterResult=true,expectedResume='2,0,0',saved={commissioned=true,assignment={key='2,0,0'},pickupBatch='minecraft:wheat'},inventory={[1]={name='minecraft:wheat_seeds',count=3}}})
  eq(r.seedPlans,0);eq(r.results[1].outcome,'harvested')
  print('PASS restarted worker requests unfinished assignment from actual GPS position without returning home')
end

do
  local base=crop(2);base.accessCandidates=true;local child=crop(3)
  local grid={['3,0,0']={name='minecraft:wheat',state={age=7}},['3,1,0']={name='minecraft:wall_torch'}}
  local options={jobs={base},access=child,grid=grid,saved={commissioned=true},inventory={[1]={name='minecraft:wheat_seeds',count=4}}}
  local r=run(options)
  eq(#r.results,2);eq(r.results[1].job.key,child.key);eq(r.results[2].job.key,base.key)
  eq(r.results[1].outcome,'harvested');eq(r.results[2].outcome,'harvested')
  eq(r.grid['3,1,0'].name,'minecraft:wall_torch');eq(r.grid[base.key].state.age,0);eq(r.grid[child.key].state.age,0)
  eq(r.saved.pending,nil);eq(r.saved.accessPending,nil)
  local events=table.concat(r.events,'|')
  assert(events:find('dig:2,0,0',1,true)<events:find('dig:3,0,0',1,true))
  assert(events:find('plant:3,0,0',1,true)<events:find('plant:2,0,0',1,true))
  options.accessTaken=nil;options.loseResult=true
  local failed=run(options);assert(failed.saved.accessPending);assert(failed.saved.pending)
  eq(failed.saved.accessPending.job.key,base.key);eq(failed.saved.pending.job.key,child.key)
  local recovered=run({jobs={},saved=failed.saved});eq(recovered.events[1],'recover');eq(recovered.events[2],'recover')
  options.accessTaken=nil;options.loseResult=nil;options.dryRun=true
  local dry=run(options);assert(not options.accessTaken);eq(dry.grid[child.key].state.age,7)
  print('PASS worker uses harvested neighbor to reach under torch, replants both, preserves both journals on failure and never opens access in dry mode')
end

do
 local r=run({jobs={},compact=true,inventory={[1]={name='minecraft:wheat',count=20}},
 seedPlan={seeds={},needed={},keep={},compacting={{key='wheat',item='minecraft:wheat',output='minecraft:hay_block',inputCount=9,count=1,batches=2}}}})
 local count=0;for _,event in ipairs(r.events) do if event=='compact' then count=count+1 end end
 eq(count,2);eq(r.saved.crafting,nil);assert(not next(r.inventory))
 local dry=run({jobs={},compact=true,dryRun=true,inventory={[1]={name='minecraft:wheat',count=20}},
 seedPlan={seeds={},needed={},keep={},compacting={{key='wheat',item='minecraft:wheat',output='minecraft:hay_block',inputCount=9,count=1,batches=2}}}})
 for _,event in ipairs(dry.events) do assert(event~='compact') end
 print('PASS worker compacts through the shared Crafter before unloading output and leftovers, clears recovery journal and honors dry mode')
end

do
 local opts={jobs={crop(2)},latePlant=true,inventory={[1]={name='minecraft:wheat_seeds',count=3}}}
 local r=run(opts);eq(r.results[1].outcome,'harvested');eq(r.grid['2,0,0'].name,'minecraft:wheat');eq(r.saved.pending,nil)
 for _,event in ipairs(r.events) do assert(not event:find('till:',1,true)) end
 opts.latePlant=nil;opts.lateForeign=true
 local foreign=run(opts);eq(foreign.results[1].outcome,'occupied');eq(foreign.grid['2,0,0'].name,'farmersdelight:onions')
 print('PASS delayed replant visibility is accepted before soil recovery; unexpected occupants are preserved without a false soil error')
end

do
 local opts={jobs={crop(2)},saved={commissioned=true},immature=true,growthTools={autoWorms=true,autoBoneMeal=true},
 inventory={[1]={name='minecraft:wheat_seeds',count=4},[2]={name='minecraft:bone_meal',count=10},[3]={name='actuallyadditions:worm',count=2}}}
 local r=run(opts);eq(r.results[1].outcome,'harvested');eq(r.inventory[2].count,8);eq(r.inventory[3].count,1)
 local events=table.concat(r.events,'|');assert(events:find('bonemeal:2,0,0',1,true)<events:find('dig:2,0,0',1,true))
 assert(events:find('worm:2,0,0',1,true)<events:find('plant:2,0,0',1,true))
 opts.growthTools={autoWorms=false,autoBoneMeal=false};local off=run(opts)
 eq(off.results[1].outcome,'growing');eq(off.inventory[2].count,10);eq(off.inventory[3].count,2)
 opts.growthTools={autoWorms=true,autoBoneMeal=true};opts.dryRun=true;local dry=run(opts)
 eq(dry.inventory[2].count,10);eq(dry.inventory[3].count,2)
 opts.dryRun=false;opts.rejectBoneMeal=true;local rejected=run(opts);eq(rejected.results[1].outcome,'growing');eq(rejected.inventory[2].count,10)
 print('PASS actual worker accelerates its assigned crop, places a worm in the harvest gap before replanting, respects both toggles and dry mode, and continues on rejected bone meal')
end
