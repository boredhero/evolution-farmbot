-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local S=require('farm.lib.store')
local Seeds=require('farm.lib.seeds')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local files,dirs={},{}
local function serialize(v)
  if type(v)=='table' then
    local parts={};for k,x in pairs(v) do parts[#parts+1]='['..serialize(k)..']='..serialize(x) end
    return '{'..table.concat(parts,',')..'}'
  elseif type(v)=='string' then return string.format('%q',v) end
  return tostring(v)
end
textutils={serialize=serialize,unserialize=function(raw)
  local f=load('return '..raw,'test','t',{});return f and f()
end}
fs={exists=function(p) return files[p]~=nil or dirs[p] end,
  getDir=function(p) return p:match('^(.*)/') or '' end,
  makeDir=function(p) dirs[p]=true end,isDir=function(p) return dirs[p] or false end,
  getFreeSpace=function() return 1000000 end,
  delete=function(p) files[p]=nil;dirs[p]=nil end,
  move=function(a,b) assert(files[a] and not files[b]);files[b]=files[a];files[a]=nil end,
  copy=function(a,b) assert(files[a] and not files[b]);files[b]=files[a] end,
  open=function(p,mode)
    if mode=='r' then if not files[p] then return nil end;return {readAll=function() return files[p] end,close=function() end} end
    return {write=function(s) files[p]=s end,close=function() end}
  end}
S.save('farm/data/controller',{debt='wheat'});S.save('farm/data/controller',{debt='cotton'})
eq(S.load('farm/data/controller').debt,'cotton')
files['farm/data/controller']='broken';eq(S.load('farm/data/controller').debt,'wheat')
print('PASS durable store: compact round trip and corrupt-primary backup recovery')
local inventories={bank={},buffer={}}
local function wrap(name)
  local inv=inventories[name];if not inv then return nil end
  return {list=function() return inv end,pushItems=function(to,slot,limit)
    local target=inventories[to];if not target then error('Disconnected inventory') end
    local item=inv[slot];if not item then return 0 end
    local n=math.min(limit,item.count);local dest
    for i,v in pairs(target) do if v.name==item.name then dest=i;break end end
    if not dest then dest=1;while target[dest] do dest=dest+1 end;target[dest]={name=item.name,count=0} end
    target[dest].count=target[dest].count+n;item.count=item.count-n
    if item.count==0 then inv[slot]=nil end
    return n
  end}
end
peripheral={wrap=wrap}
inventories.buffer[1]={name='cottonly:cotton_seeds',count=7}
assert(Seeds.store('bank','buffer'));eq(Seeds.stock('bank')['cottonly:cotton_seeds'],7)
assert(Seeds.deliver('bank','buffer','cottonly:cotton_seeds'))
eq(inventories.buffer[1].count,4);eq(Seeds.stock('bank')['cottonly:cotton_seeds'],3)
assert(Seeds.deliver('bank','buffer','cottonly:cotton_seeds'));eq(inventories.buffer[1].count,4)
assert(not Seeds.deliver('bank','buffer','newmod:no_seeds'))
eq(Seeds.stock('bank')['cottonly:cotton_seeds'],7)
print('PASS automatic seed pooling, delivery reuse, and empty-supply preservation')
files['farm/config']='existing config';files['farm.lua']='old program';files['startup.lua']='old startup'
os.epoch=function() return 12345 end
shell={run=function() error('Installer should not reconfigure existing farm') end}
assert(loadfile('install.lua'))()
eq(files['farm/config'],'existing config')
eq(files['farm/install-backups/12345/farm.lua'],'old program')
eq(files['farm/install-backups/12345/startup.lua'],'old startup')
assert(files['farm/lib/garden.lua']);assert(files['startup.lua']:find('farm.lua',1,true))
print('PASS generated installer preserves configuration and backs up startup/programs')
