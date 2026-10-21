-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local M=require('farm.lib.metrics')
local D=require('farm.dashboard')
local m=M.new(nil,100);m.data.harvests=813
local j={name='minecraft:wheat',seed='minecraft:wheat_seeds'}
m:record(j,'harvested',{name=j.name},110,nil,9)
m:record(j,'growing',nil,111,nil,10)
m:record(j,'dry_run',nil,112,nil,10)
m:report(9,{steps=50},113);m:report(9,{steps=50},114);m:report(9,{steps=20},115)
m=M.new(m.data,200);m:tick(201)
assert(m.data.harvests==814 and m.data.byWorker['9'].harvests==1)
assert(m.data.byWorker['9'].replants==1 and m.data.byWorker['9'].steps==50)
assert(m.data.byWorker['10'].inspections==1 and m.data.uptime==1)
local model=require('tests.dashboard_fixture')();model.metrics=m.data
local d=D.new();local v=d:view('test')
for _,size in ipairs({{51,19},{60,34},{120,50}}) do
 v.role='map';v.lifetime=false
 local _,hits=d:render(model,v,size[1],size[2]);d.hits.test=hits
 local stats;for _,hit in ipairs(hits) do if hit.value=='lifetime' then stats=hit end end
 assert(stats and d:touch('test',stats.x,stats.y,model));assert(v.lifetime)
 local frame;frame,hits=d:render(model,v,size[1],size[2]);d.hits.test=hits
 local found=false;for y=1,frame.h do if frame:row(y):find('LIFETIME STATS',1,true) then found=true end end;assert(found)
 for _,hit in ipairs(hits) do assert(hit.y>=size[2]-1 and hit.x+hit.w-1<=size[1]) end
 for _,hit in ipairs(hits) do if hit.action=='bot' and hit.value==1 then d:touch('test',hit.x,hit.y,model);break end end
 d:render(model,v,size[1],size[2]);assert(v.bot==2);v.bot=1
end
print('PASS lifetime migration, independent workers, dry runs, duplicate reports, restarts and reachable stats navigation')
