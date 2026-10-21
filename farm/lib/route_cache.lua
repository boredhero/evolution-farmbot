-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local R={limits={32,64,128,256,512,1024},default=512}
function R.limit(settings)
  local value=settings and settings.routeCacheLimit
  for _,n in ipairs(R.limits) do if n==value then return n end end
  return R.default
end
function R.adjust(settings,delta)
  local value=R.limit(settings);local at=1
  for i,n in ipairs(R.limits) do if n==value then at=i;break end end
  settings.routeCacheLimit=R.limits[math.max(1,math.min(#R.limits,at+delta))]
end
function R.trim(cache,limit)
  local n,oldest,used=0
  for key,r in pairs(cache) do
    n=n+1;if not used or (r.used or 0)<used then oldest,used=key,r.used or 0 end
  end
  if n<=limit then return end
  if n==limit+1 then cache[oldest]=nil;return end
  local entries={};for key,r in pairs(cache) do entries[#entries+1]={key=key,used=r.used or 0} end
  table.sort(entries,function(a,b) return a.used<b.used or (a.used==b.used and a.key<b.key) end)
  for i=1,n-limit do cache[entries[i].key]=nil end
end
return R
