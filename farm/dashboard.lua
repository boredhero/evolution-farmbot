-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local C=require('farm.lib.crops')
local F=require('farm.lib.frame')
local D={};D.__index=D
function D.installedVersion()
  if not fs or not textutils then return 'unversioned' end
  local h=fs.open('farm/version.json','r');if not h then return 'unversioned' end
  local raw=h.readAll();h.close()
  local ok,data=pcall(textutils.unserializeJSON,raw)
  if ok and type(data)=='table' and type(data.version)=='string'
    and data.version:match('^%d+%.%d+%.%d+$') then return data.version end
  return 'unversioned'
end
local symbols={ready='R',growing='g',unknown='?',stale='?',debt='!',busy='*',unsupported='?',excluded='x'}
local cropColors={wheat='4',carrots='1',potatoes='c',beetroots='e',cabbages='5',onions='0',tomatoes='e',
  rice='0',rice_panicles='0',canola='4',coffee='c',flax='3',hemp='d',sage_crop='9',cotton_plant='0',
  blueberry_bush='b',sweet_berry_bush='a',inferium_crop='5',melon='5',pumpkin='1',cocoa='c',
  sugar_cane='d',bamboo='d',nether_wart='e',kelp='9',cactus='d'}
function D.cropColor(name)
  local bare=(name or ''):match(':(.+)$') or name or ''
  if cropColors[bare] then return cropColors[bare] end
  local palette={'2','3','4','5','6','9','a','b','d','1'};local hash=0
  for i=1,#bare do hash=(hash*31+bare:byte(i))%65521 end
  return palette[hash%#palette+1]
end
local function cropInk(bg) return (bg=='b' or bg=='c' or bg=='d' or bg=='a' or bg=='e') and '0' or 'f' end
local function count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
local function short(name) return (name or '?'):gsub('^mysticalagriculture:','MA:'):gsub('^minecraft:','MC:')
  :gsub('^farmersdelight:','FD:'):gsub('^actuallyadditions:','AA:'):gsub('^biomeswevegone:','BWG:')
  :gsub('^immersiveengineering:','IE:'):gsub('^hexerei:','Hex:') end
local function pad(text,width) return text:sub(1,width)..string.rep(' ',math.max(0,width-#text)) end
local function duration(s)
  s=math.max(0,math.floor(s or 0));return ('%dd %02dh %02dm'):format(math.floor(s/86400),math.floor(s/3600)%24,math.floor(s/60)%60)
end
function D.classify(p,h,m)
  if m.excluded[p.job.key] then return 'excluded' end
  if p.intent and p.intent.expires>m.now then return 'busy' end
  if p.debt then return 'debt' end
  if p.job.mode=='probe' then return 'unsupported' end
  if not h or not h.observed or h.observed.name~=p.job.name then return 'unknown' end
  if m.now-(h.observedAt or 0)>m.freshFor then return 'stale' end
  local ready,reason=C.ready(p.job,h.observed)
  if ready then return 'ready' end
  if reason=='growing' then return 'growing' end
  return 'unsupported'
end
function D.new(views) return setmetatable({views=views or {},frames={},hits={}},D) end
function D:view(name)
  if not self.views[name] then
    local hasMap=false;for _,v in pairs(self.views) do if v.role=='map' then hasMap=true end end
    self.views[name]={role=hasMap and 'stats' or 'map',zoom=2,cache=true,page=1}
  end
  return self.views[name]
end
local function button(f,hits,x,y,text,action,value)
  f:write(x,y,text,'0','b');hits[#hits+1]={x=x,y=y,w=#text,h=1,action=action,value=value}
  return x+#text+1
end
local function levels(m)
  local found={};for _,p in pairs(m.plots) do found[p.job.pos.y]=(found[p.job.pos.y] or 0)+1 end
  local rows={};for y,n in pairs(found) do rows[#rows+1]={y=y,n=n} end
  table.sort(rows,function(a,b)return a.y<b.y end);return rows
end
local function pickLayer(m,v)
  if v.layer then return v.layer end
  local best,n=m.center.y,0
  for _,r in ipairs(levels(m)) do if r.n>n then best,n=r.y,r.n end end
  return best
end
function D:render(m,v,w,h)
  local f=F.new(w,h);local hits={}
  local role=v.role or 'map'
  f:fill(1,1,w,2,' ','0','b')
  f:write(2,1,'FARMBOT / '..(role=='map' and 'TACTICAL MAP' or 'OPERATIONS'), '0','b')
  local health=m.active and 'RUNNING' or 'PAUSED'
  if m.scanAge<0 then health='WAITING FOR SURVEY'
  elseif m.scanAge>m.freshFor then health='SURVEY STALE' end
  f:write(math.max(28,w-#health-1),1,health,m.active and '5' or '4','b')
  f:write(2,2,'Scan '..(m.scanAge<0 and 'pending' or m.scanAge..'s old')..' | growth = last inspection','0','b')
  button(f,hits,3,4,'[TEXT -]','scale',-0.5);button(f,hits,12,4,'[TEXT +]','scale',0.5)
  if role=='stats' then
    local version=m.version and ('v'..m.version) or 'unversioned'
    f:write(math.max(22,w-#version-1),4,version,'0')
  end
  if w<50 or h<28 then
    f:write(2,6,'Use TEXT - for more room.','4')
    f:write(2,8,'Plots '..count(m.plots)..' | workers '..count(m.workers))
    f:write(2,10,'Lifetime harvests '..m.metrics.harvests)
    return f,hits
  end
  if role=='map' then
    local layer=pickLayer(m,v)
    local x=3
    x=button(f,hits,x,3,'[Y-]','layer',-1)
    x=button(f,hits,x,3,'[Y+]','layer',1)
    x=button(f,hits,x,3,'[AUTO]','auto')
    x=button(f,hits,x,3,'[Z-]','zoom',-1)
    x=button(f,hits,x,3,'[Z+]','zoom',1)
    button(f,hits,x,3,v.cache==false and '[CACHE OFF]' or '[CACHE ON]','cache')
    x=24;x=button(f,hits,x,4,'[N]','pan','n');x=button(f,hits,x,4,'[S]','pan','s')
    x=button(f,hits,x,4,'[W]','pan','w');button(f,hits,x,4,'[E]','pan','e')
    local span=math.max(9,math.ceil((m.radius*2+1)/(v.zoom or 1)))
    local cx,cz=v.cx or m.center.x,v.cz or m.center.z
    local minX,minZ=cx-math.floor(span/2),cz-math.floor(span/2)
    local mw,mh=math.min(w-4,span*2),math.min(h-14,span)
    local mx,my=math.floor((w-mw)/2)+1,7
    f:write(3,5,('CROP Y=%d | NORTH ^ | %dx zoom | %dx%d blocks'):format(layer,v.zoom or 1,span,span),'0')
    f:box(mx-1,my-1,mw+2,mh+2,'SURVEY / '..count(m.cache)..' CACHED ROUTES')
    local function point(p)
      if p.x<minX or p.z<minZ or p.x>=minX+span or p.z>=minZ+span then return end
      return mx+math.min(mw-1,math.floor((p.x-minX+0.5)*mw/span)),my+math.min(mh-1,math.floor((p.z-minZ+0.5)*mh/span))
    end
    for dy=0,mh-1 do for dx=0,mw-1 do
      local p={x=minX+math.floor(dx*span/mw),y=layer,z=minZ+math.floor(dy*span/mh)}
      local name=m.world:name(p);local ch,fg,bg=' ','8','f'
      if m.scanAge<0 or not m.world:inside(p) then ch='?';fg='7'
      elseif m.plots[U.key(p)] then ch=' '
      elseif name:find('water',1,true) then ch='~';fg='b'
      elseif m.world:name({x=p.x,y=p.y-1,z=p.z})=='minecraft:water' then ch='~';fg='b'
      elseif m.world:blocked(p) then ch=' ';bg='7'
      elseif C.farmland(m.world:name({x=p.x,y=p.y-1,z=p.z})) then ch='.';fg='c'
      elseif p.x%8==0 and p.z%8==0 then ch='+';fg='7' end
      f:write(mx+dx,my+dy,ch,fg,bg)
    end end
    local drawn=0
    if v.cache~=false then
      for _,route in pairs(m.cache) do
        for _,p in ipairs(route.path) do
          if drawn>=16000 then break end;drawn=drawn+1
          if p.y==layer or p.y==layer+1 then local px,py=point(p);if px then f:write(px,py,':','7') end end
        end
        if drawn>=16000 then break end
      end
    end
    local ids={};for id in pairs(m.workers) do ids[#ids+1]=id end;table.sort(ids)
    for _,id in ipairs(ids) do
      local worker=m.workers[id]
      if worker.route and m.now-worker.seen<30 then
        local from=1
        for i,p in ipairs(worker.route) do if U.equal(p,worker.pos) then from=i end end
        for i=from,#worker.route do local p=worker.route[i]
          if p.y==layer or p.y==layer+1 then local px,py=point(p);if px then f:write(px,py,'.','3') end end
        end
      end
    end
    local priorities={excluded=0,unknown=1,stale=1,growing=2,unsupported=3,ready=4,busy=5,debt=6}
    local occupied={}
    for k,p in pairs(m.plots) do if p.job.pos.y==layer then
      local px,py=point(p.job.pos)
      if px then
        local status=D.classify(p,m.history[k],m);local cell=px..','..py
        if not occupied[cell] or priorities[status]>=occupied[cell] then
          local bg=D.cropColor(p.job.name);local fg=cropInk(bg)
          if status=='debt' then bg='e';fg='0'
          elseif status=='busy' then bg='4';fg='f'
          elseif status=='excluded' then bg='7';fg='0' end
          f:write(px,py,symbols[status],fg,bg);occupied[cell]=priorities[status]
          hits[#hits+1]={x=px,y=py,w=1,h=1,action='select',value=k}
        end
      end
    end end
    local sx,sy=point(m.center)
    if sx and m.center.y==layer then f:write(sx,sy,'S','0','b') end
    for i,id in ipairs(ids) do
      local worker=m.workers[id];local p=worker.pos
      if p and (p.y==layer or p.y==layer+1) then
        local px,py=point(p)
        if px then f:write(px,py,tostring(i%10),m.now-worker.seen<30 and '0' or '8',i%2==1 and 'b' or 'a') end
      end
    end
    f:write(3,h-6,'COLOR = CROP TYPE | tap a tile for its name','0')
    f:write(3,h-5,'R ripe  g growing  ? unseen/stale  ! gap  * busy','0')
    local fleet={}
    for i,id in ipairs(ids) do
      local worker=m.workers[id]
      fleet[#fleet+1]=i..'=Turtle #'..id..' Y='..tostring(worker.pos and worker.pos.y or '?')
    end
    f:write(3,h-4,table.concat(fleet,'  |  '),'3')
    f:write(3,h-3,'Layers: '..table.concat((function() local a={};for _,r in ipairs(levels(m)) do a[#a+1]=r.y..' ('..r.n..')' end;return a end)(),' / '),'0')
    if v.selected and m.plots[v.selected] then
      local p=m.plots[v.selected];local history=m.history[v.selected]
      f:write(3,h-2,(short(p.job.name)..' ['..D.classify(p,history,m)..']'):sub(1,w-4),D.cropColor(p.job.name))
      local seen=history and history.observedAt and math.floor(m.now-history.observedAt)..'s ago' or 'never inspected'
      local age=history and history.observed and history.observed.state and history.observed.state.age
      f:write(3,h-1,('%s | %s%s'):format(v.selected,seen,age and ' | age '..age..'/'..tostring(p.job.age or '?') or ''),'0')
    else f:write(3,h-2,': cached route | . active route | Y-/Y+ floors','0') end
  else
    local metrics=m.metrics;local rows={};local live,gaps,ready,growing,unknown=0,0,0,0,0
    for k,p in pairs(m.plots) do
      local name=p.job.name;local row=rows[name] or {name=name,live=0,gaps=0,ready=0,growing=0,unknown=0}
      rows[name]=row
      if p.live then live=live+1;row.live=row.live+1 end
      if p.debt then gaps=gaps+1;row.gaps=row.gaps+1 end
      local s=D.classify(p,m.history[k],m)
      if s=='ready' then ready=ready+1;row.ready=row.ready+1
      elseif s=='growing' then growing=growing+1;row.growing=row.growing+1
      elseif s=='unknown' or s=='stale' or s=='unsupported' then unknown=unknown+1;row.unknown=row.unknown+1 end
    end
    for name in pairs(metrics.byCrop) do if not rows[name] then rows[name]={name=name,live=0,gaps=0,ready=0,growing=0,unknown=0} end end
    local x=3;x=button(f,hits,x,3,'[PREV CROPS]','page',-1);button(f,hits,x,3,'[NEXT CROPS]','page',1)
    local third=math.floor((w-5)/3)
    local cards={{'CONTROLLER UPTIME',duration(m.sessionUptime),'Recorded lifetime '..duration(metrics.uptime)},
      {'LIFETIME HARVESTS',tostring(metrics.harvests),'Replants '..metrics.replants..' | deferred '..metrics.deferred},
      {'CURRENT FARM',live..' living / '..gaps..' gaps',ready..' ready seen | '..unknown..' unknown/stale'}}
    if w>=100 then
      for i,c in ipairs(cards) do local xx=2+(i-1)*(third+1)
        f:box(xx,5,third,5,c[1]);f:write(xx+2,7,c[2]:sub(1,third-4),'5');f:write(xx+2,8,c[3]:sub(1,third-4),'0')
      end
    else
      f:write(3,6,'UPTIME '..duration(m.sessionUptime)..' | LIFE '..duration(metrics.uptime),'0')
      f:write(3,7,'LIFETIME HARVESTS '..metrics.harvests..' | REPLANTS '..metrics.replants,'5')
      f:write(3,8,'FARM '..live..' plants | '..gaps..' gaps | '..ready..' ripe seen','0')
      f:write(3,9,'UNSEEN/STALE '..unknown..' | DEFERRED '..metrics.deferred,'4')
    end
    f:write(3,11,('Scans %d | Errors %d | Routes %d / hits %d'):format(metrics.scans,metrics.errors,count(m.cache),m.cacheHits),'0')
    local ids={};for id in pairs(m.workers) do ids[#ids+1]=id end;table.sort(ids)
    local y=13
    f:write(3,y,'FLEET / POSITION / FUEL / CURRENT TASK','3');y=y+1
    for i,id in ipairs(ids) do if i<=4 then
      local worker=m.workers[id];local online=m.now-worker.seen<30
      f:write(3,y,('#%s %s  %s  fuel=%s  %s'):format(id,online and 'ONLINE ' or 'OFFLINE',worker.pos and U.key(worker.pos) or '?',tostring(worker.fuel or '?'),worker.status or ''):sub(1,w-5),online and '0' or '8');y=y+1
    end end
    if #ids==0 then f:write(3,y,'Waiting for paired workers...','0');y=y+1 end
    y=y+1
    local footer=h>=45 and 11 or 5
    local tableBottom=math.max(y+3,h-footer);local perPage=math.max(1,tableBottom-y-2)
    local sorted={};for _,row in pairs(rows) do sorted[#sorted+1]=row end
    table.sort(sorted,function(a,b) if a.live+a.gaps~=b.live+b.gaps then return a.live+a.gaps>b.live+b.gaps end;return a.name<b.name end)
    local pages=math.max(1,math.ceil(#sorted/perPage));v.page=math.max(1,math.min(v.page or 1,pages))
    f:write(3,y,('CROP COUNTS / %d TYPES / PAGE %d OF %d'):format(#sorted,v.page,pages),'3');y=y+1
    local nameWidth=w-35
    f:write(3,y,pad('CROP',nameWidth)..' LIVE GAP RIPE GROW    ?    HV','0','b');y=y+1
    for i=(v.page-1)*perPage+1,math.min(v.page*perPage,#sorted) do
      local row=sorted[i];local lifetime=metrics.byCrop[row.name]
      f:write(3,y,pad(short(row.name),nameWidth),D.cropColor(row.name))
      f:write(3+nameWidth,y,string.format(' %4d %3d %4d %4d %4d %5d',row.live,row.gaps,row.ready,row.growing,row.unknown,lifetime and lifetime.harvests or 0),row.gaps>0 and 'e' or '0');y=y+1
    end
    f:write(3,h-footer+2,'RECENT ACTIVITY / harvest actions','3')
    local events=metrics.events
    for i=0,(h>=45 and 4 or 0) do local event=events[#events-i];if event then
      f:write(3,h-footer+3+i,(math.floor(m.now-event.time)..'s  '..event.outcome..'  '..short(event.name)..(event.detail and ' | '..event.detail or '')):sub(1,w-5),event.outcome=='deferred' and 'e' or '0')
    end end
    f:write(3,h-1,'? = unseen/stale | HV = lifetime harvest actions','0')
  end
  if m.scanError then f:write(3,h,('SCANNER: '..m.scanError):sub(1,w-5),'e') end
  return f,hits
end
function D:draw(mon,name,m)
  local v=self:view(name);local scale=v.scale or 1
  if mon.getTextScale()~=scale then mon.setTextScale(scale);self.frames[name]=nil end
  -- A quieter terrain shade; crop tiles and white labels remain prominent.
  if mon.setPaletteColor then mon.setPaletteColor(2^7,0.12,0.14,0.17) end
  local w,h=mon.getSize();local frame,hits=self:render(m,v,w,h)
  self.frames[name]=frame:flush(mon,self.frames[name]);self.hits[name]=hits
end
function D:touch(name,x,y,m)
  local v=self:view(name)
  local hits=self.hits[name] or {}
  for i=#hits,1,-1 do local hit=hits[i]
    if x>=hit.x and x<hit.x+hit.w and y>=hit.y and y<hit.y+hit.h then
      local action=hit.action
      if action=='select' then v.selected=hit.value
      elseif action=='page' then v.page=math.max(1,(v.page or 1)+hit.value)
      elseif action=='cache' then v.cache=v.cache==false
      elseif action=='scale' then v.scale=math.max(0.5,math.min(2,(v.scale or 1)+hit.value))
      elseif action=='auto' then v.layer=nil;v.cx=nil;v.cz=nil;v.zoom=1
      elseif action=='zoom' then v.zoom=math.max(1,math.min(4,(v.zoom or 1)+hit.value))
      elseif action=='layer' then
        local options=levels(m);local current=pickLayer(m,v);local at=1
        for j,r in ipairs(options) do if r.y<=current then at=j end end
        if #options>0 then v.layer=options[((at-1+hit.value)%#options)+1].y end
      elseif action=='pan' then
        local delta=math.max(1,math.floor(m.radius/(v.zoom or 1)/3));v.cx=v.cx or m.center.x;v.cz=v.cz or m.center.z
        if hit.value=='n' then v.cz=v.cz-delta elseif hit.value=='s' then v.cz=v.cz+delta
        elseif hit.value=='w' then v.cx=v.cx-delta else v.cx=v.cx+delta end
      end
      self.frames[name]=nil;return true
    end
  end
  return false
end
return D
