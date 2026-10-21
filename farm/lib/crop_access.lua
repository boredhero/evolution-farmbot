-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local C=require('farm.lib.crops')
local A={}
function A.candidates(base,world,plots,batches,leases,excluded)
  local found={}
  if base.mode~='replant' or base.repair or base.half or not base.seed then return found end
  for i=1,4 do
    local key=U.key(U.add(base.pos,U.dirs[i]));local p=plots[key];local j=p and p.job
    if j and p.live and not p.intent and not leases[key] and not excluded[key]
      and j.mode=='replant' and not j.half and j.seed==base.seed
      and (j.crop or j.name)==(base.crop or base.name)
      and batches.pending[key]==(j.crop or j.name) and not batches.visited[j.roundKey or key] then
      local blocked=true
      for _,g in ipairs(C.goals(j)) do
        if not U.equal(g,base.pos) and not world:blocked(g) then blocked=false;break end
      end
      if blocked then local copy={};for k,v in pairs(j) do copy[k]=v end;copy.version=p.version;found[#found+1]=copy end
    end
  end
  return found
end
return A
