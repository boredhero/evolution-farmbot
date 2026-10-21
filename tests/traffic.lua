-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local T=require('farm.lib.traffic')
local U=require('farm.lib.util')
local workers={}
for id=1,16 do workers[id]={pos={x=id,y=0,z=0},seen=100} end
local contested={x=8,y=0,z=1}
assert(T.claim(workers,8,workers[8].pos,contested,100).ok)
workers[9].pos={x=9,y=0,z=1}
local claim=T.claim(workers,9,workers[9].pos,contested,100)
assert(not claim.ok and claim.worker==8)
T.update(workers[8],contested,101);assert(not workers[8].nextPos)
assert(not T.claim(workers,9,workers[9].pos,contested,101).ok)
T.update(workers[8],{x=8,y=0,z=2},102);assert(T.claim(workers,9,workers[9].pos,contested,102).ok)
workers[8].routeStart=workers[8].pos;workers[8].route={{x=8,y=0,z=3},{x=8,y=0,z=4},{x=8,y=0,z=5},{x=8,y=0,z=6}}
assert(T.avoid(workers,9,102,true)['8,0,5']);assert(not T.avoid(workers,9,102,true)['8,0,6'])
assert(not T.avoid(workers,9,102,false)['8,0,5'])
assert(not T.avoid(workers,9,111,true)['8,0,5'])
assert(T.turtle('computercraft:turtle_advanced') and not T.turtle('minecraft:stone'))
-- Sixteen simultaneous approaches to shared cells cannot claim the same destination.
for id,w in pairs(workers) do w.pos={x=id,y=0,z=0};w.nextPos=nil;w.seen=200 end
local occupied={}
for id,w in pairs(workers) do
  local target={x=id,y=1,z=0};assert(T.claim(workers,id,w.pos,target,200).ok)
  local key=U.key(w.nextPos);assert(not occupied[key]);occupied[key]=id
end
print('PASS sixteen-worker traffic claims, crossing exclusion, fresh positions, short route lookahead and expired reservations')
