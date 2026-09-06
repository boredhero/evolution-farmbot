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
local function run(options)
  local position={x=0,y=1,z=0};local heading=1;local selected=1
  local grid={['0,1,-1']={name='minecraft:chest'},['0,2,0']={name='minecraft:chest'}}
  local inv=clone(options.inventory or {});local saved=clone(options.saved or {})
  local results,events={},{};local nextJob=0;local moveCalls=0
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
    select=function(i) selected=i;return true end,getFuelLevel=function() return 'unlimited' end,
    refuel=function() return false end,
    turnLeft=function() heading=((heading-2)%4)+1;return true end,
    turnRight=function() heading=heading%4+1;return true end}
  for _,side in ipairs({'','Up','Down'}) do
    turtle['inspect'..side]=function() local b=grid[U.key(target(side))];return b~=nil,clone(b) end
    turtle['dig'..side]=function()
      local k=U.key(target(side));local b=grid[k]
      assert(b and b.name~='minecraft:stone' and b.name~='minecraft:chest','Tried to dig non-crop!')
      assert(saved.pending,'Missing local write-ahead journal before dig')
      events[#events+1]='dig:'..k;grid[k]=nil
      local n=options.drops and options.drops[k] or 0
      add('minecraft:wheat_seeds',n);add('minecraft:wheat',1)
      return true
    end
    turtle['place'..side]=function()
      local k=U.key(target(side));assert(not grid[k],'Tried to replace occupied crop cell!')
      assert(inv[selected] and inv[selected].name=='minecraft:wheat_seeds')
      inv[selected].count=inv[selected].count-1;if inv[selected].count==0 then inv[selected]=nil end
      grid[k]={name='minecraft:wheat',state={age=0}};events[#events+1]='plant:'..k;return true
    end
    turtle['suck'..side]=function() return false end
    turtle['drop'..side]=function(n)
      if options.fullChest then error(stop) end
      n=math.min(n or count(selected),count(selected))
      if inv[selected] then inv[selected].count=inv[selected].count-n;if inv[selected].count==0 then inv[selected]=nil end end
      return n>0
    end
  end
  local function move(side)
    moveCalls=moveCalls+1;local p=target(side)
    if grid[U.key(p)] then return false,'obstructed' end
    position=p;return true
  end
  turtle.forward=function() return move('') end
  turtle.up=function() return move('Up') end
  turtle.down=function() return move('Down') end
  S.load=function() return clone(saved) end
  S.save=function(_,data) saved=clone(data) end
  Worker.calibrate=function() return clone(position),heading end
  local function path(from,to)
    local out={};local p=clone(from)
    for _,axis in ipairs({'x','z','y'}) do while p[axis]~=to[axis] do
      p=clone(p);p[axis]=p[axis]+(p[axis]<to[axis] and 1 or -1);out[#out+1]=p
    end end
    return out
  end
  N.client=function()
    return function(kind,data)
      if kind=='hello' then return {active=true} end
      if kind=='seed_plan' then return {seeds={['minecraft:wheat_seeds']=true},needed={}} end
      if kind=='status' then return {active=not options.paused} end
      if kind=='route' then return {path=path(data.pos,data.goals[1]),goal=data.goals[1]} end
      if kind=='blocked' then events[#events+1]='blocked';return {ok=true} end
      if kind=='recover' then events[#events+1]='recover';return {ok=true} end
      if kind=='begin' then
        events[#events+1]='begin'
        if options.replaceAtBegin then grid[U.key(data.job.pos)]={name='farmersdelight:onions',state={age=0}} end
        return {ok=true}
      end
      if kind=='job' then
        nextJob=nextJob+1;local j=options.jobs[nextJob];if not j then error(stop) end
        j=clone(j);local goal=U.add(j.pos,U.dirs[5])
        if not j.repair then grid[j.key]={name=j.name,state={age=7}} end
        if options.blockRoute then grid['1,1,0']={name='minecraft:stone'} end
        return {job=j,goal=goal,path=path(data.pos,goal),token='t'..nextJob}
      end
      if kind=='result' then
        if options.loseResult then return nil,'simulated controller disconnection' end
        results[#results+1]=clone(data);return {ok=true}
      end
      if kind=='release' then return {ok=true} end
      error('Unexpected RPC: '..kind)
    end
  end
  local cfg={controller=2,dock={x=0,y=1,z=0},dockHeading=1,
    outputBlock='minecraft:chest',fuelBlock='minecraft:chest',fuelReserve=256,dryRun=options.dryRun}
  local ok,err=pcall(Worker.run,cfg)
  assert(not ok and (err==stop or options.loseResult),tostring(err))
  return {results=results,events=events,saved=saved,grid=grid,inventory=inv,moves=moveCalls}
end
local function crop(x,repair)
  return {pos={x=x,y=0,z=0},key=x..',0,0',name='minecraft:wheat',age=7,
    seed='minecraft:wheat_seeds',mode='replant',version=x,repair=repair}
end
local tests={
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
   for _,e in ipairs(r.events) do assert(not e:match('^dig:')) end
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
