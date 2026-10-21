-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
os.queueEvent=function() end
os.pullEvent=function() coroutine.yield() end
local S=require('farm.lib.store')
local J=require('farm.lib.journal')
local function clone(x) if type(x)~='table' then return x end;local t={};for k,v in pairs(x) do t[k]=clone(v) end;return t end
local files={};local fail=false
S.load=function(p,d) return clone(files[p] or files[p..'.bak'] or d) end
S.save=function(p,d) if fail then error('disk full') end;files[p..'.bak']=files[p];files[p]=clone(d) end
fs={exists=function(p) for name in pairs(files) do if name:sub(1,#p)==p then return true end end;return false end,
 list=function(p) local a={};for name in pairs(files) do if name:sub(1,#p+1)==p..'/' then a[#a+1]=name:sub(#p+2) end end;return a end,
 delete=function(p) files[p]=nil end}
local state={garden={plots={a={debt=false}},serial=1,seeds={}},history={},batches={},metrics={},growth={}}
local j=J.new('controller',state);j:checkpoint()
state.garden.plots.a.debt=true;j:record({key='a'})
local recovered=S.load('controller');J.new('controller',recovered);assert(recovered.garden.plots.a.debt)
state.garden.plots.a.debt=false;j:record({key='a'});j:checkpoint()
files.controller=nil -- Backup snapshot must still replay all mutations.
recovered=S.load('controller');J.new('controller',recovered);assert(recovered.journalSeq==2 and not recovered.garden.plots.a.debt)
j:checkpoint();state.history.a={harvests=7};j:record({key='a'})
recovered=S.load('controller');J.new('controller',recovered);assert(recovered.history.a.harvests==7)
state.garden.plots.a=nil;j:record({key='a'})
recovered=S.load('controller');J.new('controller',recovered);assert(not recovered.garden.plots.a)
local seq=state.journalSeq;fail=true;assert(not pcall(function() j:record() end));assert(state.journalSeq==seq and not j.busy)
fail=false;j:checkpoint();recovered=S.load('controller');J.new('controller',recovered);assert(recovered.journalSeq==seq)
print('PASS atomic mutation journal: debt/replant/delete replay, backup snapshot recovery, checkpoint compaction and failed writes')
