-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local H={};H.__index=H
function H.new()return setmetatable({list={},checked=-math.huge},H)end
function H:poll(world,now)
  if self.busy then return nil,'Entity scan in progress' end
  if now-self.checked<2.1 then
    if self.error then return nil,self.error end
    return self.list
  end
  self.checked=now
  local detector=peripheral.find('environment_detector')
  if not detector or not detector.scanEntities then self.error='Attach an Environment Detector';return nil,self.error end
  local origin
  for _,b in pairs(world.blocks) do if b.name=='advancedperipherals:environment_detector' then
    if origin then self.error='Sheep detection requires one surveyed Environment Detector';return nil,self.error end
    origin=b
  end end
  if not origin then self.error='Environment Detector must be inside scanner coverage';return nil,self.error end
  -- AP 0.8 returns world-axis offsets from the detector block CENTER.
  self.busy=true
  local ok,entities,err=pcall(detector.scanEntities,math.min(16,world.radius),false,'minecraft:sheep')
  self.busy=false
  if not ok or type(entities)~='table' then self.error=tostring(ok and err or entities);return nil,self.error end
  self.list={}
  for _,e in ipairs(entities) do
    if e.name=='minecraft:sheep' and e.uuid and not e.baby and type(e.x)=='number' and type(e.y)=='number' and type(e.z)=='number' then
      local p={x=math.floor(origin.x+0.5+e.x),y=math.floor(origin.y+0.5+e.y)+1,z=math.floor(origin.z+0.5+e.z)}
      if world:inside(p) and world:inside(U.add(p,U.dirs[5])) then
        local key='sheep:'..e.uuid
        self.list[key]={key=key,roundKey=key,uuid=e.uuid,pos=p,name='minecraft:sheep',crop='minecraft:sheep',mode='sheep',onlyAbove=true,tool='minecraft:shears'}
      end
    end
  end
  self.error=nil;return self.list
end
function H.sync(garden,list,leases,now)
  if not list then return end
  for key,p in pairs(garden.data.plots) do if p.job.mode=='sheep' and not list[key] and not leases[key] then garden.data.plots[key]=nil end end
  for key,j in pairs(list) do
    local p=garden.data.plots[key]
    if not p then garden:observe(j,now)
    elseif not leases[key] then p.job=j;p.updated=now end
  end
end
function H.wool()
  local n=0
  for i=1,16 do local d=turtle.getItemDetail(i);if d and d.name:match('_wool$') then n=n+d.count end end
  return n
end
-- No attacks or digs: a moved, bare, or baby sheep simply yields no wool.
function H.shear()
  local slot
  for i=1,16 do local d=turtle.getItemDetail(i);if d and d.name=='minecraft:shears' then slot=i;break end end
  if not slot then return 'missing_tool','Carry shears for sheep rounds' end
  if turtle.inspectDown() then return 'unreachable','Block below prevents safe sheep interaction' end
  local before=H.wool();turtle.select(slot)
  local ok,err=turtle.placeDown()
  if not turtle.inspectDown() then turtle.suckDown() end
  if ok and H.wool()>before then return 'harvested' end
  return 'growing',ok and 'No wool collected' or tostring(err or 'Sheep moved or has no wool')
end
return H
