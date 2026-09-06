-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- Durable, observation-driven planting ledger. Only our own harvests create debts.
local U=require('farm.lib.util')
local C=require('farm.lib.crops')
local G={};G.__index=G
function G.new(data)
  data=data or {};data.plots=data.plots or {};data.seeds=data.seeds or {};data.serial=data.serial or 0
  return setmetatable({data=data},G)
end
local function identity(j) return j.seed or j.name end
function G:observe(job,now)
  local p=self.data.plots[job.key]
  if not p or identity(p.job)~=identity(job) then
    self.data.serial=self.data.serial+1
    p={version=self.data.serial};self.data.plots[job.key]=p
  end
  p.job=job;p.live=true;p.debt=false;p.intent=nil;p.updated=now
  if job.seed then self.data.seeds[job.seed]=true end
  if job.item then self.data.seeds[job.item]=true end
  return p
end
function G:scan(world,jobs,started,now,custom)
  -- Never reconcile a scan begun before a mutation against that mutation.
  for k,p in pairs(self.data.plots) do
    if p.updated<=started and not (p.intent and p.intent.expires>now) then
      local j=jobs[k]
      if j then self:observe(j,now)
      else
        local name=world:name(p.job.pos)
        local supported=C.candidate(world,{name=p.job.name,x=p.job.pos.x,y=p.job.pos.y,z=p.job.pos.z},custom)
        if name=='computercraft:turtle_normal' or name=='computercraft:turtle_advanced' then
          -- A turtle can temporarily occupy a hole. It is not a user's replacement.
        elseif not supported or name~='minecraft:air' or not p.debt then
          self.data.plots[k]=nil
        else p.intent=nil;p.updated=now end
      end
    end
  end
  for k,j in pairs(jobs) do if not self.data.plots[k] then self:observe(j,now) end end
end
function G:living(seed)
  local count=0
  for _,p in pairs(self.data.plots) do if p.live and p.job.seed==seed and not p.intent then count=count+1 end end
  return count
end
function G:debts(seed)
  local count=0
  for _,p in pairs(self.data.plots) do if p.debt and (not seed or p.job.seed==seed) then count=count+1 end end
  return count
end
function G:canHarvest(job,hasSeed)
  if not job.seed or hasSeed or job.guaranteedSeed then return true end
  if self:living(job.seed)>1 then return true end
  return false,'Preserving last known living plant until a replant item is available'
end
function G:begin(job,owner,token,hasSeed,now)
  local p=self.data.plots[job.key]
  if not p or p.version~=job.version then return nil,'Planting changed; resurvey required' end
  if p.intent and p.intent.expires>now then
    if p.intent.owner==owner and p.intent.token==token then return {ok=true} end
    return nil,'Another harvest/replant is still in flight'
  end
  if job.repair then
    if not p.debt then return nil,'This gap no longer needs replanting' end
    if not hasSeed then return nil,'No matching seed yet; gap remains remembered' end
  else
    if not p.live then return nil,'Plant already reserved for harvesting or replanting' end
    local allowed,why=self:canHarvest(job,hasSeed)
    if not allowed then return nil,why end
  end
  if job.seed then
    p.live=false;p.debt=true
    p.intent={owner=owner,token=token,expires=now+120}
    p.updated=now
  end
  return {ok=true}
end
function G:finish(job,token,after,world,custom,now)
  local p=self.data.plots[job.key]
  if not p or p.version~=job.version then return false end
  if p.intent and p.intent.token~=token then return false end
  p.intent=nil;p.updated=now
  if after then
    local b={name=after.name,tags=after.tags,x=job.pos.x,y=job.pos.y,z=job.pos.z}
    local actual=C.candidate(world,b,custom)
    if actual then self:observe(actual,now)
    elseif after.name==job.plantedName then
      p.live=true;p.debt=false
    elseif after.name~='computercraft:turtle_normal' and after.name~='computercraft:turtle_advanced' then
      self.data.plots[job.key]=nil -- Adopt replacements; never remove them to restore an old plan.
    end
  elseif after==false then
    if job.seed and p.debt then p.live=false else self.data.plots[job.key]=nil end
  end
  return true
end
function G:tasks(inventory,stock,now,dryRun)
  local tasks={};inventory=inventory or {};stock=stock or {}
  for _,p in pairs(self.data.plots) do
    if not p.intent or p.intent.expires<=now then
      local j={};for k,v in pairs(p.job) do j[k]=v end
      j.version=p.version
      if p.debt then
        if (inventory[j.seed] or 0)>0 or (stock[j.seed] or 0)>0 then
          j.repair=true;j.fetchSeed=(inventory[j.seed] or 0)==0;tasks[#tasks+1]=j
        end
      elseif p.live then
        local available=(inventory[j.seed] or 0)>0
        local allowed=dryRun or self:canHarvest(j,available)
        if not allowed and (stock[j.seed] or 0)>0 then allowed=true;j.fetchSeed=true end
        if allowed then tasks[#tasks+1]=j end
      end
    end
  end
  return tasks
end
return G
