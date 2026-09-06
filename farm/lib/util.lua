-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U = {}
function U.key(p) return p.x .. ',' .. p.y .. ',' .. p.z end
function U.copy(p) return {x=p.x,y=p.y,z=p.z} end
function U.add(p,d) return {x=p.x+d.x,y=p.y+d.y,z=p.z+d.z} end
function U.equal(a,b) return a and b and a.x==b.x and a.y==b.y and a.z==b.z end
function U.distance(a,b) return math.abs(a.x-b.x)+math.abs(a.y-b.y)+math.abs(a.z-b.z) end
function U.now() return os.epoch('utc')/1000 end
function U.round(x) return math.floor(x+0.5) end
-- Heading order follows clockwise turns: north, east, south, west.
U.dirs={{x=0,y=0,z=-1},{x=1,y=0,z=0},{x=0,y=0,z=1},{x=-1,y=0,z=0},
        {x=0,y=1,z=0},{x=0,y=-1,z=0}}
function U.heading(d)
  for i=1,4 do if U.equal(d,U.dirs[i]) then return i end end
end
function U.locate()
  local x,y,z=gps.locate(3)
  if not x then error('GPS unavailable. Check all four GPS hosts and Ender Modems.',0) end
  return {x=U.round(x),y=U.round(y),z=U.round(z)}
end
function U.openModem()
  for _,name in ipairs(peripheral.getNames()) do
    if peripheral.hasType(name,'modem') and peripheral.call(name,'isWireless') then
      rednet.open(name); return name
    end
  end
  error('Attach an Ender Modem to this computer/turtle.',0)
end
function U.yield() sleep(0) end
return U
