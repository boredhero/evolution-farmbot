-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local W=require('farm.lib.world')
local C=require('farm.lib.crops')
local G=require('farm.lib.garden')
local M=require('farm.lib.metrics')
local U=require('farm.lib.util')
return function()
  local center={x=0,y=65,z=0};local blocks={}
  local function put(name,x,y,z) blocks[#blocks+1]={name=name,x=x,y=y-65,z=z} end
  for x=-26,24 do
    put('minecraft:stone_bricks',x,65,-24);put('minecraft:stone_bricks',x,65,25)
  end
  for z=-24,25 do
    put('minecraft:stone_bricks',-26,65,z);put('minecraft:stone_bricks',24,65,z)
  end
  local types={'minecraft:wheat','minecraft:carrots','farmersdelight:cabbages','farmersdelight:onions',
    'cottonly:cotton_plant','actuallyadditions:canola','actuallyadditions:coffee','hexerei:sage_crop'}
  for bed=0,7 do
    local ox=-22+(bed%4)*11;local oz=-19+math.floor(bed/4)*21
    for x=ox,ox+7 do for z=oz,oz+13 do
      if x==ox+4 then put('minecraft:water',x,64,z)
      else put('minecraft:farmland',x,64,z);put(types[bed+1],x,65,z) end
    end end
  end
  for x=-8,8 do for z=-6,6 do
    put('mysticalagriculture:inferium_farmland',x,80,z)
    put('mysticalagriculture:inferium_crop',x,81,z)
  end end
  local world=W.new(center,32);world:ingest(blocks)
  local garden=G.new();garden:scan(world,C.discover(world),1,2)
  local history={};local keys={};for key in pairs(garden.data.plots) do keys[#keys+1]=key end;table.sort(keys)
  for i,key in ipairs(keys) do
    local p=garden.data.plots[key];local age=i%3==0 and p.job.age or i%(p.job.age+1)
    if i%43==0 then p.debt=true;p.live=false
    elseif i%37==0 then p.intent={owner=11,token='test',expires=1100};p.debt=true;p.live=false
    elseif i%11~=0 then
      history[key]={observed={name=p.job.name,state={age=age}},observedAt=i%17==0 and 500 or 980}
    end
  end
  local metrics=M.new(nil,100);metrics.data.harvests=14832;metrics.data.replants=13611
  metrics.data.deferred=73;metrics.data.uptime=231480;metrics.data.scans=1972
  metrics.data.errors=4;metrics.data.sessions=8
  for i,name in ipairs(types) do metrics.data.byCrop[name]={harvests=1500+i*63,replants=1400+i*42,deferred=i} end
  metrics.data.byCrop['mysticalagriculture:inferium_crop']={harvests=3270,replants=3270,deferred=0}
  for i,name in ipairs(types) do metrics.data.events[#metrics.data.events+1]={name=name,outcome=i%3==0 and 'deferred' or 'harvested',time=970+i*3} end
  local routeA,routeB={},{}
  for z=-20,20 do routeA[#routeA+1]={x=-13,y=66,z=z} end
  for x=-23,20 do routeB[#routeB+1]={x=x,y=66,z=-2} end
  local m={now=1000,active=true,world=world,center=center,radius=32,plots=garden.data.plots,
    history=history,excluded={},workers={
      [11]={pos={x=-13,y=66,z=8},seen=999,fuel=18120,status='Farming minecraft:wheat',route=routeA},
      [12]={pos={x=5,y=66,z=-2},seen=998,fuel=16490,status='Returning with cotton seeds',route=routeB}},
    cache={one={path=routeA},two={path=routeB}},cacheHits=4932,metrics=metrics.data,sessionUptime=27012,
    scanAge=27,freshFor=360}
  return m
end
