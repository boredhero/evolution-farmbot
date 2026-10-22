-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local S=require('farm.lib.store');local P=require('farm.lib.path');local C=require('farm.controller')
local now=100;local searches=0;local original=P.find
P.find=function(...) searches=searches+1;return original(...) end
os.epoch=function() return now*1000 end;os.getComputerID=function() return 4 end
os.queueEvent=function() end;os.pullEvent=function() coroutine.yield() end
sleep=function() coroutine.yield() end
fs={exists=function() return false end}
S.load=function(_,default)return default end;S.save=function()end
local blocks={{name='minecraft:stone',x=4,y=4,z=4}}
local scanner={scanBlocks=function()return blocks end}
peripheral={getNames=function()return {'left'}end,hasType=function(_,kind)return kind=='modem'end,
 call=function()return true end,find=function(kind)if kind=='geo_scanner'then return scanner end end}
local queue={};local replies={};local seq=0
rednet={open=function()end,receive=function()
 while #queue==0 do coroutine.yield() end
 return 1,table.remove(queue,1)
end,send=function(_,reply)replies[reply.seq]=reply end}
local done={}
parallel={waitForAny=function(network,discover,scan,display,player,console,touch,stop,request)
 local scanCo=coroutine.create(scan);local receiver=coroutine.create(network);local processor=coroutine.create(request)
 local function step(co)local ok,err=coroutine.resume(co);assert(ok,err)end
 step(scanCo)
 local function rpc(kind,data)
  seq=seq+1;queue[#queue+1]={v=1,seq=seq,session='cache-test',kind=kind,data=data}
  for _=1,100 do step(receiver);step(processor);if replies[seq]then
   local r=replies[seq];assert(not r.error,r.error);return r.data
  end end
  error('No controller reply')
 end
 local start={x=0,y=2,z=0};local goal={x=2,y=2,z=0}
 rpc('hello',{pos=start,dock={x=-2,y=2,z=0},inventory={}})
 local function route()return rpc('route',{pos=start,goals={goal},preview=true})end
 assert(#route().path==2);local n=searches;route();assert(searches==n)
 rpc('blocked',{pos=start,block={x=4,y=3,z=4},name='minecraft:stone'})
 route();assert(searches==n,'Unrelated obstacle must preserve cached route')
 rpc('blocked',{pos=start,block={x=3,y=3,z=3},name='computercraft:turtle_advanced'})
 route();assert(searches==n,'Other turtle must not flush cached routes')
 blocks[#blocks+1]={x=4,y=3,z=4,name='minecraft:stone'};now=230;step(scanCo)
 route();assert(searches==n,'Changed scan must preserve unaffected cached route')
 rpc('blocked',{pos=start,block={x=1,y=2,z=0},name='minecraft:stone'})
 local r=route();assert(searches>n,'A blocked cached route must be replanned')
 for _,p in ipairs(r.path)do assert(not(p.x==1 and p.y==2 and p.z==0))end
 n=searches
 -- A temporary traffic report on an unrelated route cannot destroy this detour.
 rpc('blocked',{pos=start,block={x=3,y=3,z=2},name='computercraft:turtle_advanced'})
 route();assert(searches==n)
 error(done)
end}
local ok,err=pcall(C.run,{center={x=0,y=0,z=0},radius=5,scanInterval=120,allowed={['1']=true},group='test'})
assert(not ok and err==done,tostring(err))
print('PASS real controller retains routes across changed scans and obstacle reports while rejecting obstructed cached paths')
