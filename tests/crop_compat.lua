-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local C=require('farm.lib.crops');local W=require('farm.lib.world');local U=require('farm.lib.util')
local w=W.new({x=0,y=0,z=0},5)
local function crop(name,soil)
  w:ingest({{x=0,y=0,z=0,name=soil or 'minecraft:farmland'},{x=0,y=1,z=0,name=name}})
  return C.candidate(w,{x=0,y=1,z=0,name=name})
end
local tomato=crop('farmersdelight:tomatoes');assert(tomato.plantedName=='farmersdelight:budding_tomatoes')
local budding=crop('farmersdelight:budding_tomatoes');assert(budding.seed==tomato.seed)
assert(not C.ready(budding,{name=budding.name,state={age=4}}))
for _,name in ipairs({'silentgear:flax_plant','silentgear:fluffy_plant','occultism:datura','ars_nouveau:magebloom_crop',
 'eternal_starlight:crinoa','eternal_starlight:pungency_fruit_vines','supplementaries:flax'}) do
 local j=crop(name);assert(j and j.seed and j.age==7)
 assert(not crop(name,'minecraft:dirt'))
end
assert(crop('ars_nouveau:magebloom_crop').seed=='ars_nouveau:magebloom_crop')
assert(crop('supplementaries:flax').half=='lower')
for _,soil in ipairs({'minecraft:sand','minecraft:dirt','minecraft:grass_block','minecraft:mud'}) do
 w:ingest({{x=0,y=0,z=0,name=soil},{x=0,y=1,z=0,name='minecraft:sugar_cane'},{x=0,y=2,z=0,name='minecraft:sugar_cane'}})
 assert(C.candidate(w,{x=0,y=2,z=0,name='minecraft:sugar_cane'}))
 assert(not C.candidate(w,{x=0,y=1,z=0,name='minecraft:sugar_cane'}))
end
w:ingest({{x=0,y=0,z=0,name='minecraft:sand'},{x=0,y=1,z=0,name='minecraft:cactus'}})
assert(not C.candidate(w,{x=0,y=1,z=0,name='minecraft:cactus'}))
for y=1,3 do for i=1,4 do assert(w:blocked(U.add({x=0,y=y,z=0},U.dirs[i]))) end end
assert(not C.ready({name='minecraft:cactus',mode='cane'},{name='minecraft:cactus'}))
w:ingest({{x=0,y=0,z=0,name='minecraft:sand'},{x=0,y=1,z=0,name='minecraft:cactus'},{x=0,y=2,z=0,name='minecraft:cactus'}})
local cactus=C.candidate(w,{x=0,y=2,z=0,name='minecraft:cactus'})
assert(cactus.rootY==1 and cactus.onlyAbove and #C.goals(cactus)==1)
assert(C.ready(cactus,{name='minecraft:cactus'}))
print('PASS tomato stages, audited crop types, sugar cane roots/soils, cactus upper-only harvest and growth clearance')

for _,name in ipairs({'minecraft:cactus','minecraft:sugar_cane','biomeswevegone:blooming_aloe_vera'}) do
 w:ingest({{x=0,y=0,z=0,name='biomeswevegone:windswept_sand',tags={'minecraft:sand'}},
 {x=0,y=1,z=0,name=name},{x=0,y=2,z=0,name=name}})
 local y=name=='biomeswevegone:blooming_aloe_vera' and 1 or 2
 local j=C.candidate(w,{x=0,y=y,z=0,name=name});assert(j,name..' on tagged sand')
end
w:ingest({{x=0,y=0,z=0,name='minecraft:sand'},
 {x=0,y=1,z=0,name='minecraft:bamboo'},{x=0,y=2,z=0,name='minecraft:bamboo'}})
assert(not next(C.discover(w)),'bamboo is explicitly excluded')
local P=require('farm.lib.path')
w:ingest({{x=0,y=0,z=0,name='minecraft:farmland'},
 {x=0,y=1,z=0,name='immersiveengineering:hemp'},
 {x=0,y=2,z=0,name='immersiveengineering:hemp'},
 {x=0,y=3,z=0,name='minecraft:wall_torch'}})
local hemp=C.candidate(w,{x=0,y=2,z=0,name='immersiveengineering:hemp'})
local path,goal=P.find(w,{x=2,y=3,z=0},C.goals(hemp))
assert(path and goal.y==2,'torch above hemp must select a side approach')
print('PASS tagged modded sand, excluded bamboo and side harvesting beneath torches')

for _,tag in ipairs({'c:farmlands','forge:farmland','neoforge:villager_farmlands'}) do
 w:ingest({{x=0,y=0,z=0,name='test:fertile_soil',tags={[tag]=true}},
 {x=0,y=1,z=0,name='minecraft:wheat'}})
 assert(C.candidate(w,{x=0,y=1,z=0,name='minecraft:wheat'}),'tagged farmland '..tag)
end
w:ingest({{x=0,y=0,z=0,name='test:loamy_dirt',tags={'minecraft:dirt'}},
 {x=0,y=1,z=0,name='biomeswevegone:blueberry_bush'}})
assert(C.candidate(w,{x=0,y=1,z=0,name='biomeswevegone:blueberry_bush'}))
assert(not C.farmland({name='test:decoration',tags={['minecraft:maintains_farmland']=true}}))
print('PASS modded farmland and dirt use semantic soil tags, not unrelated crop-support tags')
