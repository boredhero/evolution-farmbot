-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local V=require('farm.lib.vines')
local G=require('farm.lib.garden')
local job={pos={x=0,y=0,z=0},name='minecraft:wheat',key='0,0,0',mode='replant',seed='minecraft:wheat_seeds'}
local vine={name='minecraft:vine'}
assert(V.allowed(job,{x=0,y=3,z=0},vine))
assert(not V.allowed(job,{x=0,y=4,z=0},vine))
assert(not V.allowed(job,{x=1,y=1,z=0},vine))
assert(not V.allowed(job,{x=0,y=0,z=0},vine))
assert(not V.allowed(job,{x=0,y=1,z=0},{name='minecraft:cave_vines'}))
job.repair=true;assert(V.allowed(job,job.pos,vine))
local world={block=function(_,p) return p.y<0 and {name='minecraft:farmland'} or vine end,name=function() return 'minecraft:vine' end}
local list=V.scan(job,world);assert(#list==4 and list[1].y==3 and list[4].y==0)
assert(V.goals(job)[1].y==4)
local g=G.new();local p=g:observe(job,0);p.debt=true;p.live=false
g:scan(world,{},1,2);assert(g.data.plots[job.key].debt)
job.version=p.version;g:finish(job,nil,vine,world,nil,3);assert(g.data.plots[job.key].debt)
print('PASS vine clearance bounded to known crop column and pending gaps, excludes crop vines and preserves repair debts')
