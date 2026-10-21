-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local T={}
function T.turtle(name) return name=='computercraft:turtle_normal' or name=='computercraft:turtle_advanced' end
function T.update(worker,pos,now)
  worker.pos=pos
  if worker.nextPos and (U.equal(pos,worker.nextPos) or (worker.nextUntil or 0)<=now) then worker.nextPos=nil end
end
function T.claim(workers,id,pos,target,now)
  if not pos or not target or U.distance(pos,target)~=1 then return {ok=false,reason='Invalid traffic step'} end
  for other,w in pairs(workers) do if other~=id and now-(w.seen or 0)<10 then
    if (w.pos and U.equal(w.pos,target)) or (w.nextPos and (w.nextUntil or 0)>now and U.equal(w.nextPos,target)) then
      return {ok=false,worker=other,reason='Waiting for worker #'..other}
    end
  end end
  local w=workers[id];w.nextPos=U.copy(target);w.nextUntil=now+3
  return {ok=true}
end
function T.avoid(workers,id,now,planned)
  local avoid={}
  for other,w in pairs(workers) do if other~=id then
    if w.dock then avoid[U.key(w.dock)]=true end
    if now-(w.seen or 0)<10 then
      if w.pos then avoid[U.key(w.pos)]=true end
      if w.nextPos and (w.nextUntil or 0)>now then avoid[U.key(w.nextPos)]=true end
      if planned and w.route and w.pos then
        local at=w.routeStart and U.equal(w.routeStart,w.pos) and 0 or nil
        for i,p in ipairs(w.route) do if U.equal(p,w.pos) then at=i end end
        if at then for i=at+1,math.min(at+3,#w.route) do avoid[U.key(w.route[i])]=true end end
      end
    end
  end end
  return avoid
end
return T
