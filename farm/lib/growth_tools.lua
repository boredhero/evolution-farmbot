-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local C=require('farm.lib.crops')
local U=require('farm.lib.util')
local T={}
T.options={{key='autoWorms',label='Auto-place worms'},{key='autoBoneMeal',label='Use bone meal on current crop'}}
function T.defaults(settings)
  for _,o in ipairs(T.options) do if settings[o.key]==nil then settings[o.key]=true end end
end
function T.reserves(settings,seeds,keep)
  if settings.autoWorms then seeds['actuallyadditions:worm']=true;keep['actuallyadditions:worm']=16 end
  if settings.autoBoneMeal then seeds['minecraft:bone_meal']=true;keep['minecraft:bone_meal']=64 end
end
local function slot(name)
  for i=1,16 do local d=turtle.getItemDetail(i);if d and d.name==name and d.count>0 then return i end end
end
function T.worm(job,side,state,now,save)
  local i=slot('actuallyadditions:worm');if not i then return false end
  local key=U.key(job.pos);state.attempts=state.attempts or {}
  if now-(state.attempts[key] or -math.huge)<600 then return false end
  if now-(state.window or -math.huge)>=60 then state.window=now;state.used=0 end
  if (state.used or 0)>=6 then return false end
  state.used=(state.used or 0)+1;state.attempts[key]=now
  local n,oldest,when=0
  for k,t in pairs(state.attempts) do n=n+1;if not when or t<when then oldest,when=k,t end end
  if n>128 then state.attempts[oldest]=nil end
  save() -- A restart must not create an unbounded retry loop.
  turtle.select(i);local before=turtle.getItemCount(i)
  turtle['place'..side]()
  local placed=turtle.getItemCount(i)==before-1
  if placed then state.placed=(state.placed or 0)+1;save() end
  return placed
end
function T.boneMeal(job,block,side,inspect)
  local used=0
  for _=1,4 do
    local ready,reason=C.ready(job,block)
    if ready or reason~='growing' or not block or block.name~=job.name then break end
    local i=slot('minecraft:bone_meal');if not i then break end
    turtle.select(i);local before=turtle.getItemCount(i)
    turtle['place'..side]()
    local consumed=before-turtle.getItemCount(i)
    local after=inspect()
    if consumed==1 then used=used+1 end
    local progressed=after and after.name~=block.name
    if after and after.state and block.state then
      progressed=progressed or after.state.age~=block.state.age or after.state.berries~=block.state.berries or after.state.half~=block.state.half
    end
    block=after
    if consumed~=1 or not progressed then break end
  end
  return block,used
end
return T
