-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local R=require('farm.lib.route_cache')
local D=require('farm.dashboard')
local m=require('tests.dashboard_fixture')();m.settings={}
assert(R.limit(m.settings)==512 and R.limit({routeCacheLimit=999})==512)
local cache={};for i=1,1024 do cache[tostring(i)]={used=i} end
cache['1'].used=2048
R.trim(cache,32);local n=0;for _ in pairs(cache) do n=n+1 end
assert(n==32 and cache['1'] and cache['1024'] and not cache['992'])
cache.new={used=2049};R.trim(cache,32);assert(cache.new and not cache['994'])
for _,size in ipairs({{51,19},{164,81}}) do
 local d=D.new();local v=d:view('settings');v.settings=true;v.setting=9
 local function click(delta)
  local _,hits=d:render(m,v,size[1],size[2]);d.hits.settings=hits
  for _,hit in ipairs(hits) do
   assert(hit.y>=size[2]-1 and hit.x+hit.w-1<=size[1])
   if hit.action=='routeLimit' and hit.value==delta then assert(d:touch('settings',hit.x,hit.y,m));return end
  end
  error('Missing route limit arrow')
 end
 m.settings={};click(1);assert(m.settings.routeCacheLimit==1024);click(1);assert(m.settings.routeCacheLimit==1024)
 for i=5,1,-1 do click(-1);assert(m.settings.routeCacheLimit==R.limits[i]) end
 click(-1);assert(m.settings.routeCacheLimit==32)
 for i=2,6 do click(1);assert(m.settings.routeCacheLimit==R.limits[i]) end
end
print('PASS cache settings default512, follow all six exact choices with bounded arrows, and shrinking preserves recently reused routes')
