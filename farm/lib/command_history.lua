-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local S=require('farm.lib.store')
local H={};H.__index=H
local PATH='farm/data/commands'
local LIMIT=20
local function append(entries,line)
  if type(line)~='string' then return false end
  line=line:match('^%s*(.-)%s*$')
  if line=='' or #line>512 or line:find('[\r\n]') or entries[#entries]==line then return false end
  entries[#entries+1]=line
  if #entries>LIMIT then table.remove(entries,1) end
  return true
end
function H.new()
  local saved=S.load(PATH,{})
  local entries={}
  if type(saved)=='table' then
    for _,line in ipairs(saved) do append(entries,line) end
  end
  return setmetatable({entries=entries},H)
end
function H:read()
  -- CraftOS handles Up/Down recall and editing when read receives a history list.
  local line=read(nil,self.entries)
  if append(self.entries,line) then S.save(PATH,self.entries) end
  return line
end
return H
