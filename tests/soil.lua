-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local H=require('farm.lib.soil')
local G=require('farm.lib.garden')
local job={pos={x=1,y=1,z=1},key='1,1,1',name='minecraft:wheat',seed='minecraft:wheat_seeds',mode='replant'}
local item={name='example:multitool',tags={['minecraft:hoes']=true}}
turtle={getItemDetail=function(slot) if slot==7 then return item end end,select=function(slot) assert(slot==7) end}
local soil={name='example:soil',tags={['minecraft:dirt']=true}};local uses=0
local function probe() return soil end
local function use() uses=uses+1;soil={name=uses==1 and 'minecraft:dirt' or 'minecraft:farmland'};return true end
assert(H.recover(job,nil,probe,use));assert(uses==2)
assert(not H.recover(job,nil,probe,use));assert(uses==2)
soil={name='minecraft:stone'};assert(not H.recover(job,nil,probe,use));assert(uses==2)
soil=nil;local ok,err=H.recover(job,nil,probe,use);assert(not ok and err:find('soil at 1,0,1: air',1,true))
soil={name='minecraft:dirt'};item=nil;ok,err=H.recover(job,nil,probe,use);assert(not ok and err:find('No carried hoe',1,true))
item={name='minecraft:wooden_hoe'};assert(H.isHoe(item))
uses=0;ok,err=H.recover(job,nil,probe,function() uses=uses+1;return false,'protected' end)
assert(not ok and uses==1 and err:find('protected',1,true))
assert(not H.recover({name='minecraft:nether_wart',seed='minecraft:nether_wart',mode='replant'},nil,function() error('Must not inspect wart soil') end,use))
local garden=G.new();garden:observe(job,0);garden.data.plots[job.key].debt=true
local world={name=function() return 'minecraft:air' end,block=function() return soil end}
garden:scan(world,{},1,2);assert(garden.data.plots[job.key].debt)
soil={name='minecraft:stone'};garden:scan(world,{},3,4);assert(not garden.data.plots[job.key])
print('PASS tagged hoes/soil, two-stage tilling, missing/broken tools, non-farmland crop safety and durable dirt repair debts')
