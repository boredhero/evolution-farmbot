-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local W=require('farm.lib.world')
local P=require('farm.lib.path')
local U=require('farm.lib.util')
local function pos(x,y,z) return {x=x,y=y,z=z} end
local w=W.new(pos(0,0,0),4);local wall={}
for y=-4,4 do for z=-4,4 do wall[#wall+1]={x=0,y=y,z=z,name='minecraft:stone'} end end
w:ingest(wall)
local start,goal=pos(-1,0,0),pos(1,0,0)
w:component(w:index(start))
local path,reason,expanded=P.find(w,start,{goal})
assert(not path and reason=='No route in surveyed space' and expanded==0)
local cache=w.components;local scanned=cache.scanned
for i=1,16 do assert(not P.find(w,pos(-1,i%4,0),{goal})) end
assert(w.components==cache and cache.scanned==scanned,'Disconnected goals must reuse completed source component')
local revision=w.revision
w:observe(pos(0,0,0),{name='minecraft:dirt'});assert(w.revision==revision and w.components==cache)
w:ingest(wall);assert(w.revision==revision and w.components==cache)
w:observe(pos(0,0,0),false);assert(w.revision==revision+1 and not w.components)
path=P.find(w,start,{goal});assert(path and #path==2)
w:component(w:index(start));cache=w.components
local blocked=P.find(w,start,{goal},{avoid={['0,0,0']=true},limit=1000})
assert(not blocked and w.components==cache)
assert(#assert(P.find(w,start,{goal}))==2,'Temporary traffic must not poison static reachability')
w:observe(pos(0,0,0),{name='minecraft:stone'});assert(not P.find(w,start,{goal}))
w:ingest({});assert(#assert(P.find(w,start,{goal}))==2)
print('PASS static connectivity rejects disconnected goals once and invalidates only on changed occupancy')
local large=W.new(pos(0,0,0),10);large:ingest({});local changed=false
local component=large:component(large:index(pos(0,0,0)),function()
  if not changed then changed=true;large:observe(pos(1,0,0),{name='minecraft:stone'}) end
end)
assert(changed and component==nil,'A topology change during yielding must discard incomplete labels')
assert(#assert(P.find(large,pos(0,0,0),{pos(2,0,0)}))==4)
large:observe(pos(0,0,0),{name='minecraft:stone'})
assert(#assert(P.find(large,pos(0,0,0),{pos(-1,0,0)}))==1,'Blocked source retains original escape behavior')
print('PASS connectivity tolerates scanner changes during yielding and blocked-source escape')

local easy=W.new(pos(0,0,0),32);easy:ingest({})
assert(#assert(P.find(easy,pos(0,0,0),{pos(4,0,0)}))==4)
assert(not easy.components,'Easy cold routes must not flood the entire scanner volume')
local sealed={};for y=-32,32 do for z=-32,32 do sealed[#sealed+1]={x=0,y=y,z=z,name='minecraft:stone'} end end
easy:ingest(sealed)
local first,_,count=P.find(easy,pos(-1,0,0),{pos(1,0,0)})
assert(not first and count==1000 and easy.components)
local _,_,cached=P.find(easy,pos(-2,0,0),{pos(1,0,0)})
assert(cached==0)
print('PASS easy routes skip cold connectivity flood while expensive failures warm a reusable cache')
local pocket=W.new(pos(0,0,0),16);local shell={}
-- One-cell doorway is normally open, then temporarily occupied by a worker.
for x=3,7 do for y=-2,2 do for z=-2,2 do
  if (x==3 or x==7 or y==-2 or y==2 or z==-2 or z==2) and not (x==3 and y==0 and z==0) then
    shell[#shell+1]={x=x,y=y,z=z,name='minecraft:stone'}
  end
end end end
pocket:ingest(shell)
local origin,destination=pos(0,0,0),pos(5,0,0)
assert(#assert(P.find(pocket,origin,{destination}))==5)
local rejected,why,cost=P.find(pocket,origin,{destination},{avoid={['3,0,0']=true}})
assert(not rejected and why=='No route in surveyed space' and cost==1000)
assert(not pocket.components,'A sealed small goal pocket must avoid a full static component flood')
assert(#assert(P.find(pocket,origin,{destination}))==5,'Reverse traffic failure must not survive the blocker leaving')
-- A second accessible destination prevents the sealed target from rejecting
-- the entire request, even when that destination is on another elevation.
local choices={destination,pos(-8,4,2)}
local path=P.find(pocket,origin,choices,{avoid={['3,0,0']=true}})
assert(path and #path==14 and P.valid(pocket,origin,path,{['3,0,0']=true}))
print('PASS bounded reverse search rejects temporary sealed pockets without poisoning future or multi-goal routes')
