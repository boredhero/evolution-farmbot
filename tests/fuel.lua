-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local F=require('farm.lib.fuel')
local level,selected,pulls=400,1,0;local slots={}
turtle={getFuelLevel=function() return level end,getFuelLimit=function() return 100000 end,
 getItemDetail=function(i) return slots[i] end,getItemCount=function(i) return slots[i] and slots[i].count or 0 end,
 select=function(i) selected=i end,
 suck=function(n) pulls=pulls+1;slots[selected]={name='minecraft:coal',count=(slots[selected] and slots[selected].count or 0)+n};return true end,
 refuel=function(n) local item=slots[selected];n=math.min(n,item.count);level=level+n*80;item.count=item.count-n;if item.count==0 then slots[selected]=nil end;return true end,
 drop=function() slots[selected]=nil;return true end}
F.fill('');assert(level>=8000 and F.reserve()==64 and pulls==3)
level=level-160;F.refuel();assert(level>=8000 and F.reserve()==62)
F.fill('');assert(F.reserve()==64 and pulls==4)
F.fill('');assert(pulls==4)
level='unlimited';assert(not F.needed());F.refuel()
print('PASS fuel endurance: 8000 stored movement fuel plus one backup stack, consumed automatically and replenished without needless pulls')
