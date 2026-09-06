-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local S=require('farm.lib.store')
local Controller=require('farm.controller')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local realPrint=print
local function run(command,busy,cancel)
  local queue,input,output={},{},{};local state,job,tick,finished
  local dock={x=0,y=2,z=0};local away={x=1,y=2,z=0}
  os.epoch=function() return 100000+(tick or 0)*1000 end
  os.getComputerID=function() return 10 end
  sleep=function() coroutine.yield() end
  os.pullEvent=function() coroutine.yield() end
  print=function(s) output[#output+1]=tostring(s) end;write=function() end
  read=function() while #input==0 do coroutine.yield() end;return table.remove(input,1) end
  S.load=function(_,default) return default end
  S.save=function(path,data) if path=='farm/data/controller' then state=data end end
  peripheral={getNames=function() return {'left'} end,
    hasType=function(_,kind) return kind=='modem' end,call=function() return true end,
    find=function(kind) if kind=='geo_scanner' then return {scan=function() return {
      {name='minecraft:farmland',x=1,y=0,z=0},{name='minecraft:wheat',x=1,y=1,z=0}}
    end} end end}
  local seq=0;local current
  local function enqueue(kind,data)
    seq=seq+1;queue[#queue+1]={v=1,seq=seq,session='test',kind=kind,data=data}
  end
  rednet={open=function() end,
    receive=function() while #queue==0 do coroutine.yield() end;current=table.remove(queue,1);return 1,current end,
    send=function(_,reply)
      assert(not reply.error,reply.error)
      if current.kind=='job' then job=reply.data;assert(job.job) end
    end}
  parallel={waitForAny=function(network,scan,display,console,touch,stop)
    local loops={coroutine.create(scan),coroutine.create(network),coroutine.create(console),coroutine.create(stop)}
    for t=1,10 do
      tick=t
      if not busy then if tick==1 then input[1]=command end
      else
        if tick==1 then input[1]='start';enqueue('hello',{pos=dock,dock=dock,inventory={}})
        elseif tick==2 then enqueue('job',{pos=dock,inventory={['minecraft:wheat_seeds']=1}})
        elseif tick==3 then input[1]=command
        elseif tick==4 then
          assert(job);enqueue('result',{job=job.job,token=job.token,pos=away,outcome='dry_run',
            after={name='minecraft:wheat',state={age=7}},inventory={}})
          if cancel then input[1]='start' end
        elseif tick==5 then enqueue('heartbeat',{pos=dock,status='Docked'})
        elseif tick==6 and cancel then input[1]='exit' end
      end
      for _,co in ipairs(loops) do
        local ok,err=coroutine.resume(co);assert(ok,err)
        if coroutine.status(co)=='dead' then finished=tick;return end
      end
      if busy and tick==3 then eq(state.active,false) end
    end
    error('Stop did not complete')
  end}
  Controller.run({center={x=0,y=0,z=0},radius=5,scanInterval=120,group='test',allowed={['1']=true},customCrops={}})
  eq(state.active,false)
  assert(table.concat(output,'\n'):find('FarmBot stopped.',1,true))
  eq(finished,busy and (cancel and 6 or 5) or 1)
end
for _,alias in ipairs({'stop','exit','quit'}) do run(alias,false,false) end
realPrint('PASS stop/exit/quit save paused state and return cleanly when no workers are active')
run('stop',true,false)
realPrint('PASS stop keeps RPC service alive until both job completion and return to dock')
run('exit',true,true)
realPrint('PASS start cancels a pending stop; a later exit still shuts down cleanly')
print=realPrint
