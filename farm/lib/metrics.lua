-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- Durable lifetime counters, separate from the seven-day per-position history.
local M={};M.__index=M
function M.new(data,now)
  data=data or {since=now,uptime=0,harvests=0,replants=0,deferred=0,errors=0,scans=0,byCrop={},events={}}
  data.byWorker=data.byWorker or {};data.workerSince=data.workerSince or now
  data.sessions=(data.sessions or 0)+1
  return setmetatable({data=data,last=now,started=now},M)
end
function M:tick(now)
  self.data.uptime=self.data.uptime+math.max(0,now-self.last);self.last=now
end
function M:worker(id,now)
  local key=tostring(id);local w=self.data.byWorker[key]
  if not w then w={since=now,harvests=0,replants=0,deferred=0,errors=0,inspections=0,steps=0,byCrop={}};self.data.byWorker[key]=w end
  return w
end
function M:report(id,stats,now)
  local w=self:worker(id,now)
  if type(stats)=='table' and type(stats.steps)=='number' and stats.steps>=0 and stats.steps<math.huge then
    w.steps=math.max(w.steps,math.floor(stats.steps))
  end
end
function M:record(job,outcome,after,now,detail,id)
  local harvested=outcome=='harvested' or outcome=='deferred'
  local replanted=outcome=='replanted' or (outcome=='harvested' and job.seed and after
    and (after.name==job.name or after.name==job.plantedName))
  local errorState=outcome=='error' or outcome=='unreachable'
  if id and outcome~='dry_run' then
    local w=self:worker(id,now);w.inspections=w.inspections+1
    if harvested then w.harvests=w.harvests+1;local name=job.crop or job.name;w.byCrop[name]=(w.byCrop[name] or 0)+1 end
    if replanted then w.replants=w.replants+1 end
    if outcome=='deferred' then w.deferred=w.deferred+1 end
    if errorState then w.errors=w.errors+1 end
  end
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
