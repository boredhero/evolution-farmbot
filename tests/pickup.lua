-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local P=require('farm.lib.pickup')
local b;local sucked=0
 turtle={getItemCount=function()return 0 end,inspectDown=function()return b~=nil,b end,
 suckDown=function()sucked=sucked+1;return true end}
assert(P.collect('Down'));b={name='biomeswevegone:blueberry_bush'};assert(P.collect('Down'))
for _,name in ipairs({'minecraft:chest','minecraft:crafter','mod:seed_storage'}) do
 b={name=name};assert(not P.collect('Down'))
end
assert(sucked==2)
local q={};P.add(q,{name='berries',mode='use',pos={x=1,y=64,z=1}})
assert(q['0,65,0'] and q['2,65,2'])
P.add(q,{name='berries',mode='use',pos={x=1,y=70,z=1}});assert(q['0,71,0'])
P.add(q,{mode='cane',rootY=60,pos={x=10,y=62,z=10}});assert(q['10,61,10'])
print('PASS nearby ground pickup covers crop heights and root level while refusing chests and unknown blocks')
