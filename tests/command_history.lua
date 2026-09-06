-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local S=require('farm.lib.store')
local H=require('farm.lib.command_history')
local stored,writes={},0
local function clone(a) local t={};for i,v in ipairs(a) do t[i]=v end;return t end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
S.load=function(path,default) eq(path,'farm/data/commands');return stored end
S.save=function(path,data) eq(path,'farm/data/commands');stored=clone(data);writes=writes+1 end
local function enter(history,line,expected)
  read=function(replacement,entries)
    eq(replacement,nil);eq(entries,history.entries)
    if expected then eq(table.concat(entries,'|'),expected) end
    return line
  end
  eq(history:read(),line)
end
local h=H.new()
enter(h,'status','');enter(h,'crops','status');enter(h,'screen monitor_0 scale 1','status|crops')
eq(#stored,3)
print('PASS controller read receives chronological history for native CraftOS Up/Down and editing')
enter(h,'screen monitor_0 scale 1');enter(h,'   ');eq(writes,3)
enter(h,'  status  ');eq(stored[4],'status');eq(writes,4)
print('PASS blank lines and consecutive duplicates skipped; commands normalized for recall')
local restarted=H.new();eq(#restarted.entries,4);eq(restarted.entries[4],'status')
for i=1,110 do enter(restarted,'test '..i) end
eq(#stored,20);eq(stored[1],'test 91');eq(stored[20],'test 110')
local again=H.new();eq(#again.entries,20)
print('PASS last 20 commands persist FIFO across restarts without growing indefinitely')
stored='invalid';eq(#H.new().entries,0)
stored={'status',false,'',string.rep('x',513),'bad\nline','crops'}
local repaired=H.new();eq(table.concat(repaired.entries,'|'),'status|crops')
print('PASS malformed saved history entries are ignored safely')
