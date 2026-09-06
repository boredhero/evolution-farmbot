-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local P={}
local function before(a,b)
  -- Equal f: prefer progress toward the goal. Avoid flooding an open 65^3 cube.
  return a.f<b.f or (a.f==b.f and a.g>b.g)
end
local function push(h,e)
  local i=#h+1
  while i>1 do local j=math.floor(i/2); if not before(e,h[j]) then break end; h[i]=h[j];i=j end
  h[i]=e
end
local function pop(h)
  local first,last=h[1],table.remove(h)
  if #h>0 then
    local i=1
    while i*2<=#h do
      local c=i*2
      if c+1<=#h and before(h[c+1],h[c]) then c=c+1 end
      if not before(h[c],last) then break end
      h[i]=h[c]; i=c
    end
    h[i]=last
  end
  return first
end
function P.find(world,start,goals,opts)
  opts=opts or {}
  if not world:inside(start) then return nil,'Start outside scanner coverage' end
  local targets,valid={},{}
  local function blocked(p)
    return world:blocked(p) or (opts.avoid and opts.avoid[U.key(p)])
  end
  for _,g in ipairs(goals) do
    if world:inside(g) and (U.equal(g,start) or not blocked(g)) then
      targets[world:index(g)]=g; valid[#valid+1]=g
    end
  end
  if #valid==0 then return nil,'No accessible approach cell' end
  local function heuristic(p)
    local best=math.huge
    for _,g in ipairs(valid) do best=math.min(best,U.distance(p,g)) end
    return best
  end
  local source=world:index(start)
  local heap,dist,parents={}, {[source]=0},{}
  push(heap,{id=source,g=0,f=heuristic(start)})
  local expanded=0
  while #heap>0 do
    local current=pop(heap)
    if current.g==dist[current.id] then
      if targets[current.id] then
        local path,at={},current.id
        while at~=source do path[#path+1]=world:position(at);at=parents[at] end
        local ordered={}
        for i=#path,1,-1 do ordered[#ordered+1]=path[i] end
        return ordered,targets[current.id],expanded
      end
      expanded=expanded+1
      if expanded>(opts.limit or 60000) then return nil,'Search budget reached' end
      if opts.yieldFn and expanded%1000==0 then opts.yieldFn() end
      local pos=world:position(current.id)
      for _,d in ipairs(U.dirs) do
        local nextPos=U.add(pos,d);local id=world:index(nextPos)
        if id and not blocked(nextPos) then
          local score=current.g+1
          if not dist[id] or score<dist[id] then
            dist[id]=score;parents[id]=current.id
            push(heap,{id=id,g=score,f=score+heuristic(nextPos)})
          end
        end
      end
    end
  end
  return nil,'No route in surveyed space'
end
function P.valid(world,start,path,avoid)
  local prev=start
  for _,p in ipairs(path) do
    if U.distance(prev,p)~=1 or world:blocked(p) or (avoid and avoid[U.key(p)]) then return false end
    prev=p
  end
  return true
end
return P
