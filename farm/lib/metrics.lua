-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- Durable lifetime counters, separate from the seven-day per-position history.
local M={};M.__index=M
function M.new(data,now)
  data=data or {since=now,uptime=0,harvests=0,replants=0,deferred=0,errors=0,scans=0,byCrop={},events={}}
  data.sessions=(data.sessions or 0)+1
  return setmetatable({data=data,last=now,started=now},M)
end
function M:tick(now)
  self.data.uptime=self.data.uptime+math.max(0,now-self.last);self.last=now
end
function M:record(job,outcome,after,now,detail)
  local harvested=outcome=='harvested' or outcome=='deferred'
  local replanted=outcome=='replanted' or (outcome=='harvested' and job.seed and after
    and (after.name==job.name or after.name==job.plantedName))
  local errorState=outcome=='error' or outcome=='unreachable'
  if not harvested and not replanted and outcome~='deferred' and not errorState then return end
  local crop=self.data.byCrop[job.name] or {harvests=0,replants=0,deferred=0}
  self.data.byCrop[job.name]=crop
  if harvested then self.data.harvests=self.data.harvests+1;crop.harvests=crop.harvests+1 end
  if replanted then self.data.replants=self.data.replants+1;crop.replants=crop.replants+1 end
  if outcome=='deferred' then self.data.deferred=self.data.deferred+1;crop.deferred=crop.deferred+1 end
  if errorState then self.data.errors=self.data.errors+1 end
  local events=self.data.events
  events[#events+1]={time=now,name=job.name,outcome=outcome,detail=detail and tostring(detail):sub(1,120)}
  if #events>24 then table.remove(events,1) end
end
return M
