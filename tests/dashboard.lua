-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local D=require('farm.dashboard')
local F=require('farm.lib.frame')
local M=require('farm.lib.metrics')
local fixture=require('tests.dashboard_fixture')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function contains(frame,pattern)
  for y=1,frame.h do local row=frame:row(y);if row:find(pattern,1,true) then return true end end
  return false
end
local function validate(frame)
  for y=1,frame.h do local t,f,b=frame:row(y)
    eq(#t,frame.w);eq(#f,frame.w);eq(#b,frame.w);assert(not f:find('[^0-9a-f]'));assert(not b:find('[^0-9a-f]'))
  end
end
local m=fixture();local d=D.new()
eq(d:view('monitor_0').role,'map');eq(d:view('monitor_1').role,'stats')
local frame,hits=d:render(m,d:view('monitor_0'),164,81);validate(frame)
assert(contains(frame,'TACTICAL MAP'));assert(contains(frame,'CROP Y=65'))
assert(contains(frame,'CACHED ROUTES'));assert(#hits>50)
d.hits.monitor_0=hits
local floorButton
for _,hit in ipairs(hits) do if hit.action=='layer' and hit.value==1 then floorButton=hit end end
assert(d:touch('monitor_0',floorButton.x,floorButton.y,m));eq(d.views.monitor_0.layer,81)
local upper=d:render(m,d.views.monitor_0,164,81);assert(contains(upper,'CROP Y=81'))
print('PASS two monitor roles, floor switching, crop map and route overlay controls')
local stats=d:render(m,d:view('monitor_1'),164,81);validate(stats)
assert(contains(stats,'OPERATIONS'));assert(contains(stats,'LIFETIME HARVESTS'));assert(contains(stats,'14832'))
assert(contains(stats,'cottonly:cotton_plant'));assert(contains(stats,'MC:wheat'))
for _,size in ipairs({{51,19},{60,34},{60,40},{80,36},{120,50},{205,68},{164,81}}) do
  for _,role in ipairs({'map','stats'}) do validate(d:render(m,{role=role},size[1],size[2])) end
end
print('PASS responsive frames, live counts and lifetime per-crop statistics')
local p
for _,v in pairs(m.plots) do if v.live and not v.intent and v.job.age then p=v;break end end
eq(D.classify(p,nil,m),'unknown')
eq(D.classify(p,{observed={name=p.job.name,state={age=p.job.age}},observedAt=1},m),'stale')
eq(D.classify(p,{observed={name=p.job.name,state={age=p.job.age}},observedAt=999},m),'ready')
eq(D.classify(p,{observed={name=p.job.name,state={age=0}},observedAt=999},m),'growing')
print('PASS no invented live maturity: unknown/stale/mature/just-replanted distinguished')
local writes=0
local monitor={setCursorPos=function() end,blit=function() writes=writes+1 end}
local cache=frame:flush(monitor);eq(writes,81)
cache=frame:flush(monitor,cache);eq(writes,81)
frame:write(2,2,'x');frame:flush(monitor,cache);eq(writes,82)
print('PASS monitor redraw sends changed rows only')
local metrics=M.new(nil,100)
local j={name='minecraft:wheat',seed='minecraft:wheat_seeds'}
metrics:record(j,'deferred',false,110)
metrics:record(j,'replanted',{name=j.name},120)
metrics:record(j,'harvested',{name=j.name},130)
metrics:record(j,'dry_run',{name=j.name},140)
metrics:tick(160);eq(metrics.data.uptime,60);eq(metrics.data.harvests,2);eq(metrics.data.replants,2)
local restarted=M.new(metrics.data,1000);restarted:tick(1020)
eq(restarted.data.uptime,80);eq(restarted.data.sessions,2);eq(restarted.data.harvests,2)
print('PASS durable metrics: dry runs excluded, gap repairs counted, offline time excluded')
for i=1,150 do m.metrics.byCrop['test:crop_'..i]={harvests=i} end
local page1=d:render(m,{role='stats',page=1},164,81)
local page2=d:render(m,{role='stats',page=2},164,81)
assert(contains(page1,'PAGE 1 OF'));assert(contains(page2,'PAGE 2 OF'))
print('PASS many crop types paginate instead of disappearing off screen')
local compact,compactHits=d:render(m,{role='stats'},60,34)
assert(contains(compact,'OPERATIONS'));assert(contains(compact,'LIFETIME HARVESTS'));assert(contains(compact,'CROP COUNTS'))
assert(not contains(compact,'Use TEXT -'))
local colorMap,colorHits=d:render(m,{role='map',zoom=1},121,81)
local colored=0
for _,hit in ipairs(colorHits) do if hit.action=='select' then
  local _,_,bg=colorMap:row(hit.y);assert(bg:sub(hit.x,hit.x)~='f');colored=colored+1
end end
assert(colored>100)
eq(D.cropColor('minecraft:wheat'),'4');eq(D.cropColor('minecraft:carrots'),'1')
eq(D.cropColor('newmod:new_crop'),D.cropColor('newmod:new_crop'))
d.hits.monitor_1=compactHits
for _,hit in ipairs(compactHits) do if hit.action=='scale' and hit.value==0.5 then
  assert(d:touch('monitor_1',hit.x,hit.y,m));eq(d.views.monitor_1.scale,1.5)
end end
local realScale=0.5
local mon={getTextScale=function() return realScale end,setTextScale=function(s) realScale=s end,
  getSize=function() return 60,34 end,setCursorPos=function() end,blit=function() end}
local fresh=D.new();fresh:draw(mon,'stats',m);eq(realScale,1)
print('PASS readable scale-1 layout, crop-colored tiles, and persistent text-size touch controls')
local oldFs,oldTextutils=fs,textutils
local closed=false
fs={open=function(path) eq(path,'farm/version.json');return {readAll=function() return 'json' end,close=function() closed=true end} end}
textutils={unserializeJSON=function() return {version='0.2.2'} end}
eq(D.installedVersion(),'0.2.2');assert(closed)
textutils.unserializeJSON=function() error('Bad JSON') end;eq(D.installedVersion(),'unversioned')
fs={open=function() return nil end};eq(D.installedVersion(),'unversioned')
fs,textutils=oldFs,oldTextutils
m.version='0.2.2'
for _,size in ipairs({{60,34},{121,81}}) do
  local versionFrame=d:render(m,{role='stats'},size[1],size[2]);validate(versionFrame)
  assert(contains(versionFrame,'v0.2.2'));assert(contains(versionFrame,'[TEXT +]'))
end
print('PASS statistics shows installed metadata version at both text scales; missing/corrupt metadata is safe')
