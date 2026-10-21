-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
os.queueEvent=function() end
os.pullEvent=function() coroutine.yield() end
local S=require('farm.lib.store')
local Controller=require('farm.controller')
local Journal=require('farm.lib.journal')
fs={exists=function() return false end}
local function clone(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=clone(x) end;return t end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local stop={};local state;local responses={};local queue={};local mutations=0
os.epoch=function() return 100000 end
os.getComputerID=function() return 10 end
sleep=function() coroutine.yield() end
local blocks={}
for x=1,2 do
  blocks[#blocks+1]={name='minecraft:farmland',x=x,y=0,z=0}
  blocks[#blocks+1]={name='minecraft:wheat',x=x,y=1,z=0}
end
for _,p in ipairs({{x=2,y=2,z=0,name='minecraft:wall_torch'},
 {x=3,y=1,z=0,name='minecraft:stone'},{x=2,y=1,z=1,name='minecraft:stone'},
 {x=2,y=1,z=-1,name='minecraft:stone'}}) do blocks[#blocks+1]=p end
local scanner={}
scanner[arg[1]=='modern' and 'scanBlocks' or 'scan']=function(radius) eq(radius,5);return blocks end
peripheral={getNames=function() return {'left'} end,
  hasType=function(_,kind) return kind=='modem' end,call=function() return true end,
  find=function(kind) if kind=='geo_scanner' then return scanner end end}
S.load=function(path,default)
  if path=='farm/data/controller' then return {active=true,history={},excluded={}} end
  return default
end
S.save=function(path,data)
  if path:find('controller-journal/',1,true) then
    Journal.apply(state,clone(data));if data.plot and data.plot.intent then mutations=mutations+1 end
  elseif path=='farm/data/controller' then
    state=clone(data)
    for _,p in pairs(data.garden.plots) do if p.intent then mutations=mutations+1;break end end
  end
end
local seq=0;local assigned;local access
local function enqueue(kind,data,reuse)
  seq=reuse or seq+1
  queue[#queue+1]={v=1,seq=seq,session='test',kind=kind,data=data or {}}
end
local dock={x=0,y=2,z=0}
enqueue('hello',{dock=dock,pos=dock,inventory={}})
local lastRequest
rednet={open=function() end,
  receive=function()
    coroutine.yield()
    while #queue==0 do if #responses>=7 then error(stop) end;coroutine.yield() end
    lastRequest=table.remove(queue,1);return 1,lastRequest
  end,
  send=function(id,reply)
    eq(id,1);assert(not reply.error,reply.error);responses[#responses+1]=clone(reply)
    local inv={['minecraft:wheat_seeds']=4}
    if lastRequest.kind=='hello' then enqueue('job',{pos=dock,inventory=inv,resume='1,1,0'})
    elseif lastRequest.kind=='job' then
      assigned=reply.data;eq(assigned.job.key,'1,1,0');assert(assigned.job.accessCandidates)
      enqueue('begin',{job=assigned.job,token=assigned.token,pos=assigned.goal,inventory=inv})
    elseif lastRequest.kind=='begin' and not access then
      enqueue('access_job',{job=assigned.job,token=assigned.token,pos=assigned.goal,inventory=inv})
    elseif lastRequest.kind=='access_job' then
      access=reply.data;eq(access.job.key,'2,1,0');eq(access.job.name,'minecraft:wheat')
      assert(state.garden.plots[assigned.job.key].debt)
      enqueue('begin',{job=access.job,token=access.token,pos=assigned.job.pos,inventory=inv})
    elseif lastRequest.kind=='begin' then
      assert(state.garden.plots[assigned.job.key].debt and state.garden.plots[access.job.key].debt)
      enqueue('result',{job=access.job,token=access.token,pos=assigned.job.pos,outcome='harvested',after={name='minecraft:wheat',state={age=0}},inventory=inv})
    elseif lastRequest.kind=='result' and lastRequest.data.job.key==access.job.key then
      enqueue('result',{job=assigned.job,token=assigned.token,pos=assigned.goal,outcome='harvested',after={name='minecraft:wheat',state={age=0}},inventory=inv})
    elseif lastRequest.kind=='result' then
      assert(not state.garden.plots[assigned.job.key].debt and not state.garden.plots[access.job.key].debt)
      assert(state.batches.visited[assigned.job.key] and state.batches.visited[access.job.key])
    end
  end}
parallel={waitForAny=function(network,discover,scan,display,player,console,touch,stopLoop,request)
  local c=coroutine.create(scan);local ok,err=coroutine.resume(c);assert(ok,err)
  assert(state and state.garden.plots['1,1,0'],'Initial scan not persisted')
  local receiver,processor=coroutine.create(network),coroutine.create(request)
  for _=1,200 do for _,co in ipairs({receiver,processor}) do
    local ok,err=coroutine.resume(co);if not ok then error(err,0) end
  end end
  error('Mailbox did not complete controller scenario')
end}
local ok,err=pcall(Controller.run,{center={x=0,y=0,z=0},radius=5,scanInterval=120,
  group='test',allowed={['1']=true},customCrops={}})
assert(not ok and err==stop,tostring(err))
eq(#responses,7)
print('PASS controller leases both neighboring crops in one round and journals both planting debts before access harvest')
