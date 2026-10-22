-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local H=require('farm.lib.sheep');local W=require('farm.lib.world');local G=require('farm.lib.garden');local B=require('farm.lib.batches')
local origin={x=100,y=64,z=-100}
local w=W.new(origin,32);w:ingest({{x=0,y=0,z=0,name='advancedperipherals:environment_detector'}})
local calls=0;local entries={{uuid='a',name='minecraft:sheep',x=1.2,y=-0.5,z=-1.2,baby=false},
 {uuid='baby',name='minecraft:sheep',x=0,y=0,z=0,baby=true},{uuid='cow',name='minecraft:cow',x=0,y=0,z=0}}
peripheral={find=function(kind)assert(kind=='environment_detector');return {scanEntities=function(radius,detailed,filter)
 assert(radius==16 and not detailed and filter=='minecraft:sheep');calls=calls+1;return entries end}end}
local h=H.new();local list=h:poll(w,1);local j=assert(list['sheep:a']);assert(not list['sheep:baby'] and not list['sheep:cow'])
assert(j.pos.x==101 and j.pos.y==65 and j.pos.z==-101)
h:poll(w,2);assert(calls==1)
local g=G.new();H.sync(g,list,{},1);assert(#g:tasks({},nil,1)==0)
local tasks=g:tasks({['minecraft:shears']=1},nil,1);assert(#tasks==1)
local version=tasks[1].version
entries[1].x=2.2;H.sync(g,h:poll(w,4),{},4)
assert(g.data.plots[j.key].job.pos.x==102 and g.data.plots[j.key].version==version)
g:scan(w,{},5,5);assert(g.data.plots[j.key],'Block survey must not delete tracked sheep')
local state={};local all={{job=g.data.plots[j.key].job}}
local first=B.order(state,all,all,8,5);assert(#first==1);B.assigned(state,8,first[1].job)
assert(#B.order(state,all,all,9,5)==0,'Only one worker may own the sheep round')
B.finished(state,8,first[1].job)
local wheat={key='wheat',name='minecraft:wheat',pos={x=0,y=0,z=0}}
all[#all+1]={job=wheat};local nextJobs=B.order(state,all,all,9,6)
assert(#nextJobs==1 and nextJobs[1].job.key=='wheat','Sheep cannot restart before other crop types finish')
H.sync(g,{}, {},7);assert(not next(g.data.plots))
peripheral.find=function()return nil end
local missing,err=h:poll(w,8);assert(not missing and err:find('Environment Detector'))
assert(not h:poll(w,9),'Cached detector errors must not look like a successful scan')
print('PASS sheep detector coordinates, adult filtering, cooldown, moving identity, tool gating and exclusive fleet cycles')
