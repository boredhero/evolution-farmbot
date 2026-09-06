-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local C={}
local definitions={
 ['minecraft:wheat']={age=7,seed='minecraft:wheat_seeds'},
 ['minecraft:carrots']={age=7,seed='minecraft:carrot'},
 ['minecraft:potatoes']={age=7,seed='minecraft:potato'},
 ['minecraft:beetroots']={age=3,seed='minecraft:beetroot_seeds'},
 ['actuallyadditions:canola']={age=7,seed='actuallyadditions:canola_seeds'},
 ['actuallyadditions:coffee']={age=7,seed='actuallyadditions:coffee_beans'},
 ['actuallyadditions:rice']={age=7,seed='actuallyadditions:rice_seeds'},
 ['actuallyadditions:flax']={age=7,seed='actuallyadditions:flax_seeds'},
 ['farmersdelight:cabbages']={age=7,seed='farmersdelight:cabbage_seeds'},
 ['farmersdelight:onions']={age=7,seed='farmersdelight:onion'},
 ['farmersdelight:tomatoes']={age=3,seed='farmersdelight:tomato_seeds'},
 ['cottonly:cotton_plant']={age=7,seed='cottonly:cotton_seeds'},
 ['hexerei:sage_crop']={age=7,seed='hexerei:sage_seed'},
 ['minecraft:nether_wart']={age=3,seed='minecraft:nether_wart',support='minecraft:soul_sand'},
 ['minecraft:sweet_berry_bush']={age=3,seed='minecraft:sweet_berries',support='minecraft:grass_block'},
 ['biomeswevegone:blueberry_bush']={age=3,seed='biomeswevegone:blueberries',support='minecraft:grass_block'},
 ['minecraft:torchflower']={seed='minecraft:torchflower_seeds',plantedName='minecraft:torchflower_crop'},
 ['minecraft:torchflower_crop']={age=2,seed='minecraft:torchflower_seeds'},
 ['minecraft:pitcher_crop']={age=4,seed='minecraft:pitcher_pod',half='lower'},
}
-- Guaranteed minimum drop in the installed 1.21.1 loot tables (not expected yield).
local guaranteed={['minecraft:carrots']=true,['minecraft:potatoes']=true,
 ['minecraft:nether_wart']=true,['minecraft:sweet_berry_bush']=true,
 ['biomeswevegone:blueberry_bush']=true,['farmersdelight:onions']=true,
 ['actuallyadditions:canola']=true,['actuallyadditions:coffee']=true,
 ['actuallyadditions:rice']=true,['actuallyadditions:flax']=true}
function C.rule(name,custom)
  if custom and custom[name] then return custom[name] end
  if definitions[name] then return definitions[name] end
  local kind=name:match('^mysticalagriculture:(.+)_crop$')
  if kind and kind~='mystical_resource' and kind~='mystical_mob' then
    return {age=7,seed='mysticalagriculture:'..kind..'_seeds'}
  end
end
function C.farmland(name)
  return name=='minecraft:farmland' or name:match('^mysticalagriculture:.+_farmland$')~=nil
end
function C.tag(tags,name)
  if tags[name] then return true end
  for _,tag in ipairs(tags) do if tag==name then return true end end
  return false
