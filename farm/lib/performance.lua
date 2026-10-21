-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local P={};P.__index=P
function P.new() return setmetatable({since=U.now(),samples={}},P) end
function P:record(name,started)
  local ms=math.max(0,(U.now()-started)*1000)
  local r=self.samples[name] or {count=0,totalMs=0,maxMs=0};self.samples[name]=r
  r.count=r.count+1;r.totalMs=r.totalMs+ms;r.maxMs=math.max(r.maxMs,ms);r.lastMs=ms
end
return P
