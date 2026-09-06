-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local N={}
function N.protocol(cfg) return 'evolution-farmbot-v1:'..cfg.group end
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
    return nil,'Controller not responding'
  end
end
return N
