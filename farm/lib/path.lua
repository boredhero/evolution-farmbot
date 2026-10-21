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
  if not world:inside(start) then return nil,'Start outside scanner coverage',0 end
  local n=world.n;local plane=n*n;local floor,abs=math.floor,math.abs
  local masks={1,2,4,8,16,32,64,128};local avoid={}
  -- Convert traffic once, rather than allocating six positions and string keys
  -- for every expanded voxel. Only reconstruct positions for the final route.
  for key,value in pairs(opts.avoid or {}) do if value then
    local x,y,z=key:match('^([^,]+),([^,]+),([^,]+)$')
    x,y,z=tonumber(x),tonumber(y),tonumber(z)
    if x and y and z then
      local id=world:index({x=x,y=y,z=z});if id then avoid[id]=true end
    end
  end end
  local function blocked(id)
    return avoid[id] or floor(world.packed:byte(floor(id/8)+1)/masks[id%8+1])%2==1
  end
  local source=world:index(start);local targets,valid={},{}
  for _,g in ipairs(goals) do
    local id=world:index(g)
    if id and (id==source or not blocked(id)) then
      targets[id]=g;valid[#valid+1]={x=g.x-world.min.x,y=g.y-world.min.y,z=g.z-world.min.z}
    end
  end
  if #valid==0 then return nil,'No accessible approach cell',0 end
  if targets[source] then return {},targets[source],0 end
  local componentChecked=false
  local function connected(onlyCached)
    if not world.component then return true end
    local component,labels=world:component(source,opts.yieldFn,onlyCached)
    if not component then return true end
    componentChecked=true
    for id in pairs(targets) do if labels[id]==component then return true end end
    return false
  end
  if not connected(true) then return nil,'No route in surveyed space',0 end
  local function heuristic(x,y,z)
    local best=math.huge
    for i=1,#valid do local g=valid[i];local distance=abs(x-g.x)+abs(y-g.y)+abs(z-g.z)
      if distance<best then best=distance end
    end
    return best
  end
  local heap,dist,parents={}, {[source]=0},{}
  push(heap,{id=source,g=0,f=heuristic(start.x-world.min.x,start.y-world.min.y,start.z-world.min.z)})
  local expanded=0;local current,score
  local function visit(id,x,y,z)
    if (not dist[id] or score<dist[id]) and not blocked(id) then
      dist[id]=score;parents[id]=current.id
      push(heap,{id=id,g=score,f=score+heuristic(x,y,z)})
    end
  end
  while #heap>0 do
    current=pop(heap)
    if current.g==dist[current.id] then
      if targets[current.id] then
        local path,at={},current.id
        while at~=source do path[#path+1]=world:position(at);at=parents[at] end
        local ordered={}
        for i=#path,1,-1 do ordered[#ordered+1]=path[i] end
        return ordered,targets[current.id],expanded
      end
      expanded=expanded+1
      -- Short routes should never pay for a full-volume component flood. Only
      -- expensive searches build the shared cache; later requests reuse it.
      if expanded==1000 and not componentChecked and not connected(false) then
        return nil,'No route in surveyed space',expanded
      end
      if expanded>(opts.limit or 60000) then return nil,'Search budget reached',expanded end
      if opts.yieldFn and expanded%1000==0 then opts.yieldFn() end
      local id=current.id;local x=id%n;local z=floor(id/n)%n;local y=floor(id/plane)
      score=current.g+1
      if z>0 then visit(id-n,x,y,z-1) end
      if x<n-1 then visit(id+1,x+1,y,z) end
      if z<n-1 then visit(id+n,x,y,z+1) end
      if x>0 then visit(id-1,x-1,y,z) end
      if y<n-1 then visit(id+plane,x,y+1,z) end
      if y>0 then visit(id-plane,x,y-1,z) end
    end
  end
  return nil,'No route in surveyed space',expanded
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
