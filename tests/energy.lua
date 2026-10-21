-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local S=require('farm.lib.store');local E=require('farm.lib.energy');local F=require('farm.lib.fuel')
local journal={};S.load=function(_,default)return journal end;S.save=function(_,data)journal=data end
local selected,level,energy,calls=4,100,10000,0
local slots={[1]={name=E.core,count=1},[2]={name='test:battery',count=1},[3]={name='minecraft:coal',count=64}}
local left={name='minecraft:diamond_pickaxe'};local modem={name='computercraft:wireless_modem_advanced'}
local failure
local function swap()
 local held=slots[selected];slots[selected]=left;left=held;return true
end
turtle={getItemDetail=function(i)return slots[i]end,getSelectedSlot=function()return selected end,
 getEquippedLeft=function()return left end,getEquippedRight=function()return modem end,
 select=function(i)selected=i end,equipLeft=swap,equipRight=function()error('Must not remove modem')end,
 getFuelLevel=function()return level end,getFuelLimit=function()return 20000 end,
 refuel=function(n)local d=slots[selected];assert(d.name=='minecraft:coal');d.count=d.count-n;level=level+80*n;return true end}
peripheral={wrap=function(side)
 assert(side=='left' and left.name==E.core)
 return {chargeTurtle=function(n)
  assert(slots[selected].name=='test:battery' and journal.side=='left');calls=calls+1
  if failure then error(failure) end
  local amount=math.min(n,energy,500);energy=energy-amount;level=level+amount;return true,amount
 end}
end}
local cfg={fuelMode='energy',batteryItem='test:battery'}
assert(E.charge(cfg,8000));assert(level==8000 and left.name=='minecraft:diamond_pickaxe' and selected==4 and not journal.side)
assert(slots[1].name==E.core and slots[2].name==cfg.batteryItem and modem.name=='computercraft:wireless_modem_advanced')
local before=calls;F.refuel(cfg);assert(calls==before,'no swap while internal buffer is healthy')
level=100;energy=0;assert(not E.charge(cfg,8000));assert(left.name=='minecraft:diamond_pickaxe')
failure='Battery refuses extraction';local ok,err=E.charge(cfg,8000);assert(not ok and err:find('refuses') and not journal.side)
failure='Terminated';local ok,err=pcall(E.charge,cfg,8000);assert(not ok and err:find('Terminated') and left.name=='minecraft:diamond_pickaxe');failure=nil
-- Restart before swap, or after installing core, both restore the ordinary worker hardware.
journal={side='left'};E.recover();assert(not journal.side)
journal={side='left'};selected=1;swap();E.recover();assert(left.name=='minecraft:diamond_pickaxe' and not journal.side and slots[1].name==E.core)
-- Auto falls back to coal; pure energy never burns the carried coal.
level=100;energy=0;local coal=slots[3].count;F.refuel(cfg);assert(level==100 and slots[3].count==coal)
cfg.fuelMode='auto';F.refuel(cfg);assert(level>100 and slots[3].count<coal)
level=6000;coal=slots[3].count;before=calls;F.refuel(cfg);assert(level==6000 and slots[3].count==coal and calls==before,'auto must not burn coal while energy buffer is healthy')
assert(F.protected(cfg,E.core) and F.protected(cfg,cfg.batteryItem) and not F.protected(cfg,'minecraft:wheat'))
assert(F.mode({})=='coal' and not F.protected({fuelMode='coal'},E.core))
print('PASS energy charging retains hardware, restores pickaxe on errors/restarts/termination, avoids modem swaps, and supports coal fallback')
local Setup=require('farm.setup');write=function()end;local oldPrint=print;print=function()end
local answers={'invalid','energy','test:battery'};read=function()return table.remove(answers,1)end
local setup={};Setup.fuel(setup);assert(setup.fuelMode=='energy' and setup.batteryItem=='test:battery')
Setup.fuel(setup,'auto','test:other');assert(setup.batteryItem=='test:other')
Setup.fuel(setup,'coal');assert(setup.fuelMode=='coal');assert(not pcall(Setup.fuel,setup,'invalid'))
print=oldPrint
print('PASS fuel setup validates choices, stores battery identity and preserves coal defaults')
