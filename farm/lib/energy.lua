-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local S=require('farm.lib.store')
local E={core='advancedperipherals:weak_automata_core'}
local PATH='farm/data/energy-swap'
local function equipped(side)
  local fn=side=='left' and turtle.getEquippedLeft or turtle.getEquippedRight
  return fn and fn()
end
local function equip(side)return side=='left' and turtle.equipLeft or turtle.equipRight end
local function find(name)
  for i=1,16 do local d=turtle.getItemDetail(i);if d and d.name==name then return i end end
end
function E.recover()
  local j=S.load(PATH,{})
  if not j.side then return end
  local current=equipped(j.side)
  if current and current.name=='minecraft:diamond_pickaxe' then S.save(PATH,{});return end
  assert(current and current.name==E.core,'Charging recovery: expected Automata Core on '..j.side)
  local slot=find('minecraft:diamond_pickaxe');assert(slot,'Charging recovery: put the diamond pickaxe back in inventory')
  turtle.select(slot);assert(equip(j.side)(),'Charging recovery: could not restore pickaxe')
  assert(equipped(j.side).name=='minecraft:diamond_pickaxe','Charging recovery: pickaxe not restored')
  S.save(PATH,{})
end
function E.charge(cfg,target)
  E.recover()
  local battery=cfg.batteryItem and find(cfg.batteryItem)
  if not battery then return false,'Put the configured charged battery in inventory' end
  local side
  for _,name in ipairs({'left','right'})do local d=equipped(name);if d and d.name=='minecraft:diamond_pickaxe' then side=name;break end end
  if not side then return false,'Energy charging needs an equipped diamond pickaxe to swap temporarily' end
  local core=find(E.core);if not core then return false,'Carry a Weak Automata Core for energy charging' end
  local selected=turtle.getSelectedSlot and turtle.getSelectedSlot() or 1
  S.save(PATH,{side=side})
  turtle.select(core)
  local swapped,why=equip(side)()
  if not swapped then E.recover();turtle.select(selected);return false,why end
  local before=turtle.getFuelLevel()
  local ok,err=pcall(function()
    local p=peripheral.wrap(side)
    assert(p and type(p.chargeTurtle)=='function','Automata charging unavailable or disabled')
    turtle.select(battery)
    for _=1,32 do
      local level=turtle.getFuelLevel();if level>=target then break end
      local charged,reason=p.chargeTurtle(target-level)
      if not charged then error(tostring(reason or 'Battery cannot supply FE'),0) end
      if turtle.getFuelLevel()<=level then break end
    end
  end)
  E.recover();turtle.select(selected)
  if not ok then
    if tostring(err):find('Terminated',1,true) then error(err,0) end
    return false,tostring(err)
  end
  if turtle.getFuelLevel()>before then return true end
  return false,'Battery is empty or cannot supply energy; recharge it externally'
end
return E
