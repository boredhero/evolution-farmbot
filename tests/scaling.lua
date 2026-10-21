-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local G=require('farm.lib.garden')
local B=require('farm.lib.batches')
local g=G.new()
for i=1,4096 do
  local name='test:crop_'..i%16;local key=tostring(i)
  g:observe({key=key,name=name,crop=name,seed=name..'_seed'},0)
end
local calls=0;local counts=g.counts
g.counts=function(self) calls=calls+1;return counts(self) end
g.living=function() error('Repeated per-plant population scan') end
local state={};local crops={}
for id=1,16 do
  local tasks=g:tasks({}, {},1,false);local options={}
  for _,j in ipairs(tasks) do options[#options+1]={job=j,score=tonumber(j.key)} end
  local ordered=B.order(state,options,options,id);assert(#ordered>0)
  local j=ordered[1].job;assert(not crops[j.crop]);crops[j.crop]=id;B.assigned(state,id,j)
end
assert(calls==16,'Only one linear population count per worker task query')
g:reserves();assert(calls==17)
print('PASS 4096 plants and sixteen workers: exclusive crop rounds and linear shared population counting')
