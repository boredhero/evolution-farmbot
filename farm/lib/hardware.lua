-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- Reports what the controller can actually see, so a missing wired modem ring
-- or an unshared peripheral is visible without reading the source.
local Hardware={}
-- Geo Scanner reports two different type names depending on the pack build.
local SCANNER={'geo_scanner','geoScanner'}
local function safe(fn,...)
  local ok,value=pcall(fn,...)
  if ok then return value end
end
function Hardware.survey(env)
  local names=safe(env.getNames) or {}
  table.sort(names)
  local found={monitors={},inventories={},wired={},wireless={},scanner=nil,player=nil,environment=nil,other={}}
  for _,name in ipairs(names) do
    local function is(kind) return safe(env.hasType,name,kind)==true end
    local claimed=false
    for _,kind in ipairs(SCANNER) do
      if is(kind) then found.scanner=found.scanner or name;claimed=true end
    end
    if is('player_detector') then found.player=found.player or name;claimed=true end
    if is('environment_detector') then found.environment=found.environment or name;claimed=true end
    if is('monitor') then found.monitors[#found.monitors+1]=name;claimed=true end
    if is('inventory') then found.inventories[#found.inventories+1]=name;claimed=true end
    if is('modem') then
      claimed=true
      local list=safe(env.call,name,'isWireless') and found.wireless or found.wired
      list[#list+1]=name
    end
    if not claimed then found.other[#found.other+1]=name end
  end
  return found
end
local function list(items,empty)
  if #items==0 then return empty end
  if #items==1 then return items[1] end
  return #items..': '..table.concat(items,', ')
end
-- context supplies what only the running controller knows: monitor roles, the
-- dimension read from the Environment Detector, and current player count.
function Hardware.lines(env,context)
  context=context or {}
  local f=Hardware.survey(env)
  local out={'HARDWARE / what this controller can see'}
  local function add(label,value,note)
    out[#out+1]=label..': '..value..(note and ('  -- '..note) or '')
  end
  -- `present and nil or hint` would always yield the hint, so branch explicitly.
  local function note(present,hint) if not present then return hint end end
  add('Geo Scanner',f.scanner or 'MISSING',note(f.scanner,'required; must touch the controller'))
  add('Ender/wireless modem',list(f.wireless,'MISSING'),note(#f.wireless>0,'required for GPS and workers'))
  add('Wired modems',list(f.wired,'none'),note(#f.wired>0,'right-click each modem so its ring lights up'))
  local roles={}
  for _,name in ipairs(f.monitors) do
    roles[#roles+1]=name..(context.monitorRole and ('='..tostring(context.monitorRole(name))) or '')
  end
  add('Monitors',list(roles,'none'))
  add('Inventories',list(f.inventories,'none'))
  local seen=context.players
  add('Player Detector',f.player or 'not attached',
    f.player and (seen and (seen..(seen==1 and ' player' or ' players')..' in range') or nil)
      or note(f.player,'optional; enables the map player overlay'))
  add('Environment Detector',f.environment or 'not attached',
    f.environment and (context.dimension or 'dimension not read yet')
      or note(f.environment,'optional; filters players in other dimensions'))
  if #f.other>0 then add('Other peripherals',table.concat(f.other,', ')) end
  if context.gps then add('GPS position',context.gps) end
  if context.version then add('Installed version','v'..context.version) end
  if context.workers then add('Paired workers',context.workers) end
  return out
end
return Hardware
