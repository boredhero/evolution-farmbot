-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local C=require('farm.lib.crops')
local U=require('farm.lib.util')
local P={}
local plants={['minecraft:sugar_cane']=true,['minecraft:cactus']=true,['minecraft:cocoa']=true,
 ['minecraft:melon']=true,['minecraft:pumpkin']=true,['immersiveengineering:hemp']=true,
 ['farmersdelight:rice']=true,['farmersdelight:rice_panicles']=true,
 ['biomeswevegone:aloe_vera']=true,['biomeswevegone:blooming_aloe_vera']=true,
 ['minecraft:cave_vines']=true,['minecraft:cave_vines_plant']=true,['farmersdelight:tomatoes_on_rope']=true}
function P.room()
  for i=1,16 do if turtle.getItemCount(i)==0 or (turtle.getItemSpace and turtle.getItemSpace(i)>0) then return true end end
  return false
end
function P.collect(side)
  if not P.room() then return false end
  local found,b=turtle['inspect'..side]()
  if found and not plants[b.name] and not C.rule(b.name) then return false end
  -- Never suck from a chest, machine, or unknown mod block while collecting ground drops.
  return turtle['suck'..side]()
end
function P.add(queue,job)
  local y=job.pos.y+1
  if job.rootY then y=job.rootY+1 elseif job.mode=='upper' or job.mode=='rice' then y=job.pos.y end
  for dx=-1,1 do for dz=-1,1 do
    local p={x=job.pos.x+dx,y=y,z=job.pos.z+dz};queue[U.key(p)]=p
  end end
end
return P
