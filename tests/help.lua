-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local Help=require('farm.lib.help')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local h=assert(io.open('farm/controller.lua','rb'));local source=h:read('*a');h:close()
-- The dispatcher is the source of truth: read the tokens it actually accepts.
local dispatched={}
for word in source:gmatch("cmd=='([%a_]+)'") do dispatched[word]=true end
assert(dispatched.status and dispatched.screen and dispatched.quit,'Command scan found nothing')
local documented={}
for _,t in ipairs(Help.topics) do
  for _,name in ipairs(t.names) do
    assert(not documented[name],'Duplicate help topic for '..name)
    documented[name]=t
  end
end
for word in pairs(dispatched) do
  assert(documented[word],'Console accepts '..word..' but farm/lib/help.lua does not document it')
  assert(Help.find(word)==documented[word],'help '..word..' does not resolve')
end
for word in pairs(documented) do
  assert(dispatched[word],'Help documents '..word..' but the console does not dispatch it')
end
print('PASS every command the controller console dispatches is documented, and nothing extra is')
local overview=Help.lines()
local text=table.concat(overview,'\n')
assert(overview[1]:find('help NAME',1,true),'Overview must say how to get detail')
for _,t in ipairs(Help.topics) do
  for _,form in ipairs(t.usage) do
    assert(text:find(form,1,true),'Overview omits '..form)
  end
end
assert(text:find('screen NAME scale 0.5|1|1.5|2',1,true))
assert(text:find('check update',1,true));assert(text:find('update system',1,true))
assert(text:find('exclude X Y Z',1,true));assert(text:find('allow ID',1,true))
print('PASS the overview lists every usage form, including the argument-taking ones')
-- Anything wider than the terminal wraps mid-word and reads as garbage in game.
local function fits(lines,what)
  for _,line in ipairs(lines) do
    assert(#line<=Help.width,what..' line is '..#line..' columns: '..line)
  end
end
fits(overview,'Overview')
for _,t in ipairs(Help.topics) do fits(Help.lines(t.names[1]),'help '..t.names[1]) end
fits(Help.lines('nonsense'),'Unknown-command')
print('PASS every help line fits the 51-column advanced computer terminal')
local stop=Help.lines('stop')
eq(stop[1],'stop')
assert(table.concat(stop,'\n'):find('Same command: exit, quit',1,true))
eq(table.concat(Help.lines('exit'),'\n'),table.concat(stop,'\n'))
eq(table.concat(Help.lines('quit'),'\n'),table.concat(stop,'\n'))
print('PASS stop, exit and quit share one explanation that names the aliases')
local screen=Help.lines('screen')
eq(screen[1],'screen NAME map|stats');eq(screen[2],'screen NAME scale 0.5|1|1.5|2')
assert(table.concat(screen,'\n'):find('printed by screens',1,true))
local update=table.concat(Help.lines('check'),'\n')
assert(update:find('five minutes',1,true),'check update must warn about the GitHub manifest cache')
print('PASS a multi-form command shows both forms, and check update warns about the manifest cache')
local unknown=Help.lines('flibbertigibbet')
assert(unknown[1]:find('flibbertigibbet',1,true));assert(unknown[2]:find('Type help',1,true))
eq(table.concat(Help.lines(''),'\n'),table.concat(overview,'\n'))
print('PASS an unknown word is named back and points at help; an empty argument lists everything')
