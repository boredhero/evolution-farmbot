-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local F={values={['minecraft:coal']=80,['minecraft:charcoal']=80,['minecraft:coal_block']=800}}
function F.target() return math.min(8000,turtle.getFuelLimit and turtle.getFuelLimit() or 20000) end
function F.reserve()
  local n=0;for slot=1,16 do local item=turtle.getItemDetail(slot);if item and F.values[item.name] then n=n+item.count end end
  return n
end
function F.mode(cfg)return cfg and cfg.fuelMode or 'coal' end
function F.protected(cfg,name)
  return F.mode(cfg)~='coal' and (name==cfg.batteryItem or name=='advancedperipherals:weak_automata_core')
end
function F.refuel(cfg)
  local level=turtle.getFuelLevel();if level=='unlimited' then return end
  if F.mode(cfg)~='coal' then
    if level>=F.target()/2 then return end
    local ok,err=require('farm.lib.energy').charge(cfg,F.target());F.energyError=not ok and err or nil
    if F.mode(cfg)=='energy' or turtle.getFuelLevel()>=F.target()/2 then return end
  end
  for slot=1,16 do
    local item=turtle.getItemDetail(slot);level=turtle.getFuelLevel()
    if level>=F.target() then return end
    if item and F.values[item.name] then
      turtle.select(slot);turtle.refuel(math.min(item.count,math.ceil((F.target()-level)/F.values[item.name])))
    end
  end
end
function F.needed(cfg)
  local level=turtle.getFuelLevel()
  local target=F.mode(cfg)=='coal' and F.target() or F.target()/2
  return level~='unlimited' and (level<target or (F.mode(cfg)~='energy' and F.reserve()<64))
end
function F.fill(side,cfg)
  if F.mode(cfg)=='energy' then F.refuel(cfg);return end
  for _=1,3 do
    if not F.needed(cfg) then return end
    local slot
    for i=1,16 do
      local item=turtle.getItemDetail(i)
      if item and F.values[item.name] and item.count<64 then slot=i;break end
      if not item and not slot then slot=i end
    end
    if not slot then return end
    turtle.select(slot)
    if not turtle['suck'..side](64-turtle.getItemCount(slot)) then return end
    local item=turtle.getItemDetail(slot)
    if item and not F.values[item.name] then turtle['drop'..side]();return end
    F.refuel(cfg)
  end
end
return F
