-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- Advanced Peripherals player tracking. Absent hardware is not an error: the
-- overlay simply stays empty so every existing install keeps working untouched.
local U=require('farm.lib.util')
local Players={};Players.__index=Players
local PAD=8
-- Yaw is degrees clockwise from south, so south sorts first here.
local ARROWS={'v','<','^','>'}
function Players.arrow(yaw)
  if type(yaw)~='number' then return '@' end
  return ARROWS[math.floor(((yaw%360)+45)/90)%4+1]
end
function Players.new(find,dimension)
  return setmetatable({find=find or peripheral.find,dimension=dimension,list={},error=nil,checked=nil},Players)
end
function Players:detector()
  local ok,detector=pcall(self.find,'player_detector')
  if ok then return detector end
end
-- The controller cannot ask which dimension it occupies, so an Environment
-- Detector supplies it once. Without one we cannot filter and show everyone.
function Players:home()
  if self.dimension~=nil or self.checked then return self.dimension end
  self.checked=true
  local ok,env=pcall(self.find,'environment_detector')
  if ok and env and env.getDimension then
    local got,name=pcall(env.getDimension)
    if got and type(name)=='string' then self.dimension=name end
  end
  return self.dimension
end
function Players:poll(center,radius)
  local detector=self:detector()
  if not detector then self.list={};self.error=nil;return self.list end
  local home=self:home()
  local ok,names=pcall(detector.getPlayersInRange,math.floor(radius+PAD))
  if not ok or type(names)~='table' then
    self.error='player detector unavailable';self.list={};return self.list
  end
  local found={}
  for _,name in ipairs(names) do
    local got,pos=pcall(detector.getPlayerPos,name)
    -- getPlayerPos is disabled by config on some servers; degrade to names only.
    if got and type(pos)=='table' and type(pos.x)=='number' and type(pos.z)=='number' then
      if not home or not pos.dimension or pos.dimension==home then
        local p={name=name,x=math.floor(pos.x),y=math.floor(pos.y or center.y),z=math.floor(pos.z),
          yaw=pos.yaw,dimension=pos.dimension}
        p.away=U.distance(p,center)
        found[#found+1]=p
      end
    end
  end
  table.sort(found,function(a,b) if a.away~=b.away then return a.away<b.away end;return a.name<b.name end)
  -- Nearest to the controller is whoever is standing at the screens with it.
  if found[1] then found[1].viewer=true end
  self.error=nil;self.list=found
  return self.list
end
return Players
