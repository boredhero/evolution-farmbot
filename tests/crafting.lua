-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local R=require('farm.lib.seed_recipes');local Craft=require('farm.lib.crafting')
local function run(seed,recipe,options)
  options=options or {}
  local slots={[1]={name=recipe.item,count=3}};local machine={};local selected=1;local saves=0;local pulses=0;local output=false
  local journal={}
  if options.busy then machine[1]={name='minecraft:diamond',count=1} end
  if options.resume then
    machine[1]={name=recipe.item,count=1};slots[1].count=2;journal={loaded=true,before=0,ingredientBefore=3}
  end
  turtle={getItemDetail=function(i)return slots[i] end,getItemSpace=function(i)return 64-(slots[i] and slots[i].count or 0) end,
    select=function(i)selected=i end,
    drop=function(n)
      assert(n==1 and saves>0 and not next(machine));slots[selected].count=slots[selected].count-1
      machine[1]={name=recipe.item,count=1};return true
    end}
  turtle.dropUp=turtle.drop;turtle.dropDown=turtle.drop
  peripheral={wrap=function()return {list=function()return machine end} end}
  redstone={getOutput=function()return output end,setOutput=function(_,value)
    output=value
    if value then pulses=pulses+1
      if not options.fail then slots[2]={name=seed,count=recipe.count};machine={} end
    end
  end}
  sleep=function()end
  local ok,err=Craft.run('front',seed,recipe,journal,function()saves=saves+1 end)
  assert(not output,'redstone must be reset')
  if options.busy then assert(not ok and slots[1].count==3 and pulses==0 and not journal.loaded)
  elseif options.fail then assert(not ok and journal.loaded and machine[1].count==1)
  else assert(ok,err);assert(slots[1].count==2 and slots[2].count==recipe.count and pulses==1) end
end
for seed,recipes in pairs(R.recipes) do for _,recipe in ipairs(recipes) do
  assert(R.find(seed,{[recipe.item]=1}).item==recipe.item)
  run(seed,recipe)
end end
local seed='farmersdelight:tomato_seeds';local recipe=R.recipes[seed][1]
run(seed,recipe,{busy=true});run(seed,recipe,{resume=true});run(seed,recipe,{fail=true})
assert(not R.find('not:a_seed',{['minecraft:diamond']=1}))
print('PASS all verified vanilla/modded single-item seed recipes, busy-station refusal, interrupted craft recovery, failed craft retention')
