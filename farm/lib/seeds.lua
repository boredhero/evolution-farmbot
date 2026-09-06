-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- Controller-side, wired inventory transfer. Never takes arbitrary item requests:
-- caller supplies the item from the worker's current leased crop rule.
local Seeds={}
function Seeds.stock(sourceName)
  local stock={}
  if not sourceName or sourceName=='' then return stock end
  local source=peripheral.wrap(sourceName)
  if not source or not source.list then return stock end
  for _,item in pairs(source.list()) do stock[item.name]=(stock[item.name] or 0)+item.count end
  return stock
end
function Seeds.store(sourceName,bufferName)
  if not sourceName or sourceName=='' or not bufferName or bufferName=='' then return nil,'Seed bank not connected' end
  if sourceName==bufferName then return nil,'Seed bank and dock buffer must differ' end
  local source,buffer=peripheral.wrap(sourceName),peripheral.wrap(bufferName)
  if not source or not buffer or not buffer.list or not buffer.pushItems then return nil,'Seed bank unavailable' end
  for slot,item in pairs(buffer.list()) do
    if buffer.pushItems(sourceName,slot,item.count)<item.count then return nil,'Seed bank full: add storage capacity' end
  end
  return {ok=true}
end
function Seeds.deliver(sourceName,bufferName,itemName)
  if not sourceName or sourceName=='' or not bufferName or bufferName=='' then
    return nil,'Configure the seed source and this worker seed-buffer inventory first'
  end
  if sourceName==bufferName then return nil,'Seed source and delivery buffer must be different inventories' end
  local source,buffer=peripheral.wrap(sourceName),peripheral.wrap(bufferName)
  if not source or not source.list or not source.pushItems or not buffer or not buffer.list or not buffer.pushItems then
    return nil,'Seed inventories unavailable: check enabled wired modems and cable'
  end
  -- A previous interrupted delivery remains reusable. Return other items first.
  for slot,item in pairs(buffer.list()) do
    if item.name~=itemName then
      if buffer.pushItems(sourceName,slot,item.count)<item.count then return nil,'Seed source has no space for leftover buffer items' end
    end
  end
  local available=0
  for _,item in pairs(buffer.list()) do if item.name==itemName then available=available+item.count end end
  if available>0 then return {count=available} end
  for slot,item in pairs(source.list()) do
    if item.name==itemName then
      local count=source.pushItems(bufferName,slot,math.min(4,item.count))
      if count>0 then return {count=count} end
    end
  end
  return nil,'Seed supply empty: '..itemName..'. Crop left intact.'
end
return Seeds
