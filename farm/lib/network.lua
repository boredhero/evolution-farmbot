-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local N={}
function N.protocol(cfg) return 'evolution-farmbot-v1:'..cfg.group end
-- Pairing must not depend on a human retyping the farm name: the protocol is
-- built from it, so a typo makes worker and controller silently invisible to
-- each other. Discovery runs on one fixed protocol and reports the real name.
N.DISCOVERY='evolution-farmbot-discover'
function N.answer(cfg)
  local id,m=rednet.receive(N.DISCOVERY)
  if type(m)=='table' and m.kind=='who' then
    rednet.send(id,{kind='controller',group=cfg.group,controller=os.getComputerID(),center=cfg.center},N.DISCOVERY)
  end
end
function N.discover(timeout)
  U.openModem()
  rednet.broadcast({kind='who'},N.DISCOVERY)
  local found,seen={},{}
  local deadline=U.now()+(timeout or 3)
  repeat
    local id,m=rednet.receive(N.DISCOVERY,math.max(0,deadline-U.now()))
    if id and type(m)=='table' and m.kind=='controller' and type(m.group)=='string' and not seen[id] then
      seen[id]=true;found[#found+1]={controller=id,group=m.group,center=m.center}
    end
  until U.now()>=deadline
  table.sort(found,function(a,b) return a.controller<b.controller end)
  return found
end
-- Turns the commonest misconfiguration into a message that names the fix.
function N.mismatch(cfg,found)
  for _,c in ipairs(found or {}) do
    if c.group~=cfg.group then
      return 'Controller #'..c.controller..' is on farm network "'..c.group..
        '" but this worker is set to "'..tostring(cfg.group)..'". Run farm setup worker to pair automatically.'
    elseif c.controller~=cfg.controller then
      return 'Controller #'..c.controller..' answered on this network; this worker is set to #'..
        tostring(cfg.controller)..'. Run farm setup worker to pair automatically.'
    end
  end
end
function N.client(cfg)
  U.openModem()
  local seq=0
  return function(kind,data)
    seq=seq+1
    local message={v=1,seq=seq,kind=kind,data=data or {},session=cfg.session}
    for attempt=1,4 do
      rednet.send(cfg.controller,message,N.protocol(cfg))
      local deadline=U.now()+12
      repeat
        local id,reply=rednet.receive(N.protocol(cfg),math.max(0,deadline-U.now()))
        if id==cfg.controller and type(reply)=='table' and reply.seq==seq and reply.session==cfg.session then
          if reply.error then return nil,reply.error end
          return reply.data
        end
      until U.now()>=deadline
    end
    local ok,found=pcall(N.discover,2)
    return nil,'Controller not responding. '..((ok and N.mismatch(cfg,found)) or
      'Check the controller is running farm start and both have Ender Modems.')
  end
end
return N
