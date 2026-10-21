-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- Nine identical inputs, all Crafter slots enabled; one verified output per pulse.
local M={}
local function count(name)
  local n=0;for i=1,16 do local d=turtle.getItemDetail(i);if d and d.name==name then n=n+d.count end end;return n
end
function M.run(side,output,recipe,journal,save)
  local inv=peripheral.wrap(side)
  if not inv or type(inv.list)~='function' then return false,'Crafter inventory is not accessible' end
  local drop=side=='top' and turtle.dropUp or side=='bottom' and turtle.dropDown or turtle.drop
  local suck=side=='top' and turtle.suckUp or side=='bottom' and turtle.suckDown or turtle.suck
  local function contents()
    local items=inv.list();local n=0
    for _,d in pairs(items) do if d.name~=recipe.item then return nil,items end;n=n+d.count end
    return n,items
  end
  if not journal.loaded then
    if next(inv.list()) then return false,'Crafter must be empty' end
    if redstone.getOutput(side) then return false,'Crafter control side already powered' end
    if count(recipe.item)<9 then return false,'Not enough compacting ingredients' end
    local room=false
    for i=1,16 do local d=turtle.getItemDetail(i);if not d or (d.name==output and turtle.getItemSpace(i)>0) then room=true end end
    if not room then return false,'No room for compacted output' end
    journal.loaded=true;journal.before=count(output);journal.ingredientBefore=count(recipe.item);save()
  end
  local n,items=contents()
  if n==0 and count(output)==journal.before+1 then return true end
  if not n or n>9 or count(recipe.item)+n~=journal.ingredientBefore or count(output)~=journal.before then
    return false,'Compacting inventory changed; preserving recovery journal'
  end
  local function rollback(reason)
    local amount=contents()
    if amount and count(recipe.item)+amount==journal.ingredientBefore and count(output)==journal.before then
      for _=1,9 do
        if amount==0 then journal.loaded=false;save();return false,reason end
        -- Reuse the ingredient slot where possible; otherwise an empty slot.
        for i=1,16 do local d=turtle.getItemDetail(i);if not d or (d.name==recipe.item and turtle.getItemSpace(i)>0) then turtle.select(i);break end end
        if not suck(amount) then break end
        amount=contents();if not amount then break end
      end
      if amount==0 and count(recipe.item)==journal.ingredientBefore then journal.loaded=false;save() end
    end
    return false,reason
  end
  while n<9 do
    local source
    for i=1,16 do local d=turtle.getItemDetail(i);if d and d.name==recipe.item then source=i;break end end
    if not source then return rollback('Missing compacting input') end
    turtle.select(source)
    if not drop(1) then return rollback('Crafter refused input; enable all nine slots') end
    local nextCount;nextCount,items=contents()
    if nextCount~=n+1 then return false,'Crafter input changed; preserving recovery journal' end
    n=nextCount
  end
  for slot=1,9 do if not items[slot] or items[slot].count~=1 then return rollback('Compacting needs all nine Crafter slots enabled') end end
  local ok,err=pcall(function()
    redstone.setOutput(side,false);sleep(0.1);redstone.setOutput(side,true);sleep(0.2)
    redstone.setOutput(side,false);sleep(0.6)
  end)
  redstone.setOutput(side,false)
  if not ok then error(err,0) end
  if count(output)==journal.before+1 and not next(inv.list()) then return true end
  return rollback('Compacting did not complete; check recipe and Crafter output face')
end
return M
