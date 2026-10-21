-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
os.queueEvent=function() end
os.pullEvent=function() coroutine.yield() end
local S=require('farm.lib.store')
local Controller=require('farm.controller')
fs={exists=function() return false end}
local cfg={center={x=0,y=0,z=0},radius=5,scanInterval=120,group='test',allowed={['1']=true},customCrops={}}
local stop={};local inputs,queue={},{};local replies={};local saved
os.epoch=function() return 100000 end
os.getComputerID=function() return 10 end
sleep=function() coroutine.yield() end
write=function() end
read=function() while #inputs==0 do coroutine.yield() end;return table.remove(inputs,1) end
S.load=function(_,default) return default end
S.save=function(path,data) if path=='farm/config' then saved=data end end
peripheral={getNames=function() return {'left'} end,hasType=function() return true end,call=function() return true end,
  find=function(kind) if kind=='geo_scanner' then return {scanBlocks=function() return {} end} end end}
rednet={open=function() end,
  receive=function() while #queue==0 do coroutine.yield() end;return 1,table.remove(queue,1) end,
  send=function(_,reply) assert(not reply.error,reply.error);replies[#replies+1]=reply.data end}
local seq=0
local function enqueue(kind,dry)
  seq=seq+1;queue[#queue+1]={v=1,seq=seq,session='test',kind=kind,
    data={pos={x=0,y=1,z=0},dock={x=0,y=1,z=0},dryRun=dry,remoteMode=true}}
end
parallel={waitForAny=function(network,discover,scan,display,player,console,touch,stopLoop,request)
  local work=coroutine.create(request);local net=coroutine.create(network);local con=coroutine.create(console)
  local function resume(co) local ok,err=coroutine.resume(co);assert(ok,err);if co==net then ok,err=coroutine.resume(work);assert(ok,err) end end
  inputs[1]='farm worker 1 mode live';resume(con)
  assert(saved.workerModes['1']==false,'offline command must persist')
  enqueue('hello',true);resume(net)
  enqueue('job',true);resume(net);assert(replies[#replies].mode=='live')
  enqueue('job',false);resume(net);assert(not replies[#replies].mode and not replies[#replies].job,'acknowledged mode must not enable paused farm')
  inputs[1]='worker 1 mode dry';resume(con)
  enqueue('job',false);resume(net);assert(replies[#replies].mode=='dry')
  inputs[1]='worker 2 mode live';resume(con);assert(cfg.workerModes['2']==nil)
  inputs[1]='worker 1 mode typo';resume(con);assert(cfg.workerModes['1']==true)
  inputs[1]='worker 1 recover';resume(con)
  enqueue('control',true);resume(net);assert(replies[#replies].recover==1)
  inputs[1]='worker 1 recover';resume(con)
  enqueue('control',true);resume(net);assert(replies[#replies].recover==2)
  error(stop)
end}
local ok,err=pcall(Controller.run,cfg);assert(not ok and err==stop,tostring(err))
print('PASS controller modes: optional farm prefix, persistence, paired-only, acknowledgment, paused-farm safety')
