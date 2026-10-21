-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local U=require('farm.lib.util')
local M=require('farm.lib.mailbox')
local events,threads,sent={},{},{}
local current
os.epoch=function() return 100000 end
sleep=function() error('Computation must not wait for a timer') end
os.queueEvent=function(...) events[#events+1]=table.pack(...) end
os.pullEvent=function(filter)
  local event=table.pack(coroutine.yield(filter))
  if event[1]=='terminate' then error('Terminated',0) end
  return table.unpack(event,1,event.n)
end
local function resume(t,event)
  local ok,filter=coroutine.resume(t.co,table.unpack(event,1,event.n));assert(ok,filter)
  t.filter=filter
end
local function add(fn)
  local t={co=coroutine.create(fn)};threads[#threads+1]=t;resume(t,{n=0});return t
end
local function pump()
  local count=0
  while #events>0 do
    count=count+1;assert(count<1000,'Event loop did not settle')
    local event=table.remove(events,1);current=event
    -- CC broadcasts each event once; unmatched filters do not retain a backlog.
    for _,t in ipairs(threads) do
      if coroutine.status(t.co)~='dead' and (not t.filter or t.filter==event[1] or event[1]=='terminate') then resume(t,event) end
    end
  end
end
rednet={receive=function(protocol)
  while true do
    local _,id,m,p=os.pullEvent('rednet_message')
    if p==protocol then return id,m end
  end
end,send=function(id,m,p) sent[#sent+1]={id=id,message=m,protocol=p} end}
local function request(id,kind,seq,session,protocol)
  os.queueEvent('rednet_message',id,{v=1,kind=kind,seq=seq or 1,session=session or 'a',data={}},protocol or 'farm')
end
local allowed,calls,profile={},{},{}
for id=1,16 do allowed[tostring(id)]=true end
local heartbeat,step,busy,started=false,false,false,false
local mailbox=M.new({protocol='farm',allowed=allowed,performance={record=function(_,kind) profile[kind]=(profile[kind] or 0)+1 end},
  handle=function(id,m)
    if m.kind=='heartbeat' then heartbeat=true;assert(busy);return {ok=true} end
    if m.kind=='step' then step=true;assert(busy);return {ok=true} end
    if m.kind=='error' then error('expected handler failure') end
    local key=id..':'..m.session..':'..m.seq;calls[key]=(calls[key] or 0)+1
    assert(not busy,'Heavy requests must remain serialized');busy=true
    if not started then
      started=true
      for worker=2,16 do request(worker,'job') end
      request(1,'job') -- Retry while original handler is still in progress.
      request(16,'heartbeat',-1);request(16,'step',2)
      U.yield()
      assert(heartbeat and step,'Heartbeats and traffic must run during route search')
    else U.yield() end
    busy=false;return {owner=id}
  end})
add(function() mailbox:receive() end);add(function() mailbox:work() end)
request(1,'job');pump()
assert(#sent==17,'Sixteen job replies and one fast traffic reply expected')
for id=1,16 do assert(calls[id..':a:1']==1,'Lost or duplicated worker '..id) end
assert(profile.rpc_job==16 and profile.rpc_step==1)
assert(not next(mailbox.pending))
print('PASS sixteen workers keep every request while routing yields, with immediate heartbeat and traffic service')
request(1,'job');pump();assert(calls['1:a:1']==1 and #sent==18)
request(1,'job',1,'new-session');pump();assert(calls['1:new-session:1']==1)
assert(sent[#sent].message.session=='new-session')
request(15,'error',4);pump();assert(sent[#sent].message.error:find('expected handler failure',1,true))
request(99,'job');pump();assert(sent[#sent].message.error:find('not paired',1,true))
local before=#sent
request(1,'job',99,'a','other-farm');os.queueEvent('rednet_message',1,{v=1,seq=100,data={}},'farm');pump()
assert(#sent==before)
print('PASS retries execute once, sessions remain distinct, malformed traffic is ignored and handler errors reply')
-- Two callers must each wait for their own event, with no timer dependency.
local resumed={}
add(function() U.yield();resumed[1]=current[2] end)
add(function() U.yield();resumed[2]=current[2] end)
pump();assert(resumed[1] and resumed[2] and resumed[1]~=resumed[2])
print('PASS cooperative yields use distinct queued events instead of timer sleeps')
