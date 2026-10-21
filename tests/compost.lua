-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local M=require('farm.lib.compost')
local garden={data={plots={a={job={name='wheat',seed='minecraft:wheat_seeds'}},b={job={name='carrot',seed='minecraft:carrot'}}}}}
local inv={['minecraft:wheat_seeds']=64,['minecraft:carrot']=64}
assert(M.plan(garden,{pending={a='wheat'}},{},inv,{},{} )['minecraft:wheat_seeds']==nil)
local plan=M.plan(garden,{pending={}},{},inv,{},{});assert(plan['minecraft:wheat_seeds']==48 and not plan['minecraft:carrot'])
garden.data.plots.a.debt=true;assert(not next(M.plan(garden,{},{},inv,{},{})));garden.data.plots.a.debt=false
assert(not next(M.plan(garden,{},{{job={name='wheat'}}},inv,{},{})))
local count,level,selected,bone=64,0,1,0
sleep=function()if level==7 then level=8 end end
turtle={getItemDetail=function(i)if i==1 and count>0 then return {name='minecraft:wheat_seeds',count=count} end end,
 getItemCount=function(i)return i==1 and count or 0 end,select=function(i)selected=i end,
 inspectDown=function()return true,{name='minecraft:composter',state={level=level},tags={['computercraft:turtle_can_use']=true}} end,
 placeDown=function()assert(selected==1);if level==8 then level=0;bone=bone+1 elseif level<7 then count=count-1;level=level+1 end;return true end,
 suckDown=function()return true end}
assert(M.run('Down',plan)==48 and count==16 and bone==6)
local old=turtle.inspectDown;turtle.inspectDown=function()return true,{name='minecraft:chest'}end
assert(M.run('Down',{['minecraft:wheat_seeds']=2})==0 and count==16)
turtle.inspectDown=old;turtle.placeDown=function()return false end
assert(M.run('Down',{['minecraft:wheat_seeds']=2})==0 and count==16)
print('PASS completed-batch composting protects reserves, produce, active jobs and debts; stops safely on replacement or unsupported seeds')
