-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local W=require('farm.lib.world')
local P=require('farm.lib.path')
local U=require('farm.lib.util')
local function pos(x,y,z) return {x=x,y=y,z=z} end
local function bfs(w,start,goals,avoid)
  local targets={};for _,p in ipairs(goals) do targets[U.key(p)]=true end
  local queue={{p=start,d=0}};local seen={[U.key(start)]=true};local at=1
  while queue[at] do
    local entry=queue[at];at=at+1
    if targets[U.key(entry.p)] then return entry.d end
    for _,v in ipairs(U.dirs) do
      local p=U.add(entry.p,v);local k=U.key(p)
      if not seen[k] and not w:blocked(p) and not avoid[k] then
        seen[k]=true;queue[#queue+1]={p=p,d=entry.d+1}
      end
    end
  end
end
math.randomseed(4186)
for trial=1,80 do
  local w=W.new(pos(139,74,-923),3);local blocks,avoid={},{}
  for x=-3,3 do for y=-3,3 do for z=-3,3 do
    local p=U.add(w.center,pos(x,y,z))
    if math.random()<0.35 then blocks[#blocks+1]={x=x,y=y,z=z,name='minecraft:stone'} end
    if math.random()<0.12 then avoid[U.key(p)]=true end
  end end end
  w:ingest(blocks)
  local start=U.add(w.center,pos(-3,-3,-3));local goals={U.add(w.center,pos(3,3,3)),U.add(w.center,pos(3,-3,3))}
  local path,_,expanded=P.find(w,start,goals,{avoid=avoid})
  assert(type(expanded)=='number');assert((path and #path or nil)==bfs(w,start,goals,avoid))
  if path then assert(P.valid(w,start,path,avoid)) end
end
print('PASS indexed A* matches BFS with translated coordinates, dynamic traffic and multiple goals')
local w=W.new(pos(0,0,0),32);local blocks={}
for y=-32,32 do for z=-32,32 do blocks[#blocks+1]={x=0,y=y,z=z,name='minecraft:stone'} end end
w:ingest(blocks)
local positions,indexes=0,0;local oldPosition,oldIndex=w.position,w.index
w.position=function(self,id) positions=positions+1;return oldPosition(self,id) end
w.index=function(self,p) indexes=indexes+1;return oldIndex(self,p) end
local yields=0
local path,reason,expanded=P.find(w,pos(-1,0,0),{pos(1,0,0)},{limit=3000,yieldFn=function() yields=yields+1 end})
assert(not path and reason=='Search budget reached' and expanded==3001)
assert(yields==3 and positions==0 and indexes<=4,'Search hot loop must not allocate voxel positions or reindex neighbors')
local small=W.new(pos(0,0,0),1);small:ingest({})
for _,d in ipairs(U.dirs) do small:observe(d,{name='minecraft:stone'}) end
local _,failure,count=P.find(small,pos(0,0,0),{pos(1,1,1)})
assert(failure=='No route in surveyed space' and count==1)
print('PASS failed route profiling reports expansions and bounded yields without neighbor coordinate allocations')
