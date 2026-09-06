-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local Hardware=require('farm.lib.hardware')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function envFor(types,wireless)
  local names={};for name in pairs(types) do names[#names+1]=name end
  return {getNames=function() return names end,
    hasType=function(name,kind)
      for _,t in ipairs(types[name] or {}) do if t==kind then return true end end
      return false
    end,
    call=function(name,method) if method=='isWireless' then return (wireless or {})[name]==true end end}
end
local full=envFor({
  monitor_0={'monitor'},monitor_1={'monitor'},
  geo_scanner_2={'geo_scanner'},
  playerDetector_3={'player_detector'},
  environmentDetector_4={'environment_detector'},
  back={'modem'},modem_5={'modem'},
  seedbank={'inventory'},
  mysterious_thing={'brewery'},
},{back=true})
local f=Hardware.survey(full)
eq(f.scanner,'geo_scanner_2');eq(f.player,'playerDetector_3');eq(f.environment,'environmentDetector_4')
eq(#f.monitors,2);eq(#f.inventories,1);eq(#f.wireless,1);eq(#f.wired,1)
eq(f.wireless[1],'back');eq(f.wired[1],'modem_5')
eq(#f.other,1);eq(f.other[1],'mysterious_thing')
print('PASS survey sorts every attached peripheral into its role, including unrecognised ones')
local text=table.concat(Hardware.lines(full,{monitorRole=function(n) return n=='monitor_0' and 'map' or 'stats' end,
  dimension='minecraft:overworld',players=2,gps='0,65,0',version='0.3.1',workers='11, 12'}),'\n')
assert(text:find('monitor_0=map',1,true));assert(text:find('monitor_1=stats',1,true))
assert(text:find('2 players in range',1,true));assert(text:find('minecraft:overworld',1,true))
assert(text:find('Ender/wireless modem: back',1,true))
assert(text:find('Monitors: 2: monitor_0=map',1,true))
assert(text:find('GPS position: 0,65,0',1,true));assert(text:find('v0.3.1',1,true))
assert(text:find('Paired workers: 11, 12',1,true))
assert(not text:find('MISSING',1,true))
-- Present hardware must never carry the hint that explains how to attach it.
assert(not text:find('required; must touch',1,true))
assert(not text:find('required for GPS',1,true))
assert(not text:find('right-click each modem',1,true))
assert(not text:find('optional;',1,true))
assert(not text:find('not attached',1,true))
print('PASS a fully equipped controller reports every peripheral with its live role and reading')
local one=table.concat(Hardware.lines(full,{players=1}),'\n')
assert(one:find('1 player in range',1,true))
local attached=table.concat(Hardware.lines(full,{}),'\n')
assert(not attached:find('optional;',1,true))
assert(attached:find('dimension not read yet',1,true))
print('PASS attached hardware never advertises itself as optional, and player counts read naturally')
local bare=envFor({back={'modem'}},{back=true})
local missing=table.concat(Hardware.lines(bare,{}),'\n')
assert(missing:find('Geo Scanner: MISSING',1,true))
assert(missing:find('required; must touch the controller',1,true))
assert(missing:find('Wired modems: none',1,true))
assert(missing:find("right-click each modem",1,true))
assert(missing:find('Player Detector: not attached',1,true))
assert(missing:find('optional; enables the map player overlay',1,true))
print('PASS missing required hardware is named MISSING with its fix; optional hardware reads as optional')
local hostile={getNames=function() error('peripheral bus fault') end,
  hasType=function() error('nope') end,call=function() error('nope') end}
local survived=Hardware.lines(hostile,{})
assert(#survived>1);assert(table.concat(survived,'\n'):find('MISSING',1,true))
local partial=envFor({odd={'monitor'}})
partial.hasType=function(name,kind) if kind=='monitor' then error('boom') end;return false end
eq(#Hardware.survey(partial).monitors,0)
print('PASS a faulty peripheral bus degrades to a readable report instead of crashing the console')
local alt=envFor({scanner={'geoScanner'}})
eq(Hardware.survey(alt).scanner,'scanner')
print('PASS the alternate geoScanner type name is recognised')
