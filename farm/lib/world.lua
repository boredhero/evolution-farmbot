-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local W={}; W.__index=W
function W.new(center,radius)
  local n=radius*2+1
  return setmetatable({center=U.copy(center),radius=radius,n=n,
    min={x=center.x-radius,y=center.y-radius,z=center.z-radius},
    packed=string.rep(string.char(255),math.ceil(n*n*n/8)),blocks={}},W)
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
  for j,b in ipairs(scan) do
    local p=U.add(self.center,b)
    local i=self:index(p)
    if i and b.name and b.name~='minecraft:air' then
      blocks[U.key(p)]={name=b.name,tags=b.tags or {},x=p.x,y=p.y,z=p.z}
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
  self.packed=table.concat(chars); self.blocks=blocks
end
function W:snapshot() return {center=self.center,radius=self.radius,packed=self.packed} end
return W
