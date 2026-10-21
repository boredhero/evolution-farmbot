-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local C=require('farm.lib.crops')
local M={}
function M.plan(garden,batches,leases,inventory,keep,stock)
  local busy,seedCrops={},{}
  for _,name in pairs(batches.pending or {}) do busy[name]=true end
  for _,lease in pairs(leases or {}) do busy[lease.job.crop or lease.job.name]=true end
  for _,p in pairs(garden.data.plots) do
    local j=p.job
    if j.seed then
      local r=seedCrops[j.seed] or {busy=false};seedCrops[j.seed]=r
      r.busy=r.busy or busy[j.crop or j.name] or p.debt or p.intent~=nil
    end
  end
  local amounts={}
  for seed,r in pairs(seedCrops) do
    -- Edible planting items are produce, not excess seeds.
    local bare=seed:match(':(.+)$') or seed
    if not r.busy and (bare=='seed' or bare:match('_seeds$') or bare:match('_seed$')) then
      local reserve=math.max(keep[seed] or 0,16-(stock[seed] or 0))
      local excess=(inventory[seed] or 0)-reserve
      if excess>0 then amounts[seed]=excess end
    end
  end
  return amounts
end
function M.run(side,amounts)
  local inspect=turtle['inspect'..side];local use=turtle['place'..side];local suck=turtle['suck'..side]
  local function block()
    local ok,b=inspect()
    if not ok or b.name~='minecraft:composter' then return nil,'Composter missing or replaced' end
    if not C.tag(b.tags or {},'computercraft:turtle_can_use') then return nil,'Composter interaction tag missing' end
    return b
  end
  local total=0
  local function empty(slot)
    local b,err=block();if not b then return false,err end
    if b.state.level==7 then sleep(1.2);b,err=block();if not b then return false,err end end
    if b.state.level==8 then
      local tool=slot
      if not tool or turtle.getItemCount(tool)==0 then
        for i=1,16 do if turtle.getItemCount(i)>0 then tool=i;break end end
      end
      if not tool then return false,'Need an interaction item to empty composter' end
      turtle.select(tool);use();suck()
      b,err=block();if not b then return false,err end
    end
    return b.state.level<7,'Composter is still processing'
  end
  for slot=1,16 do
    local item=turtle.getItemDetail(slot)
    if item and (amounts[item.name] or 0)>0 then
      while (amounts[item.name] or 0)>0 and turtle.getItemCount(slot)>0 do
        local ok,err=empty(slot);if not ok then return total,err end
        turtle.select(slot);local before=turtle.getItemCount(slot);use()
        local consumed=before-turtle.getItemCount(slot)
        if consumed~=1 then break end -- Unsupported mod seeds stay in inventory for normal export.
        amounts[item.name]=amounts[item.name]-1;total=total+1
      end
    end
  end
  empty();return total
end
return M
