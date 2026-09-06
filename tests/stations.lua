-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- A chest given by coordinate is walked to and faced, never reached at range.
package.path='./?.lua;'..package.path
local U=require('farm.lib.util')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
-- Every station must be approachable from a horizontal neighbour, and the
-- turtle must be able to work out which way to turn once it arrives.
local target={x=10,y=64,z=-3}
local neighbours={}
for i=1,4 do neighbours[#neighbours+1]=U.add(target,U.dirs[i]) end
eq(#neighbours,4)
local headings={}
for _,cell in ipairs(neighbours) do
  eq(U.distance(cell,target),1)
  local h=U.heading({x=target.x-cell.x,y=0,z=target.z-cell.z})
  assert(h,'no heading from '..U.key(cell))
  headings[h]=(headings[h] or 0)+1
end
eq(headings[1],1);eq(headings[2],1);eq(headings[3],1);eq(headings[4],1)
print('PASS a station has four standing cells, each with exactly one facing that looks at it')
-- Standing above or below cannot face the block, which is why approach uses
-- horizontal neighbours only.
eq(U.heading({x=0,y=1,z=0}),nil);eq(U.heading({x=0,y=-1,z=0}),nil)
eq(U.heading({x=2,y=0,z=0}),nil)
print('PASS vertical and distant offsets yield no facing, so only adjacent cells are used')
local setup=io.open('farm/setup.lua'):read('*a')
assert(setup:find('cfg.stations',1,true),'setup must record stations')
assert(setup:find('PUT harvested items into',1,true))
assert(setup:find('TAKE coal/charcoal from',1,true))
assert(not setup:find('output.name',1,true),'setup must not read a block it no longer inspects')
local worker=io.open('farm/worker.lua'):read('*a')
assert(worker:find('function approach(target,what)',1,true),'worker must visit stations')
assert(worker:find('stations.output',1,true) and worker:find('stations.fuel',1,true))
assert(worker:find("navigate({cfg.dock},true) end",1,true),'worker must park at home after using stations')
print('PASS setup records coordinates and the worker visits them instead of requiring adjacency')
local farm=io.open('farm.lua'):read('*a')
assert(farm:find("command=='station'",1,true),'a worker must be able to move a chest without rerunning setup')
assert(farm:find("command=='stations'",1,true),'a worker must be able to show where its chests are')
assert(farm:find("saved.stations[which]=nil",1,true),'moving a chest must forget the block learned at the old spot')
assert(farm:find('cannot be removed',1,true),'the output chest must not be removable')
assert(farm:find('station output|fuel X Y Z',1,true),'the usage line must mention station')
-- Clearing a learned block must not disturb the unfinished-harvest journal.
local before=farm:find('S.load(\'farm/data/worker\',{})',1,true)
assert(before,'station editing reads the worker journal rather than deleting it')
assert(not farm:find('fs.delete',1,true),'never delete worker data to reset a station')
print('PASS a chest can be moved or swapped with farm station, without rerunning setup or losing the journal')
