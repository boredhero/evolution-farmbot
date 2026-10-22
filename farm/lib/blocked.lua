-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local B={}
-- Bounded reverse inspection. A candidate bridges the crop pocket to the
-- already-proven reachable component; never suggest removing it automatically.
function B.explain(world,start,goals,reason,yieldFn)
  local out={reason=reason or 'Route unavailable',candidates={}}
  local cache=world.components;local source=world:index(start)
  local label=cache and cache.labels[source]
  local connected=label and cache.complete[label]
  local queue,seen,boundary={},{},{}
  local function add(p)
    local id=world:index(p)
    if id and not seen[id] and not world:blocked(p) then seen[id]=true;queue[#queue+1]=p end
  end
  for _,g in ipairs(goals) do add(g) end
  local function candidate(p)
    local b=world:block(p)
    if b then out.candidates[#out.candidates+1]={pos=U.copy(p),name=b.name} end
  end
  if #queue==0 then
    for _,g in ipairs(goals) do candidate(g) end
    out.kind='approach';return out
  end
  if not connected or reason~='No route in surveyed space' then return out end
  local at=1
  while at<=#queue and at<=512 do
    local p=queue[at]
    for _,d in ipairs(U.dirs) do
      local q=U.add(p,d);local id=world:index(q)
      if id then
        if world:blocked(q) then
          if not boundary[id] then
            boundary[id]=true
            for _,side in ipairs(U.dirs) do
              local other=world:index(U.add(q,side))
              if other and cache.labels[other]==label then candidate(q);break end
            end
          end
        else add(q) end
      end
    end
    if yieldFn and at%128==0 then yieldFn() end
    at=at+1
  end
  table.sort(out.candidates,function(a,b)
    local at=a.name:find('torch') and 0 or 1;local bt=b.name:find('torch') and 0 or 1
    if at~=bt then return at<bt end
    return U.key(a.pos)<U.key(b.pos)
  end)
  while #out.candidates>3 do table.remove(out.candidates) end
  if #out.candidates>0 then out.kind='bridge' end
  return out
end
function B.list(plots,history,excluded)
  local rows={}
  for key,p in pairs(plots or {}) do
    local h=history and history[key]
    if h and h.routeIssue and not (excluded and excluded[key]) and p.live~=false then
      rows[#rows+1]={key=key,job=p.job,issue=h.routeIssue}
    end
  end
  table.sort(rows,function(a,b)return a.key<b.key end)
  return rows
end
return B
