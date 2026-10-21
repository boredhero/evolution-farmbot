-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local C=require('farm.lib.crops')
local U=require('farm.lib.util')
local H={}
function H.isHoe(item)
  if not item then return false end
  local tags=item.tags or {}
  return C.tag(tags,'minecraft:hoes') or C.tag(tags,'c:tools/hoe') or C.tag(tags,'forge:tools/hoes')
    or item.name:match('_hoe$')~=nil
end
function H.find()
  for slot=1,16 do if H.isHoe(turtle.getItemDetail(slot,true)) then return slot end end
end
function H.recover(job,custom,probe,use)
  if not C.needsFarmland(job,custom) then return false,'Crop does not use tilled soil' end
  local where=U.key(U.add(job.pos,U.dirs[6]))
  local block,err=probe()
  if err then return false,err end
  local function report(reason) return reason..'; soil at '..where..': '..(block and block.name or 'air') end
  if C.farmland(block) then return false,report('Soil is already farmland') end
  if not C.dirt(block) then return false,report('Soil is not tagged dirt; left unchanged') end
  local slot=H.find();if not slot then return false,report('No carried hoe') end
  -- Coarse/rooted dirt may need two uses. The actual game decides whether a modded soil is tillable.
  for _=1,2 do
    turtle.select(slot)
    local ok,why=use()
    block,err=probe();if err then return false,err end
    if C.farmland(block) then return true end
    if not ok or not C.dirt(block) then return false,report('Hoe could not restore farmland: '..tostring(why or 'unchanged')) end
    slot=H.find();if not slot then return false,report('Hoe exhausted before farmland was restored') end
  end
  return false,report('Hoe did not produce farmland after two uses')
end
return H
