-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
package.path='./?.lua;./?/init.lua;'..package.path
local U=require('farm.lib.util')
local W=require('farm.lib.world')
local P=require('farm.lib.path')
local C=require('farm.lib.crops')
local G=require('farm.lib.garden')
local tests,passed={},0
local function test(name,f) tests[#tests+1]={name,f} end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function pos(x,y,z) return {x=x,y=y,z=z} end
local function block(name,x,y,z,tags) return {name=name,x=x,y=y,z=z,tags=tags} end
local function world(blocks,r) local w=W.new(pos(0,0,0),r or 5);w:ingest(blocks or {});return w end
local function field(names)
  local blocks={}
  for i,name in ipairs(names) do
    blocks[#blocks+1]=block('minecraft:farmland',i,0,0)
    blocks[#blocks+1]=block(name,i,1,0)
  end
  return world(blocks)
end
local function learn(w)
  local g=G.new();g:scan(w,C.discover(w),1,2);return g
end
local function job(g,key)
  local p=g.data.plots[key];local j={}
  for k,v in pairs(p.job) do j[k]=v end;j.version=p.version;return j
end
test('packed 65-cube round trips every coordinate and bounds',function()
  local w=world({block('minecraft:stone',32,32,32)},32)
  eq(#w.packed,34329)
  for i=0,65^3-1 do eq(w:index(w:position(i)),i) end
  assert(w:blocked(pos(32,32,32)));assert(not w:blocked(pos(-32,-32,-32)))
  assert(w:blocked(pos(33,0,0)))
end)
test('map starts unknown-blocked; scan replaces stale walls; turtle cells transient',function()
  local w=W.new(pos(0,0,0),2);assert(w:blocked(pos(0,0,0)))
  w:ingest({block('computercraft:turtle_normal',0,0,0),block('minecraft:stone',1,0,0)})
  assert(not w:blocked(pos(0,0,0)));assert(w:blocked(pos(1,0,0)))
  w:ingest({});assert(not w:blocked(pos(1,0,0)))
end)
test('3D A* detours vertically without breaking walls',function()
  local w=world({block('minecraft:stone',1,0,0)})
  local path=P.find(w,pos(0,0,0),{pos(2,0,0)})
  eq(#path,4);assert(P.valid(w,pos(0,0,0),path))
  assert(not P.valid(w,pos(0,0,0),path,{[U.key(path[1])]=true}))
end)
test('full-radius diagonal route uses goal-directed A* tie breaking',function()
  local w=world({},32)
  local path,_,expanded=P.find(w,pos(-32,-32,-32),{pos(32,32,32)})
  eq(#path,192);assert(expanded<1000)
end)
test('A* matches BFS on 60 deterministic obstacle maps',function()
  math.randomseed(619)
  for trial=1,60 do
    local blocks={}
    for x=-2,2 do for y=-2,2 do for z=-2,2 do
      if math.random()<0.3 and not (x==-2 and y==-2 and z==-2) then blocks[#blocks+1]=block('minecraft:stone',x,y,z) end
    end end end
    local w=world(blocks,2);local start,goal=pos(-2,-2,-2),pos(2,2,2)
    local queue={{start,0}};local seen={[U.key(start)]=true};local at=1;local length
    while queue[at] do
      local p,n=queue[at][1],queue[at][2];at=at+1
      if U.equal(p,goal) then length=n;break end
      for _,d in ipairs(U.dirs) do local q=U.add(p,d)
        if not w:blocked(q) and not seen[U.key(q)] then seen[U.key(q)]=true;queue[#queue+1]={q,n+1} end
      end
    end
    local path=P.find(w,start,{goal});eq(path and #path or nil,length)
  end
end)
test('requested crop maturity and item mappings',function()
  local rows={
    {'minecraft:wheat',7,'minecraft:wheat_seeds'}, {'minecraft:beetroots',3,'minecraft:beetroot_seeds'},
    {'actuallyadditions:canola',7,'actuallyadditions:canola_seeds'},
    {'actuallyadditions:coffee',7,'actuallyadditions:coffee_beans'},
    {'actuallyadditions:flax',7,'actuallyadditions:flax_seeds'},
    {'farmersdelight:cabbages',7,'farmersdelight:cabbage_seeds'},
    {'farmersdelight:onions',7,'farmersdelight:onion'},
    {'farmersdelight:tomatoes',3,'farmersdelight:tomato_seeds'},
    {'hexerei:sage_crop',7,'hexerei:sage_seed'}, {'cottonly:cotton_plant',7,'cottonly:cotton_seeds'},
    {'mysticalagriculture:inferium_crop',7,'mysticalagriculture:inferium_seeds'},
    {'mysticalagriculture:diamond_crop',7,'mysticalagriculture:diamond_seeds'},
  }
  for _,r in ipairs(rows) do
    local w=field({r[1]});local j=C.discover(w)['1,1,0'];assert(j,r[1]);eq(j.seed,r[3])
    assert(C.ready(j,{name=r[1],state={age=r[2]}}))
    assert(not C.ready(j,{name=r[1],state={age=r[2]-1}}))
  end
end)
test('blueberries discovered on grass, mature only, guaranteed replant drop',function()
  local w=world({block('minecraft:grass_block',0,0,0),block('biomeswevegone:blueberry_bush',0,1,0)})
  local j=C.discover(w)['0,1,0'];eq(j.seed,'biomeswevegone:blueberries');assert(j.guaranteedSeed)
  assert(C.ready(j,{name=j.name,state={age=3}}));assert(not C.ready(j,{name=j.name,state={age=2}}))
  w:ingest({block('minecraft:stone',0,0,0),block(j.name,0,1,0)});eq(next(C.discover(w)),nil)
end)
test('MA needs MA or vanilla farmland, not arbitrary age-like decoration',function()
  local w=world({block('mysticalagriculture:insanium_farmland',0,0,0),block('mysticalagriculture:iron_crop',0,1,0)})
  assert(C.discover(w)['0,1,0'])
  eq(C.candidate(world({}),block('minecraft:wheat',0,1,0)),nil)
  eq(C.candidate(w,block('minecraft:oak_log',0,1,0)),nil)
end)
test('hemp and FD rice preserve lower blocks',function()
  local w=world({block('minecraft:farmland',0,0,0),block('immersiveengineering:hemp',0,1,0),
    block('immersiveengineering:hemp',0,2,0),block('farmersdelight:rice',2,0,0),block('farmersdelight:rice_panicles',2,1,0)})
  local jobs=C.discover(w);eq(jobs['0,1,0'],nil)
  assert(C.ready(jobs['0,2,0'],{name='immersiveengineering:hemp',state={half='upper'}}))
  assert(not C.ready(jobs['0,2,0'],{name='immersiveengineering:hemp',state={half='lower',age=4}}))
  eq(jobs['2,0,0'],nil);eq(jobs['2,1,0'].mode,'rice')
end)
test('cane keeps its root and checks sand; pumpkins do not need farmland',function()
  local w=world({block('minecraft:sand',0,0,0),block('minecraft:sugar_cane',0,1,0),
    block('minecraft:sugar_cane',0,2,0),block('minecraft:sugar_cane',0,3,0),block('minecraft:pumpkin',3,3,3)})
  local jobs=C.discover(w);eq(jobs['0,1,0'],nil);eq(jobs['0,2,0'],nil)
  eq(jobs['0,3,0'].mode,'cane');eq(jobs['3,3,3'].mode,'fruit')
end)
test('cocoa approaches opposite jungle log and checks attachment',function()
  local w=world({block('minecraft:jungle_log',0,1,-1),block('minecraft:cocoa',0,1,0)})
  local j=C.discover(w)['0,1,0'];eq(U.key(C.goals(j)[1]),'0,1,1')
  assert(C.ready(j,{name=j.name,state={age=2,facing='north'}}))
  assert(not C.ready(j,{name=j.name,state={age=2,facing='south'}}))
end)
test('unknown crop is inspect-only, never guessed from an age value',function()
  local w=world({block('minecraft:farmland',0,0,0),block('newmod:mystery',0,1,0,{'minecraft:crops'})})
  local j=C.discover(w)['0,1,0'];eq(j.mode,'probe')
  assert(not C.ready(j,{name=j.name,state={age=7}}))
end)
test('newly planted supported species automatically joins ledger',function()
  local g=learn(field({'minecraft:wheat'}));eq(g:living('minecraft:wheat_seeds'),1)
  local w=field({'minecraft:wheat','cottonly:cotton_plant'})
  g:scan(w,C.discover(w),3,4);eq(g:living('cottonly:cotton_seeds'),1)
end)
test('zero-seed harvest allowed with other plants; debt survives and attracts matching harvest',function()
  local w=field({'minecraft:wheat','minecraft:wheat','minecraft:wheat'});local g=learn(w)
  local j=job(g,'1,1,0');assert(g:begin(j,1,'a',false,3))
  assert(g:finish(j,'a',false,w,nil,4));eq(g:debts(),1);eq(g:living(j.seed),2)
  local tasks=g:tasks({}, {},5);eq(#tasks,2)
  for _,t in ipairs(tasks) do assert(not t.repair) end
end)
test('matching harvested seeds turn a remembered gap into a priority repair task',function()
  local w=field({'minecraft:wheat','minecraft:wheat'});local g=learn(w);local j=job(g,'1,1,0')
  assert(g:begin(j,1,'a',false,3));g:finish(j,'a',false,w,nil,4)
  local tasks=g:tasks({[j.seed]=2},{},5);local repair
  for _,t in ipairs(tasks) do if t.key==j.key then repair=t end end
  assert(repair.repair);assert(not repair.fetchSeed)
  assert(g:begin(repair,2,'b',true,6));g:finish(repair,'b',{name=j.name,state={age=0}},w,nil,7)
  eq(g:debts(),0);eq(g:living(j.seed),2)
end)
test('shared bank can supply repair without user seed-list configuration',function()
  local w=field({'minecraft:wheat','minecraft:wheat'});local g=learn(w);local j=job(g,'1,1,0')
  g:begin(j,1,'a',false,3);g:finish(j,'a',false,w,nil,4)
  local found=false
  for _,t in ipairs(g:tasks({}, {[j.seed]=1},5)) do if t.repair then found=true;assert(t.fetchSeed) end end
  assert(found)
end)
test('two turtles cannot both risk the final living plant',function()
  local g=learn(field({'minecraft:wheat','minecraft:wheat'}))
  assert(g:begin(job(g,'1,1,0'),1,'a',false,3))
  local allowed=g:begin(job(g,'2,1,0'),2,'b',false,3);eq(allowed,nil)
  eq(g:living('minecraft:wheat_seeds'),1)
end)
test('guaranteed-drop single crop can bootstrap with no seed inventory',function()
  local g=learn(field({'mysticalagriculture:inferium_crop'}))
  assert(g:begin(job(g,'1,1,0'),1,'a',false,3))
end)
test('write-ahead debt survives controller restart before harvest acknowledgement',function()
  local w=field({'minecraft:wheat','minecraft:wheat'});local g=learn(w);local j=job(g,'1,1,0')
  g:begin(j,1,'a',false,3)
  local restarted=G.new(g.data);eq(restarted:debts(),1)
  local empty=world({block('minecraft:farmland',1,0,0),block('minecraft:farmland',2,0,0),block('minecraft:wheat',2,1,0)})
  restarted:scan(empty,C.discover(empty),200,201);eq(restarted:debts(),1)
  assert(not restarted.data.plots[j.key].intent)
end)
test('old scan cannot erase a newly recorded harvest debt',function()
  local w=field({'minecraft:wheat','minecraft:wheat'});local g=learn(w);local j=job(g,'1,1,0')
  g:begin(j,1,'a',false,5);g:finish(j,'a',false,w,nil,6)
  g:scan(w,C.discover(w),4,7);eq(g:debts(),1)
end)
test('player replacement overrides debt and invalidates old work version',function()
  local w=field({'minecraft:wheat','minecraft:wheat'});local g=learn(w);local old=job(g,'1,1,0')
  g:begin(old,1,'a',false,3);g:finish(old,'a',false,w,nil,4)
  local changed=field({'farmersdelight:onions','minecraft:wheat'})
  g:scan(changed,C.discover(changed),5,6)
  eq(g:debts(),0);eq(g.data.plots[old.key].job.seed,'farmersdelight:onion')
  assert(not g:begin(old,1,'old',true,7))
  assert(not g:finish(old,'a',false,w,nil,8));eq(g:debts(),0)
end)
test('manual removal does not invent a replant debt',function()
  local w=field({'minecraft:wheat'});local g=learn(w);local j=job(g,'1,1,0')
  g:finish(j,'nothing',false,w,nil,3);eq(g:debts(),0);eq(g.data.plots[j.key],nil)
  g=learn(w);local empty=world({block('minecraft:farmland',1,0,0)})
  g:scan(empty,C.discover(empty),4,5);eq(next(g.data.plots),nil)
end)
test('removing farmland retires an old debt instead of fighting a redesign',function()
  local w=field({'minecraft:wheat','minecraft:wheat'});local g=learn(w);local j=job(g,'1,1,0')
  g:begin(j,1,'a',false,3);g:finish(j,'a',false,w,nil,4)
  g:scan(world({}),{},5,6);eq(g:debts(),0)
end)
test('same-family growth transition does not count as a manual crop swap',function()
  local g=learn(field({'minecraft:torchflower_crop'}));local version=g.data.plots['1,1,0'].version
  local w=field({'minecraft:torchflower'});g:scan(w,C.discover(w),3,4)
  eq(g.data.plots['1,1,0'].version,version)
end)
test('interaction crops fail closed without the narrowly scoped compatibility tag',function()
  local w=world({block('minecraft:cave_vines',0,1,0)});local j=C.discover(w)['0,1,0']
  assert(not C.ready(j,{name=j.name,state={berries=true}}))
  assert(C.ready(j,{name=j.name,state={berries=true},tags={['computercraft:turtle_can_use']=true}}))
end)
for _,t in ipairs(tests) do
  local ok,err=pcall(t[2])
  if not ok then io.stderr:write('FAIL '..t[1]..'\n'..tostring(err)..'\n');os.exit(1) end
  passed=passed+1;print('PASS '..t[1])
end
print(('Passed %d tests'):format(passed))
