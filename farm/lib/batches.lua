-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- One crop per exclusive worker-owned round; one shared fleet cycle covers every type.
local B={}
local function crop(job) return job.crop or job.name end
local function init(s)
  s.deferred=s.deferred or {}
  s.pending=s.pending or {};s.workers=s.workers or {};s.visited=s.visited or {}
  s.owners=s.owners or {};s.finished=s.finished or {};s.inflight=s.inflight or {};s.groups=s.groups or {};s.repairs=s.repairs or {}
end
function B.order(state,all,options,id,now)
  init(state);id=tostring(id);now=now or 0
  local available={}
  for _,o in ipairs(all) do if not o.job.repair then available[o.job.key]=o end end
  for key in pairs(state.pending) do
    if not available[key] and not state.inflight[key] then state.pending[key]=nil end
  end
  -- Admit new locations of an unfinished crop, but never reopen a completed type.
  for key,o in pairs(available) do
    local name=crop(o.job)
    if not state.visited[o.job.roundKey or key] and not state.finished[name] then state.pending[key]=name end
  end
  for name,owner in pairs(state.owners) do
    local pending=false
    for _,crop in pairs(state.pending) do if crop==name then pending=true;break end end
    for _,r in pairs(state.repairs) do if r.name==name then pending=true end end
    if not pending then
      state.finished[name]=true;state.owners[name]=nil
      if state.workers[owner]==name then state.workers[owner]=nil end
    end
  end
  local unparked=false;local restartable=false
  for _,name in pairs(state.pending) do if not state.deferred[name] then unparked=true end end
  for _,o in pairs(available) do if not state.deferred[crop(o.job)] then restartable=true end end
  if not unparked and not next(state.inflight) and restartable then
    local visited={}
    for key,o in pairs(available) do local rk=o.job.roundKey or key
      if state.deferred[crop(o.job)] and state.visited[rk] then visited[rk]=true end
    end
    state.cycle=(state.cycle or 0)+1;state.visited=visited;state.finished={};state.workers={};state.owners={}
    for key,o in pairs(available) do
      if not state.visited[o.job.roundKey or key] then state.pending[key]=crop(o.job) end
    end
  elseif not state.cycle and next(state.pending) then state.cycle=1 end
  state.groups={}
  for key,name in pairs(state.pending) do
    local g=state.groups[name] or {count=0,ready=0};state.groups[name]=g;g.count=g.count+1
    if available[key] and available[key].ready then g.ready=g.ready+1 end
  end
  local current=state.workers[id];local ordered={}
  for _,o in ipairs(options) do
    local j=o.job;local owner=state.owners[crop(j)]
    local deferred=state.deferred[crop(j)]
    if (not deferred or deferred<=now) and (not owner or owner==id) and (not current or crop(j)==current or j.repair) then
      if j.repair or (state.pending[j.key]==crop(j) and not state.inflight[j.key]) then ordered[#ordered+1]=o end
    end
  end
  table.sort(ordered,function(a,b)
    local ar,br=a.job.repair==true,b.job.repair==true
    if ar~=br then return ar end
    if not ar and crop(a.job)~=crop(b.job) then
      local ad,bd=state.deferred[crop(a.job)],state.deferred[crop(b.job)]
      if ad and not bd then return true elseif bd and not ad then return false end
      local ag,bg=state.groups[crop(a.job)],state.groups[crop(b.job)]
      if ag.ready~=bg.ready then return ag.ready>bg.ready end
      if ag.count~=bg.count then return ag.count>bg.count end
      return crop(a.job)<crop(b.job)
    end
    if a.score~=b.score then return a.score<b.score end
    return a.job.key<b.job.key
  end)
  return ordered
end
function B.assigned(state,id,job)
  init(state);id=tostring(id)
  state.deferred[crop(job)]=nil
  assert(not state.owners[crop(job)] or state.owners[crop(job)]==id,'Crop round already owned')
  if job.repair then state.repairs[job.key]={name=crop(job),owner=id};state.owners[crop(job)]=id end
  if not job.repair then
    if not state.owners[crop(job)] then state.round=(state.round or 0)+1 end
    state.owners[crop(job)]=id;state.workers[id]=crop(job)
  end
  state.inflight[job.key]=id
end
function B.finished(state,id,job)
  init(state);state.inflight[job.key]=nil;state.repairs[job.key]=nil
  if not job.repair then state.pending[job.key]=nil;state.visited[job.roundKey or job.key]=true end
end
function B.release(state,id)
  init(state);id=tostring(id)
  for key,owner in pairs(state.inflight) do if owner==id then state.inflight[key]=nil;state.repairs[key]=nil end end
end
-- Park only after the owner has no assignable work, never during travel/unload.
function B.park(state,id,untilTime)
  init(state);id=tostring(id)
  for _,owner in pairs(state.inflight) do if owner==id then return false end end
  local name=state.workers[id]
  if not name then return false end
  state.deferred[name]=untilTime;state.owners[name]=nil;state.workers[id]=nil
  return true
end
function B.skip(state,key)
  init(state);state.pending[key]=nil;state.inflight[key]=nil;state.visited[key]=true
end
return B
