-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local Worker=require('farm.worker')
local selected=1;local fuel=0
local slots={
  [1]={name='wheat',count=60},[2]={name='wheat',count=20},
  [3]={name='wheat',count=10},[4]={name='minecraft:coal',count=12},
  [5]={name='seed',count=64},[6]={name='seed',count=3},
  [7]={name='special',count=1,variant=1},[8]={name='special',count=1,variant=2}}
turtle={getItemDetail=function(i) return slots[i] end,
  getItemCount=function(i) return slots[i] and slots[i].count or 0 end,
  getItemSpace=function(i) return 64-(slots[i] and slots[i].count or 0) end,
  select=function(i) selected=i end,
  refuel=function() fuel=fuel+slots[selected].count*80;slots[selected]=nil;return true end,
  compareTo=function(i) return slots[i] and slots[selected].name==slots[i].name and slots[selected].variant==slots[i].variant end,
  transferTo=function(i)
    local n=math.min(slots[selected].count,64-slots[i].count)
    slots[i].count=slots[i].count+n;slots[selected].count=slots[selected].count-n
    if slots[selected].count==0 then slots[selected]=nil end
    return true
  end}
Worker.compact()
assert(slots[1].count==64 and slots[2].count==26 and slots[3]==nil)
assert(slots[4]==nil and fuel==960)
assert(slots[5].count==64 and slots[6].count==3)
assert(slots[7].variant==1 and slots[8].variant==2)
print('PASS packing merges compatible stacks without loss, respects full/different stacks, consumes carried fuel')
