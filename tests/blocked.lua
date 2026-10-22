-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;'..package.path
local W=require('farm.lib.world');local P=require('farm.lib.path');local B=require('farm.lib.blocked')
local w=W.new({x=0,y=0,z=0},2);local scan={}
for y=-2,2 do for z=-2,2 do scan[#scan+1]={x=0,y=y,z=z,name=(y==0 and z==0) and 'minecraft:wall_torch' or 'minecraft:stone'} end end
w:ingest(scan)
local start={x=-1,y=0,z=0};local goal={x=1,y=0,z=0}
local component=w:component(w:index(start))
local d=B.explain(w,start,{goal},'No route in surveyed space')
assert(d.kind=='bridge' and #d.candidates>0)
local torch=false
-- Multiple wall blocks are valid openings; every suggested removal must open a route.
for _,c in ipairs(d.candidates) do
 local copy=W.new(w.center,w.radius);copy.packed=w.packed;copy:observe(c.pos,nil)
 assert(P.find(copy,start,{goal}));if c.name=='minecraft:wall_torch' then torch=true end
end
assert(torch)
local blocked=B.explain(w,start,{{x=0,y=0,z=0}},'No accessible approach cell')
assert(blocked.kind=='approach' and blocked.candidates[1].name=='minecraft:wall_torch')
assert(#B.explain(w,start,{goal},'Search budget reached').candidates==0)
local plots={a={live=true,job={name='minecraft:wheat',pos=goal}}};local history={a={routeIssue=d}}
assert(#B.list(plots,history,{})==1);assert(#B.list(plots,history,{a=true})==0)
history.a.routeIssue=nil;assert(#B.list(plots,history,{})==0)
local m=require('tests.dashboard_fixture')();m.plots=plots;m.history={a={routeIssue=blocked}}
local D=require('farm.dashboard');local ui=D.new();local v=ui:view('test');v.blocked=true
local f,hits=ui:render(m,v,51,19);local text='';for y=1,f.h do text=text..f:row(y)..'\n' end
assert(text:find('0,0,0',1,true));assert(text:find('MC:wall_torch',1,true))
for _,hit in ipairs(hits) do assert(hit.y>=18) end
ui.hits.test=hits
for _,hit in ipairs(hits) do if hit.action=='view' then assert(ui:touch('test',hit.x,hit.y,m));assert(not v.blocked);break end end
print('PASS blocked crop diagnostics identify valid openings, avoid guesses and render coordinates with reachable controls')
