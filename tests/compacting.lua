-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local M=require('farm.lib.compacting')
local Craft=require('farm.lib.compact_crafting')
assert(#M.plan({}, {['minecraft:wheat']=64},{},{})==0)
local plan=M.plan({wheat=true,onion=true},{['minecraft:wheat']=64,['farmersdelight:onion']=32},{['farmersdelight:onion']=16},{['minecraft:wheat_seeds']=16})
assert(#plan==2 and plan[1].batches==5 and plan[2].batches==1)
assert(#M.plan({wheat=true},{['minecraft:wheat']=8},{},{})==0)
local function run(options)
 options=options or {};local required=options.wool and 4 or 9;local slots={[1]={name='minecraft:wheat',count=20}};local machine={};local selected=1;local powered=false;local pulses=0;local saves=0
 local journal={};local crash={};local drops=0
 local function insert(n)
  local d=slots[selected];assert(d and d.name=='minecraft:wheat' and d.count>=n)
  local slot=1
  if not options.disabled then while machine[slot] do slot=slot+1 end end
  d.count=d.count-n;machine[slot]={name='minecraft:wheat',count=(machine[slot] and machine[slot].count or 0)+n}
 end
 turtle={getItemDetail=function(i)return slots[i] end,getItemSpace=function(i)return 64-(slots[i] and slots[i].count or 0) end,
 select=function(i)selected=i end,drop=function(n)
  assert(n==1 and saves>0);insert(n);drops=drops+1
  if options.crashAfter==drops then error(crash) end
  return true
 end,suck=function(n)
  for slot,d in pairs(machine) do
   local take=math.min(n,d.count);d.count=d.count-take;if d.count==0 then machine[slot]=nil end
   if not slots[selected] then slots[selected]={name='minecraft:wheat',count=0} end
   slots[selected].count=slots[selected].count+take;return true
  end
  return false
 end}
 peripheral={wrap=function()return {list=function()return machine end,pushItems=function(_,source,n,target)
  if options.transferFail then return 0 end
  assert(n==1 and not machine[target]);machine[target]=machine[source];machine[source]=nil
  if options.crashArrange then options.crashArrange=false;error(crash) end
  return 1
 end} end}
 redstone={getOutput=function()return powered end,setOutput=function(_,v)
  powered=v
  if v then
   pulses=pulses+1
   if not options.fail then
    if options.wool then assert(machine[1] and machine[2] and machine[4] and machine[5] and not machine[3]) end
    machine={};slots[2]={name='minecraft:hay_block',count=1} end
   if options.crashOutput then options.crashOutput=false;error(crash) end
  end
 end}
 sleep=function()end
 if options.foreign then machine[1]={name='minecraft:diamond',count=1} end
 local function save()saves=saves+1 end
 local recipe={item='minecraft:wheat',inputCount=required,slots=options.wool and {1,2,4,5} or nil,count=1}
 local ok,made,why=pcall(Craft.run,'front','minecraft:hay_block',recipe,journal,save)
 if not ok then
  assert(made==crash);options.crashAfter=nil
  made,why=Craft.run('front','minecraft:hay_block',recipe,journal,save)
 end
 assert(not powered)
 if options.foreign then assert(not made and slots[1].count==20 and not journal.loaded and pulses==0)
 elseif options.disabled or options.fail or options.transferFail then assert(not made and slots[1].count==20 and not journal.loaded and not next(machine))
 else assert(made,why);assert(slots[1].count==20-required and slots[2].count==1 and pulses==1 and not next(machine)) end
end
run();run({disabled=true});run({foreign=true});run({fail=true})
for n=1,9 do run({crashAfter=n}) end
run({crashOutput=true})
print('PASS compacting protects planting stock, defaults off, balances nine inputs, rolls back disabled/failed recipes, and resumes every interrupted insertion/output without duplicate consumption')

assert(#M.plan({}, {['minecraft:string']=64},{},{})==0)
local strings=M.plan({string=true},{['minecraft:string']=64},{['minecraft:string']=10},{})
assert(#strings==1 and strings[1].batches==6 and strings[1].inputCount==9)
assert(strings[1].item=='minecraft:string' and strings[1].output=='compressedblocks:crated_string')
assert(#M.plan({string=true},{['minecraft:string']=8},{},{})==0)
print('PASS optional string crates use nine string per batch, preserve reserves and leave leftovers loose')

run({wool=true});run({wool=true,transferFail=true})
for n=1,4 do run({wool=true,crashAfter=n}) end
run({wool=true,crashOutput=true})
local wool=M.plan({wool=true,string=true},{['minecraft:string']=19},{['minecraft:string']=2},{})
assert(#wool==1 and wool[1].output=='minecraft:white_wool' and wool[1].batches==4 and wool[1].inputCount==4)
assert(wool[1].slots[4]==5)
print('PASS shaped wool grid, four-input recovery and exclusive string conversion planning')
