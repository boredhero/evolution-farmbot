-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- Learn real farm cycles; wall-clock estimates include inspection delay and offline time.
local C=require('farm.lib.crops')
local G={}
local function identity(job) return job.seed or job.name end
function G.record(models,h,job,result,now)
  local planted=h.growthStart
  if not planted and h.observed and h.observed.state and h.observed.state.age==0 then planted=h.observedAt end
  local ripe=result.outcome=='harvested' and job.mode=='replant'
  if ripe and planted and now>planted then
    local seconds=now-planted
    if seconds>=5 and seconds<=86400 then
      local key=identity(job);local model=models[key] or {samples=0,seconds=seconds}
      model.seconds=model.seconds*0.75+seconds*0.25;model.samples=model.samples+1
      models[key]=model
    end
    h.growthStart=nil
  end
  local after=result.after
  if after and after.state and after.state.age==0 and (result.outcome=='harvested' or result.outcome=='replanted') then
    h.growthStart=now
  elseif planted and not h.growthStart and not ripe then h.growthStart=planted end
end
function G.estimate(models,job,h,now)
  if not h or not h.observed or h.observed.name~=job.name then return nil end
  local model=(models or {})[identity(job)]
  if not model or model.samples<1 or not job.age or job.age<=0 then return nil end
  local age=h.observed.state and h.observed.state.age
  if type(age)~='number' or age>=job.age then return nil end
  -- Estimate remaining fraction from the last inspection; no synthetic maturity state.
  local remaining=model.seconds*(job.age-age)/job.age-(now-(h.observedAt or now))
  return math.max(0,remaining),model.samples
end
return G
