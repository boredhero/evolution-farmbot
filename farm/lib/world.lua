-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local W={}; W.__index=W
function W.new(center,radius)
  local n=radius*2+1
  return setmetatable({center=U.copy(center),radius=radius,n=n,
    min={x=center.x-radius,y=center.y-radius,z=center.z-radius},
    packed=string.rep(string.char(255),math.ceil(n*n*n/8)),blocks={},revision=0},W)
end
function W:index(p)
  local x,y,z=p.x-self.min.x,p.y-self.min.y,p.z-self.min.z
  if x<0 or y<0 or z<0 or x>=self.n or y>=self.n or z>=self.n then return nil end
  return x+self.n*(z+self.n*y)
end
function W:position(i)
  return {x=self.min.x+i%self.n,z=self.min.z+math.floor(i/self.n)%self.n,
    y=self.min.y+math.floor(i/(self.n*self.n))}
end
function W:inside(p) return self:index(p)~=nil end
function W:blocked(p)
  local i=self:index(p); if not i then return true end
  return math.floor(self.packed:byte(math.floor(i/8)+1)/2^(i%8))%2==1
end
function W:block(p) return self.blocks[U.key(p)] end
function W:name(p) local b=self:block(p); return b and b.name or 'minecraft:air' end
local transient={['computercraft:turtle_normal']=true,['computercraft:turtle_advanced']=true}
function W:ingest(scan,yieldFn)
  -- Only call after a successful COMPLETE scan. Missing entries mean air here.
  local bytes,blocks={},{}
  local function mark(p)
    local i=self:index(p);if not i then return end
    local k=math.floor(i/8)+1;local mask=2^(i%8);local v=bytes[k] or 0
    if math.floor(v/mask)%2==0 then bytes[k]=v+mask end
  end
  for j,b in ipairs(scan) do
    local p=U.add(self.center,b)
    local i=self:index(p)
    if i and b.name and b.name~='minecraft:air' then
      blocks[U.key(p)]={name=b.name,tags=b.tags or {},x=p.x,y=p.y,z=p.z}
      if b.name=='minecraft:cactus' then
        -- A solid turtle beside cactus breaks it. Reserve space for up to two
        -- new growth blocks too, so growth between scans cannot invalidate this.
        for dy=0,2 do for d=1,4 do mark(U.add(U.add(p,{x=0,y=dy,z=0}),U.dirs[d])) end end
      end
      if not transient[b.name] then
        local k=math.floor(i/8)+1; local mask=2^(i%8)
        local v=bytes[k] or 0
        if math.floor(v/mask)%2==0 then bytes[k]=v+mask end
      end
    end
    if yieldFn and j%2000==0 then yieldFn() end
  end
  local chars={}
  for i=1,math.ceil(self.n^3/8) do chars[i]=string.char(bytes[i] or 0) end
  local packed=table.concat(chars)
  if packed~=self.packed then self.revision=(self.revision or 0)+1;self.components=nil end
  self.packed=packed; self.blocks=blocks
end
function W:observe(pos,block)
  local i=self:index(pos);if not i then return end
  local k=math.floor(i/8)+1;local mask=2^(i%8);local value=self.packed:byte(k)
  local was=math.floor(value/mask)%2==1;local blocked=block and not transient[block.name] or false
  if was~=blocked then
    value=value+(blocked and mask or -mask)
    self.packed=self.packed:sub(1,k-1)..string.char(value)..self.packed:sub(k+1)
    self.revision=(self.revision or 0)+1;self.components=nil
  end
  self.blocks[U.key(pos)]=block and {name=block.name,tags=block.tags or {},x=pos.x,y=pos.y,z=pos.z} or nil
end
-- Components contain only surveyed solids. Moving workers must never poison
-- shared reachability. Publish completion only after the entire flood finishes.
function W:component(source,yieldFn,onlyCached)
  local floor=math.floor;local packed=self.packed;local n=self.n;local plane=n*n
  local masks={1,2,4,8,16,32,64,128}
  local function blocked(id) return floor(packed:byte(floor(id/8)+1)/masks[id%8+1])%2==1 end
  if blocked(source) then return nil end
  local cache=self.components
  if onlyCached and (not cache or not cache.complete[cache.labels[source]]) then return nil end
  if not cache then cache={labels={},complete={},serial=0,scanned=0};self.components=cache end
  local labels=cache.labels;local known=labels[source]
  if known then
    if cache.complete[known] then return known,labels end
    return nil
  end
  cache.serial=cache.serial+1;local component=cache.serial
  local queue={source};local at=1;labels[source]=component
  local function visit(id)
    if not labels[id] and not blocked(id) then labels[id]=component;queue[#queue+1]=id end
  end
  while at<=#queue do
    local id=queue[at];local x=id%n;local z=floor(id/n)%n;local y=floor(id/plane)
    if z>0 then visit(id-n) end
    if x<n-1 then visit(id+1) end
    if z<n-1 then visit(id+n) end
    if x>0 then visit(id-1) end
    if y<n-1 then visit(id+plane) end
    if y>0 then visit(id-plane) end
    if yieldFn and at%1000==0 then
      yieldFn()
      -- A scanner or observation may replace topology while this loop yields.
      if self.components~=cache then return nil end
    end
    at=at+1
  end
  cache.complete[component]=true;cache.scanned=cache.scanned+#queue
  return component,labels
end
function W:snapshot() return {center=self.center,radius=self.radius,packed=self.packed} end
return W
