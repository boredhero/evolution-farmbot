-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local U=require('farm.lib.util')
local Worker=require('farm.worker')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
for originalHeading=1,4 do for shaft=0,1 do
  local p={x=20,y=80,z=-30};local heading=originalHeading
  local origin=U.copy(p)
  local function blocked(q)
    if shaft==1 and q.y==80 and (q.x~=20 or q.z~=-30) then return true end
    -- Force the probe to try more than its initial facing.
    return q.x==20 and q.z==-31
  end
  local function move(d)
    local q=U.add(p,d);if blocked(q) then return false end;p=q;return true
  end
  gps={locate=function() return p.x,p.y,p.z end}
  turtle={inspect=function() return blocked(U.add(p,U.dirs[heading])) end,
    inspectUp=function() return blocked(U.add(p,U.dirs[5])) end,
    inspectDown=function() return blocked(U.add(p,U.dirs[6])) end,
    forward=function() return move(U.dirs[heading]) end,
    back=function() return move(U.dirs[(heading+1)%4+1]) end,
    up=function() return move(U.dirs[5]) end,down=function() return move(U.dirs[6]) end,
    turnLeft=function() heading=((heading-2)%4)+1;return true end,
    turnRight=function() heading=heading%4+1;return true end}
  local found,h=Worker.calibrate()
  assert(U.equal(found,origin));assert(U.equal(p,origin));eq(h,originalHeading);eq(heading,originalHeading)
end end
print('PASS GPS heading calibration: all four orientations, blocked probes, vertical-passage recovery')