end
function C.candidate(world,b,custom)
  local pos={x=b.x,y=b.y,z=b.z};local below=U.add(pos,U.dirs[6])
  local rule=C.rule(b.name,custom)
  local job={pos=pos,name=b.name,key=U.key(pos),mode='replant'}
  if rule then
    if rule.support then
      if world:name(below)~=rule.support then return nil end
    elseif not C.farmland(world:name(below)) then return nil end
    job.age=rule.age;job.seed=rule.seed;job.half=rule.half
    job.plantedName=rule.plantedName
    job.guaranteedSeed=guaranteed[b.name] or b.name:match('^mysticalagriculture:.+_crop$')~=nil
    return job
  elseif b.name=='minecraft:melon' or b.name=='minecraft:pumpkin' then
    job.mode='fruit';return job
  elseif b.name=='minecraft:cocoa' then
    job.mode='cocoa';job.age=2;job.seed='minecraft:cocoa_beans';job.guaranteedSeed=true;job.supports={}
    for i=1,4 do
      local p=U.add(pos,U.dirs[i])
      if world:name(p)=='minecraft:jungle_log' then job.supports[#job.supports+1]=i end
    end
    if #job.supports>0 then return job end
  elseif b.name=='minecraft:sugar_cane' then
    -- Harvest only the top of a column; the root is never a target.
    if world:name(U.add(pos,U.dirs[5]))=='minecraft:sugar_cane' then return nil end
    local p=below;local height=0
    while world:inside(p) and world:name(p)=='minecraft:sugar_cane' do
      height=height+1;p=U.add(p,U.dirs[6])
    end
    if height>0 and (world:name(p)=='minecraft:sand' or world:name(p)=='minecraft:red_sand') then
      job.mode='cane';return job
    end
  elseif b.name=='farmersdelight:rice_panicles' and world:name(below)=='farmersdelight:rice' then
    job.mode='rice';job.age=3;return job
  elseif b.name=='immersiveengineering:hemp' and world:name(below)==b.name
    and C.farmland(world:name(U.add(below,U.dirs[6]))) then
    job.mode='upper';job.half='upper';return job
  elseif b.name=='minecraft:cactus' or b.name=='minecraft:bamboo' then
    if world:name(U.add(pos,U.dirs[5]))==b.name then return nil end
    local p=below;local height=0
    while world:inside(p) and world:name(p)==b.name do height=height+1;p=U.add(p,U.dirs[6]) end
    local soil=world:name(p)
    if height>0 and (soil=='minecraft:sand' or soil=='minecraft:red_sand'
      or (b.name=='minecraft:bamboo' and (soil=='minecraft:grass_block' or soil=='minecraft:dirt'))) then
      job.mode='cane';job.onlyAbove=b.name=='minecraft:cactus';return job
    end
  elseif b.name=='minecraft:kelp' and world:name(below)=='minecraft:kelp_plant' then
    job.mode='upper';job.onlyAbove=true;return job
  elseif b.name=='minecraft:cave_vines' or b.name=='minecraft:cave_vines_plant' then
    job.mode='use';job.item='minecraft:stick';job.berries=true;return job
  elseif b.name=='farmersdelight:tomatoes_on_rope' then
    local p=below
    while world:inside(p) and world:name(p)==b.name do p=U.add(p,U.dirs[6]) end
    if world:name(p)=='farmersdelight:tomatoes' and C.farmland(world:name(U.add(p,U.dirs[6]))) then
      job.mode='use';job.age=3;job.item='minecraft:stick';return job
    end
  elseif C.tag(b.tags or {},'minecraft:crops') or C.tag(b.tags or {},'c:crops') then
    if C.farmland(world:name(below)) and not b.name:match('_stem$') then
      job.mode='probe';return job
    end
  end
end
function C.discover(world,custom,yieldFn)
  local jobs,count={},0
  for _,b in pairs(world.blocks) do
    local job=C.candidate(world,b,custom)
    if job then jobs[job.key]=job end
    count=count+1;if yieldFn and count%2000==0 then yieldFn() end
  end
  return jobs
end
function C.goals(job)
  local goals={}
  if job.mode=='cocoa' then
    for _,i in ipairs(job.supports) do
      local d=U.dirs[i];goals[#goals+1]=U.add(job.pos,{x=-d.x,y=0,z=-d.z})
    end
  else
    -- Above is convenient, but horizontal harvesting handles low ceilings.
    goals[1]=U.add(job.pos,U.dirs[5])
    if not job.onlyAbove then for i=1,4 do goals[#goals+1]=U.add(job.pos,U.dirs[i]) end end
  end
  return goals
end
function C.ready(job,block)
  if not block or block.name~=job.name then return false,'changed' end
  if job.mode=='probe' then return false,'unsupported' end
  if block.state and block.state.ropelogged then return false,'unsupported_rope' end
  if job.age and (not block.state or block.state.age~=job.age) then return false,'growing' end
  if job.half and (not block.state or block.state.half~=job.half) then return false,'wrong_half' end
  if job.berries and (not block.state or not block.state.berries) then return false,'growing' end
  if job.mode=='use' and not C.tag(block.tags or {},'computercraft:turtle_can_use') then
    return false,'interaction_tag_missing'
  end
  if job.mode=='cocoa' then
    local names={'north','east','south','west'};local found=false
    for _,i in ipairs(job.supports) do if block.state.facing==names[i] then found=true end end
    if not found then return false,'support_changed' end
  end
  return true
end
return C
