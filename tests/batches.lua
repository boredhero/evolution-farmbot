-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local B=require('farm.lib.batches')
local function option(key,name,distance,ready)
  return {job={key=key,name=name},score=distance or 0,ready=ready}
end
local wheat1=option('w1','wheat',20,true)
local wheat2=option('w2','wheat',10,true)
local carrot=option('c1','carrot',1,true)
local all={wheat1,wheat2,carrot};local state={}
local ordered=B.order(state,all,all,1)
assert(ordered[1]==wheat2,'largest ready group wins over a nearer singleton')
B.assigned(state,1,wheat2.job);B.finished(state,1,wheat2.job)
ordered=B.order(state,all,all,1)
assert(ordered[1]==wheat1,'worker finishes its type despite immediate regrowth')
B.assigned(state,1,wheat1.job);B.finished(state,1,wheat1.job)
ordered=B.order(state,all,all,1)
assert(ordered[1]==carrot,'singleton must run before regrown wheat')
B.assigned(state,1,carrot.job);B.finished(state,1,carrot.job)
ordered=B.order(state,all,all,1);assert(state.cycle==2 and ordered[1]==wheat2)
print('PASS largest ready batch, nearest within crop, finite rounds prevent singleton starvation')

local many={}
for i=1,6 do many[#many+1]=option('w'..i,'wheat',i,true) end
for i=1,3 do many[#many+1]=option('c'..i,'carrot',i,true) end
many[#many+1]=option('rare','inferium',0,true)
state={};local assigned={};local total=0
for _=1,10 do
 for id=1,10 do
  if total<#many then
   local candidate=B.order(state,many,many,id)[1]
   if candidate then
    assert(not assigned[candidate.job.key],'no duplicate within the fleet cycle')
    assigned[candidate.job.key]=true;B.assigned(state,id,candidate.job)
    for other=1,10 do if other~=id then
      local next=B.order(state,many,many,other)[1]
      assert(not next or next.job.name~=candidate.job.name,'one owner per crop round')
    end end
    B.finished(state,id,candidate.job);total=total+1
   end
  end
 end
end
assert(total==#many and assigned.rare)
print('PASS ten bots share one cycle with exclusive crop-round ownership and no repeated plants')

state={}
local unknowns={option('a','unknown',1),option('b','unknown',2),carrot}
assert(B.order(state,unknowns,unknowns,1)[1]==carrot,'known ready counts precede unknown inspections')
state={};B.order(state,all,all,1)
assert(B.order(state,all,{carrot},2)[1]==carrot,'worker-specific seed eligibility must be respected')
assert(state.pending.w1 and state.pending.w2,'one worker cannot discard jobs another can perform')
local repair=option('gap','beetroot',1000);repair.job.repair=true
ordered=B.order(state,all,{wheat1,repair},1);assert(ordered[1]==repair)
B.assigned(state,1,repair.job);B.finished(state,1,repair.job)
assert(state.workers['1']==nil,'repair must not replace batch affinity')
B.skip(state,'w1');assert(state.pending.w1==nil)
ordered=B.order(state,{carrot},{carrot},1);assert(ordered[1]==carrot and not state.pending.w2)
print('PASS repair priority, worker eligibility, unreachable and removed crops do not corrupt rounds')

local Garden=require('farm.lib.garden')
local g=Garden.new()
local function plant(key,name,seed,guaranteed)
  g:observe({key=key,name=name,seed=seed,guaranteedSeed=guaranteed},0)
end
plant('w1','wheat','wheat_seed');plant('w2','wheat','wheat_seed')
plant('c1','coffee','coffee');plant('c2','coffee','coffee')
plant('o1','onion','onion');plant('g1','magic','magic_seed',true)
plant('gap','flax','flax_seed');g.data.plots.gap.live=false;g.data.plots.gap.debt=true
local keep=g:reserves('wheat')
assert(keep.wheat_seed==4 and keep.coffee==nil and keep.onion==1 and keep.magic_seed==nil and keep.flax_seed==1)
print('PASS batch reserves retain current crop, last-plant seeds and replant debts without hoarding every crop')

state={}
local lower=option('low','berries',1,true);local upper=option('high','berries',30,true)
local other=option('next','coffee',0,true)
B.order(state,{lower,other},{lower,other},9);B.assigned(state,9,lower.job);B.finished(state,9,lower.job)
ordered=B.order(state,{lower,upper,other},{lower,upper,other},9)
assert(ordered[1]==upper,'newly eligible berries on another height join the current batch')
B.assigned(state,9,upper.job);B.finished(state,9,upper.job)
ordered=B.order(state,{lower,upper,other},{lower,upper,other},9)
assert(ordered[1]==other,'visited/regrown berries cannot starve the next type')
print('PASS current crop admits unvisited plants at other heights while visited plants wait for the next round')

state={}
local w=option('w','wheat',1,true)
local t1=option('t1','tomatoes',2,true);local t2=option('t2','tomatoes',100,true)
local c1=option('cocoa1','cocoa',3,true);local c2=option('cocoa2','cocoa',200,true)
local rare=option('inferium','inferium',500,true)
local crops={w,t1,t2,c1,c2,rare}
B.order(state,crops,crops,1);B.assigned(state,1,w.job);B.finished(state,1,w.job)
B.order(state,crops,crops,1);B.assigned(state,1,t1.job);B.finished(state,1,t1.job)
B.order(state,crops,crops,1);B.assigned(state,1,t2.job)
B.release(state,1) -- Fuel/unload before inspection: same round and plant remain unfinished.
assert(state.workers['1']=='tomatoes' and not state.visited.t2)
assert(B.order(state,crops,crops,1)[1]==t2)
local forTwo=B.order(state,crops,crops,2)[1];assert(forTwo.job.name~='wheat' and forTwo.job.name~='tomatoes')
B.assigned(state,2,c1.job);B.finished(state,2,c1.job)
B.release(state,2);assert(B.order(state,crops,crops,2)[1]==c2)
assert(B.order(state,crops,crops,3)[1]==rare,'third bot must take inferium, never completed wheat or owned cocoa/tomatoes')
B.assigned(state,3,rare.job);B.finished(state,3,rare.job)
assert(not B.order(state,crops,crops,3)[1],'idle bot waits for unfinished owned rounds instead of restarting wheat')
B.assigned(state,1,t2.job);B.finished(state,1,t2.job)
B.assigned(state,2,c2.job);B.finished(state,2,c2.job)
B.order(state,crops,crops,1);assert(state.cycle==2)
print('PASS shared wheat/tomato/cocoa/inferium cycle survives unloads, uninspected assignments and exclusive ownership across bots')

state={}
local mature=option('tm','farmersdelight:tomatoes',1,true)
local bud=option('tb','farmersdelight:budding_tomatoes',2);bud.job.crop='farmersdelight:tomatoes'
B.order(state,{mature,bud},{mature,bud},1);B.assigned(state,1,mature.job)
assert(not B.order(state,{mature,bud},{mature,bud},2)[1],'different growth-stage block names must share one exclusive crop round')
B.release(state,1);state.inflight={} -- Simulate a restart using the same durable round state.
assert(B.order(state,{mature,bud},{mature,bud},1)[1]==mature)
print('PASS crop stages share ownership and a restart preserves unchecked assignments')

-- Reproduce the final blocked cabbage round holding three idle workers hostage.
state={}
local ca=option('ca','cabbage',1,true);local cb=option('cb','cabbage',2,true)
local fleet={ca,cb,w,rare}
B.order(state,fleet,fleet,8,100);B.assigned(state,8,ca.job);B.finished(state,8,ca.job)
B.assigned(state,9,w.job);B.finished(state,9,w.job)
B.assigned(state,10,rare.job);B.finished(state,10,rare.job)
B.order(state,fleet,fleet,9,100);assert(not B.order(state,fleet,fleet,9,100)[1])
assert(B.park(state,8,105));assert(state.pending.cb and state.visited.ca)
local nextCrop=B.order(state,fleet,fleet,9,101)[1]
assert(nextCrop and nextCrop.job.name~='cabbage' and state.cycle==2)
assert(state.pending.cb and not state.pending.ca and state.visited.ca,'carry unfinished round without revisiting checked cabbage')
local resumed=B.order(state,fleet,fleet,21,106)[1];assert(resumed==cb,'overdue deferred crop has priority over another new sweep')
B.assigned(state,21,cb.job);assert(not B.park(state,21,110),'never release active work')
assert(not B.order(state,fleet,{cb},8,106)[1],'exclusive ownership survives reassignment')
B.release(state,21);assert(B.order(state,fleet,fleet,21,106)[1]==cb,'unloading preserves resumed round')
B.assigned(state,21,cb.job);B.finished(state,21,cb.job)
assert(not B.order(state,fleet,{ca,cb},8,107)[1],'finished cabbage still waits for other crops in new cycle')
print('PASS blocked final round parks without losing unchecked plants, unblocks fleet cycles and resumes exclusively without reharvesting checked plants')

state={};B.order(state,{ca,cb},{ca,cb},8,0);B.assigned(state,8,ca.job);B.finished(state,8,ca.job);B.park(state,8,5)
for tick=1,4 do assert(not B.order(state,{ca,cb},{ca,cb},9,tick)[1] and state.cycle==1) end
assert(B.order(state,{ca,cb},{ca,cb},9,6)[1]==cb)
print('PASS all-blocked farms wait without manufacturing cycles or forgetting round progress')

state={};B.order(state,fleet,fleet,8,100);B.assigned(state,8,ca.job);B.finished(state,8,ca.job)
B.assigned(state,9,w.job);B.finished(state,9,w.job);B.assigned(state,10,rare.job);B.finished(state,10,rare.job)
local gap={key='gap',name='cabbage',repair=true};B.assigned(state,8,gap);B.finished(state,8,gap)
assert(B.park(state,8,105,'cabbage'))
assert(B.order(state,fleet,fleet,9,101)[1].job.name~='cabbage','failed repair must free fleet before owner wakes from error sleep')
print('PASS failed repair immediately defers its crop, independently of worker error sleep')

state={};B.order(state,fleet,fleet,8,100)
B.assigned(state,8,ca.job);B.finished(state,8,ca.job);B.assigned(state,8,cb.job);B.finished(state,8,cb.job)
B.assigned(state,9,w.job);B.finished(state,9,w.job);B.order(state,fleet,fleet,9,100)
assert(not B.deferBlocked(state,{},105))
assert(B.deferBlocked(state,{inferium=true},105),'unowned inaccessible crop must not hold cycle forever')
assert(B.order(state,fleet,fleet,10,101)[1] and state.cycle==2)
print('PASS wholly blocked unowned crop rounds also defer so newly discovered inaccessible crops cannot stall the fleet')
