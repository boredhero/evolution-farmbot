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

w=W.new({x=0,y=0,z=0},8)
-- Match the AP 0.8 scan captured on the live server, including registry-qualified tags.
for _,tags in ipairs({{['minecraft:block/c:sands']=true},{['minecraft:block/minecraft:sand']=true},
 {'minecraft:block/c:sands'},{['c:sands']=true}}) do
 w:ingest({{x=0,y=0,z=0,name='biomeswevegone:windswept_sand',tags=tags},
 {x=0,y=1,z=0,name='minecraft:cactus'},{x=0,y=2,z=0,name='minecraft:cactus'},
 {x=0,y=3,z=0,name='minecraft:cactus'}})
 local jobs=C.discover(w);local j=jobs['0,3,0']
 assert(j and j.rootY==1 and j.onlyAbove and not jobs['0,1,0'] and not jobs['0,2,0'])
 local route,goal=P.find(w,{x=3,y=4,z=0},C.goals(j))
 assert(route and goal.x==0 and goal.y==4 and goal.z==0)
end
assert(C.dirt({name='test:dirt',tags={['minecraft:block/minecraft:dirt']=true}}))
assert(C.farmland({name='test:farmland',tags={['minecraft:block/c:farmlands']=true}}))
assert(not C.tag({['minecraft:item/c:sands']=true},'c:sands'))
assert(not C.tag({['minecraft:block/c:sands']=false},'c:sands'))
print('PASS actual AP registry-qualified sand tags discover tall cactus with reachable top-only access; soil tags and ordinary turtle tags remain compatible')

for _,name in ipairs({'minecraft:melon','minecraft:pumpkin','biomeswevegone:pale_pumpkin'}) do
 local j=crop(name,'minecraft:dirt')
 assert(j and j.mode=='fruit' and not j.seed and j.crop==name)
 assert(C.ready(j,{name=name}))
 assert(not C.ready(j,{name='minecraft:air'}))
end
for _,name in ipairs({'biomeswevegone:pale_pumpkin_stem','biomeswevegone:attached_pale_pumpkin_stem',
 'minecraft:pumpkin_stem','minecraft:attached_pumpkin_stem'}) do
 w:ingest({{x=0,y=0,z=0,name='minecraft:farmland'},
 {x=0,y=1,z=0,name=name,tags={['minecraft:block/minecraft:crops']=true}}})
 assert(not next(C.discover(w)),'preserve planted stem '..name)
end
assert(not crop('biomeswevegone:carved_pale_pumpkin'))
print('PASS pale pumpkin fruit is harvestable without replanting; growing/attached stems and carved decorations are preserved')

for height=1,3 do
 local scan={{x=0,y=0,z=0,name='biomeswevegone:windswept_sand',tags={['minecraft:block/c:sands']=true}}}
 for y=1,height do scan[#scan+1]={x=0,y=y,z=0,name='minecraft:cactus'} end
 scan[#scan+1]={x=0,y=height+1,z=0,name='minecraft:cactus_flower'};w:ingest(scan)
 local jobs=C.discover(w);local j=jobs['0,'..(height+1)..',0'];local n=0;for _ in pairs(jobs)do n=n+1 end
 assert(n==1 and j and j.crop=='minecraft:cactus' and j.columnName=='minecraft:cactus' and j.rootY==1)
 assert(j.roundKey=='0,1,0' and C.ready(j,{name='minecraft:cactus_flower'}))
 local path,goal=P.find(w,{x=3,y=height+2,z=0},C.goals(j));assert(path and goal.y==height+2)
end
assert(not crop('minecraft:cactus_flower','minecraft:sand'),'do not harvest unsupported decorative flowers')
print('PASS cactus flowers share the cactus round, expose an above-flower approach and preserve single-block roots on tagged sand')
