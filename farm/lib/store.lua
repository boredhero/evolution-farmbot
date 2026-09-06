-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local S={}
local function read(path)
  if not fs.exists(path) then return nil end
  local h=fs.open(path,'r'); if not h then return nil end
  local raw=h.readAll(); h.close()
  return textutils.unserialize(raw)
end
function S.load(path,default)
  local ok,data=pcall(read,path)
  if ok and type(data)=='table' then return data end
  ok,data=pcall(read,path..'.bak')
  if ok and type(data)=='table' then return data end
  return default
end
function S.save(path,data)
  fs.makeDir(fs.getDir(path))
  local raw=textutils.serialize(data,{compact=true})
  local h,err=fs.open(path..'.new','w'); assert(h,err)
  h.write(raw); h.close()
  if fs.exists(path..'.bak') then fs.delete(path..'.bak') end
  if fs.exists(path) then fs.move(path,path..'.bak') end
  fs.move(path..'.new',path)
end
return S
