-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local C=require('farm.lib.crops')
local V={}
function V.allowed(job,pos,block)
  if not job or not pos or not block or block.name~='minecraft:vine' then return false end
  local dy=pos.y-job.pos.y
  return job.mode=='replant' and pos.x==job.pos.x and pos.z==job.pos.z
    and dy<4 and (dy>=1 or (dy==0 and job.repair==true))
end
function V.scan(job,world)
  local list={}
  for dy=3,0,-1 do
    local pos=U.add(job.pos,{x=0,y=dy,z=0})
    if V.allowed(job,pos,world:block(pos)) then list[#list+1]=pos end
  end
  job.vines=list;return list
end
function V.goals(job)
  local target=job.vines and job.vines[1]
  return C.goals(target and {pos=target} or job)
end
return V
