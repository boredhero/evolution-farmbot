-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- Small atomic mutation records between full snapshots; retain the records needed by the backup snapshot.
local S=require('farm.lib.store')
local U=require('farm.lib.util')
local J={};J.__index=J
function J.apply(state,r)
  if type(r)~='table' or type(r.seq)~='number' or r.seq<=(state.journalSeq or 0) then return end
  state.garden=state.garden or {plots={}};state.garden.plots=state.garden.plots or {};state.history=state.history or {}
  for _,key in ipairs({'batches','metrics','growth'}) do state[key]=r[key] end
  state.garden.seeds=r.seeds;state.garden.serial=r.serial
  if r.key then state.garden.plots[r.key]=r.plot or nil;state.history[r.key]=r.history or nil end
  state.journalSeq=r.seq
end
function J.new(path,state)
  local self=setmetatable({path=path,dir=path..'-journal',state=state,checkpointSeq=state.journalSeq or 0},J)
  if fs.exists(self.dir) then
    local files={};for _,name in ipairs(fs.list(self.dir)) do if name:match('^%d+$') then files[#files+1]=tonumber(name) end end
    table.sort(files)
    for _,seq in ipairs(files) do if seq>(state.journalSeq or 0) then
      local r=S.load(self.dir..'/'..seq,nil);assert(r and r.seq==seq,'Invalid controller journal record '..seq)
      J.apply(state,r)
    end end
  end
  return self
end
function J:locked(fn)
  while self.busy do os.pullEvent('farmbot_journal_unlock') end
  self.busy=true;local ok,err=pcall(fn);self.busy=false;os.queueEvent('farmbot_journal_unlock')
  if not ok then error(err,0) end
end
function J:record(job)
  self:locked(function()
    local s=self.state;local key=job and job.key;local seq=(s.journalSeq or 0)+1
    S.save(self.dir..'/'..seq,{seq=seq,batches=s.batches,metrics=s.metrics,growth=s.growth,
      serial=s.garden.serial,seeds=s.garden.seeds,key=key,
      plot=key and s.garden.plots[key] or false,history=key and s.history[key] or false})
    s.journalSeq=seq
  end)
end
function J:checkpoint()
  self:locked(function()
    S.save(self.path,self.state)
    if fs.exists(self.dir) then for _,name in ipairs(fs.list(self.dir)) do
      local seq=tonumber(name:match('^(%d+)'))
      if seq and seq<=self.checkpointSeq then fs.delete(self.dir..'/'..name) end
    end end
    self.checkpointSeq=self.state.journalSeq or 0
  end)
end
return J
