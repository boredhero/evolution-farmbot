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
