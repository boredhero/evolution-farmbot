-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local T=require('farm.lib.growth_tools')
local settings={};T.defaults(settings);assert(settings.autoWorms and settings.autoBoneMeal)
settings.autoWorms=false;T.defaults(settings);assert(not settings.autoWorms)
local seeds,keep={},{};T.reserves(settings,seeds,keep);assert(keep['minecraft:bone_meal']==64 and not seeds['actuallyadditions:worm'])
local job={name='minecraft:wheat',mode='replant',age=7,pos={x=0,y=1,z=0}}
local n,uses,kind,age=30,0,'minecraft:bone_meal',0
local rejected,stalled=false,false
local function use()
 uses=uses+1
 if not rejected then n=n-1;if not stalled then age=math.min(7,age+2) end end
end
turtle={getItemDetail=function(i)if i==1 and n>0 then return {name=kind,count=n} end end,
 select=function()end,getItemCount=function()return n end,placeDown=use}
local function inspect()return {name=job.name,state={age=age}} end
local block,count=T.boneMeal(job,inspect(),'Down',inspect)
assert(count==4 and age==7 and n==26)
T.boneMeal(job,block,'Down',inspect);assert(uses==4)
age=0;rejected=true;T.boneMeal(job,inspect(),'Down',inspect);assert(uses==5 and n==26)
rejected=false;stalled=true;T.boneMeal(job,inspect(),'Down',inspect);assert(uses==6 and n==25)
kind='actuallyadditions:worm';local state={};local saves=0;rejected=true
for i=1,8 do job.pos.x=i;assert(not T.worm(job,'Down',state,100,function()saves=saves+1 end)) end
assert(state.used==6 and uses==12 and saves==6)
job.pos.x=1;T.worm(job,'Down',state,170,function()saves=saves+1 end);assert(uses==12)
job.pos.x=8;rejected=false;assert(T.worm(job,'Down',state,170,function()saves=saves+1 end));assert(state.placed==1 and n==24)
print('PASS growth tools preserve explicit settings, retain bounded supplies, stop rejected/stalled bone meal and try bounded distinct worm sites with persistent cooldowns')
