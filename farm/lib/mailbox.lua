-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local M={};M.__index=M
local serial=0
local fast={step=true,status=true,control=true}
function M.new(opts)
  serial=serial+1
  return setmetatable({protocol=opts.protocol,allowed=opts.allowed,handle=opts.handle,performance=opts.performance,
    event='farmbot_mailbox_'..serial,queue={},head=1,tail=0,pending={},responses={},order={},first=1,last=0},M)
end
function M:reply(id,m,key)
  local started=U.now();local ok,data,err=pcall(self.handle,id,m)
  if self.performance then self.performance:record('rpc_'..m.kind,started) end
  local reply={seq=m.seq,session=m.session}
  if ok then reply.data=data;reply.error=err else reply.error=tostring(data) end
  self.responses[key]=reply;self.last=self.last+1;self.order[self.last]=key
  if self.last-self.first>=512 then
    self.responses[self.order[self.first]]=nil;self.order[self.first]=nil;self.first=self.first+1
  end
  if self.first>512 then
    local order={};for i=self.first,self.last do order[#order+1]=self.order[i] end
    self.order=order;self.first=1;self.last=#order
  end
  self.pending[key]=nil
  rednet.send(id,reply,self.protocol)
end
function M:receive()
  while true do
    local id,m=rednet.receive(self.protocol)
    if type(m)=='table' and m.v==1 and type(m.seq)=='number' and type(m.kind)=='string' and type(m.data)=='table' then
      if not self.allowed[tostring(id)] then
        rednet.send(id,{seq=m.seq,session=m.session,error='Worker '..id..' is not paired. Run allow '..id..' on controller.'},self.protocol)
      elseif m.kind=='heartbeat' then pcall(self.handle,id,m)
      else
        local key=tostring(id)..':'..tostring(m.session)..':'..tostring(m.seq)
        if self.responses[key] then rednet.send(id,self.responses[key],self.protocol)
        elseif not self.pending[key] then
          self.pending[key]=true
          if fast[m.kind] then self:reply(id,m,key)
          else
            local empty=self.head>self.tail
            self.tail=self.tail+1;self.queue[self.tail]={id=id,message=m,key=key}
            if empty then os.queueEvent(self.event) end
          end
        end
      end
    end
  end
end
function M:work()
  while true do
    while self.head<=self.tail do
      local item=self.queue[self.head];self.queue[self.head]=nil;self.head=self.head+1
      self:reply(item.id,item.message,item.key)
    end
    self.queue={};self.head=1;self.tail=0
    os.pullEvent(self.event)
  end
end
return M
