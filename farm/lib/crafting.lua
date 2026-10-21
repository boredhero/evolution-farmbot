-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- One verified ingredient in an otherwise empty vanilla Crafter, output into turtle.
local M={}
local function count(name)
  local n=0;for i=1,16 do local d=turtle.getItemDetail(i);if d and d.name==name then n=n+d.count end end
  return n
end
function M.run(side,seed,recipe,journal,save)
  local inv=peripheral.wrap(side)
  if not inv or type(inv.list)~='function' then return false,'Crafter inventory is not accessible' end
  local items=inv.list()
  if not journal.loaded then
    if next(items) then return false,'Crafter must be empty' end
    if redstone.getOutput(side) then return false,'Crafter control side already powered' end
    local source,room
    for i=1,16 do
      local d=turtle.getItemDetail(i)
      if d and d.name==recipe.item then source=i end
      if not d or (d.name==seed and turtle.getItemSpace(i)>=recipe.count) then room=true end
    end
    if not source then return false,'Missing crafting ingredient: '..recipe.item end
    if not room then return false,'No room for crafted seeds' end
    -- Mark before insertion. Recovery checks the machine before inserting again.
    journal.loaded=true;journal.before=count(seed);journal.ingredientBefore=count(recipe.item);save()
    turtle.select(source)
    local drop=side=='top' and turtle.dropUp or side=='bottom' and turtle.dropDown or turtle.drop
    if not drop(1) then journal.loaded=false;save();return false,'Could not insert seed ingredient' end
    items=inv.list()
  end
  local n=0
  for _,item in pairs(items) do
    if item.name~=recipe.item then return false,'Crafter contains an unexpected item; leaving it untouched' end
    n=n+item.count
  end
  if n==0 then
    if count(seed)>=(journal.before or 0)+recipe.count then return true end
    if journal.ingredientBefore and count(recipe.item)==journal.ingredientBefore then
      journal.loaded=false;save();return false,'Ingredient was not inserted; retrying safely'
    end
    return false,'Craft output missing; check Crafter and its output face'
  end
  if n~=1 then return false,'Crafter has more than the reserved ingredient; leaving it untouched' end
  local ok,err=pcall(function()
    redstone.setOutput(side,false);sleep(0.1)
    redstone.setOutput(side,true);sleep(0.2)
    redstone.setOutput(side,false);sleep(0.6)
  end)
  redstone.setOutput(side,false)
  if not ok then error(err,0) end
  if count(seed)>=(journal.before or 0)+recipe.count and not next(inv.list()) then return true end
  return false,'Seed craft did not complete; check recipe and Crafter'
end
return M
