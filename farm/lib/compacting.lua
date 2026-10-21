-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local Seeds=require('farm.lib.seed_recipes')
local M={}
M.recipes={
 {key='melon',label='Melon slices -> melon blocks',item='minecraft:melon_slice',output='minecraft:melon'},
 {key='wheat',label='Wheat -> hay bales',item='minecraft:wheat',output='minecraft:hay_block'},
 {key='cabbage',label='Cabbages -> cabbage crates',item='farmersdelight:cabbage',output='farmersdelight:cabbage_crate'},
 {key='tomato',label='Tomatoes -> tomato crates',item='farmersdelight:tomato',output='farmersdelight:tomato_crate'},
 {key='onion',label='Onions -> onion crates',item='farmersdelight:onion',output='farmersdelight:onion_crate'},
 {key='rice',label='Rice -> rice bags',item='farmersdelight:rice',output='farmersdelight:rice_bag'},
 {key='panicle',label='Rice panicles -> rice bales',item='farmersdelight:rice_panicle',output='farmersdelight:rice_bale'},
 {key='straw',label='Straw -> straw bales',item='farmersdelight:straw',output='farmersdelight:straw_bale'},
}
function M.plan(settings,inventory,keep,needed)
  local out={};local reserve={}
  for item,n in pairs(keep or {}) do reserve[item]=n end
  -- Preserve produce required to replenish known planting stocks through seed recipes.
  for seed,n in pairs(needed or {}) do
    local deficit=math.max(0,n-(inventory[seed] or 0))
    for _,r in ipairs(Seeds.recipes[seed] or {}) do
      reserve[r.item]=math.max(reserve[r.item] or 0,math.ceil(deficit/r.count))
    end
  end
  for _,r in ipairs(M.recipes) do if settings and settings[r.key]==true then
    local batches=math.floor(((inventory[r.item] or 0)-(reserve[r.item] or 0))/9)
    if batches>0 then out[#out+1]={key=r.key,item=r.item,output=r.output,count=1,inputCount=9,batches=batches} end
  end end
  return out
end
return M
