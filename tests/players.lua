-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local Players=require('farm.lib.players')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local center={x=0,y=65,z=0}
eq(Players.arrow(0),'v');eq(Players.arrow(90),'<');eq(Players.arrow(180),'^');eq(Players.arrow(270),'>')
eq(Players.arrow(-90),'>');eq(Players.arrow(359),'v');eq(Players.arrow(44),'v');eq(Players.arrow(46),'<')
eq(Players.arrow(nil),'@');eq(Players.arrow('north'),'@')
print('PASS Minecraft yaw maps to a north-up facing arrow, including negative and wrapped angles')
local world={
  ada={x=3.7,y=65.0,z=-2.2,yaw=180,dimension='minecraft:overworld'},
  bo={x=-40.0,y=65.0,z=0.0,yaw=0,dimension='minecraft:overworld'},
  cy={x=1.0,y=65.0,z=1.0,yaw=270,dimension='ftbmining:mining'},
}
local asked
local function find(kind)
  if kind=='environment_detector' then return {getDimension=function() return 'minecraft:overworld' end} end
  if kind=='player_detector' then
    return {getPlayersInRange=function(r) asked=r;local n={};for k in pairs(world) do n[#n+1]=k end;table.sort(n);return n end,
      getPlayerPos=function(name) return world[name] end}
  end
end
local tracker=Players.new(find)
local list=tracker:poll(center,32)
eq(asked,40)
eq(#list,2)
eq(list[1].name,'ada');assert(list[1].viewer)
eq(list[1].x,3);eq(list[1].z,-3)
eq(list[2].name,'bo');eq(list[2].viewer,nil)
print('PASS nearest player is the viewer; float coords floor to blocks; other dimensions are excluded')
world.cy.dimension='minecraft:overworld'
eq(#Players.new(find):poll(center,32),3)
print('PASS a player entering the controller dimension appears without reconfiguration')
local blind=Players.new(function(kind)
  if kind=='player_detector' then
    return {getPlayersInRange=function() return {'ada'} end,
      getPlayerPos=function() error('getPlayerPos is disabled') end}
  end
end)
eq(#blind:poll(center,32),0);eq(blind.error,nil)
print('PASS a server with getPlayerPos disabled degrades to an empty overlay, not a crash')
local broken=Players.new(function(kind)
  if kind=='player_detector' then return {getPlayersInRange=function() error('detector removed') end} end
end)
eq(#broken:poll(center,32),0);assert(broken.error)
local none=Players.new(function() return nil end)
eq(#none:poll(center,32),0);eq(none.error,nil)
print('PASS missing detector is silent; a failing detector reports an error instead of stopping the farm')
