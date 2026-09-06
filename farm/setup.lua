-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local S=require('farm.lib.store')
local N=require('farm.lib.network')
local Setup={}
local function input(prompt,default)
  write(prompt..(default and ' ['..tostring(default)..']' or '')..': ')
  local value=read();if value=='' then return default end;return value
end
local function number(prompt,default)
  while true do local n=tonumber(input(prompt,default));if n and n%1==0 then return n end;print('Enter a whole number.') end
end
local function position(prompt)
  print(prompt..' (use F3 Targeted Block coordinates, not player feet)')
  return {x=number('X'),y=number('Y'),z=number('Z')}
end
-- Finds the controller instead of asking the operator to retype its farm name.
-- A mistyped name is invisible rather than wrong: the name is baked into the
-- rednet protocol, so the pair simply never hear each other.
function Setup.pair(cfg)
  print('Searching for a running FarmBot controller...')
  local ok,found=pcall(N.discover,3)
  found=ok and found or {}
  if #found==1 then
    cfg.controller,cfg.group=found[1].controller,found[1].group
    print('Paired with controller #'..cfg.controller..' on farm network "'..cfg.group..'".')
    return
  end
  if #found>1 then
    print('More than one controller answered:')
    for _,c in ipairs(found) do print('  #'..c.controller..'  network "'..c.group..'"') end
    cfg.controller=number('Which controller computer ID')
    for _,c in ipairs(found) do if c.controller==cfg.controller then cfg.group=c.group end end
    if cfg.group then print('Using farm network "'..cfg.group..'".');return end
    print('That controller did not answer; entering the name by hand.')
  else
    print('No controller answered. Start it with farm start, check both Ender Modems,')
    print('then rerun farm setup worker. Entering details by hand for now.')
  end
  cfg.group=input('Farm network name (must match the controller exactly)',cfg.group or 'noah-farm')
  cfg.controller=cfg.controller or number('Controller computer ID')
end
function Setup.run(role)
  print('Evolution FarmBot setup - computer ID '..os.getComputerID())
  role=role or input('Role: controller, worker, gps',turtle and 'worker' or 'controller')
  assert(role=='controller' or role=='worker' or role=='gps','Unknown role')
  U.openModem()
  local cfg={role=role,group='noah-farm',version=1}
  if role=='gps' then
    cfg.pos=position('Coordinates of THIS GPS COMPUTER block')
  elseif role=='controller' then
    cfg.group=input('Farm network name','noah-farm')
    assert(peripheral.find('geo_scanner') or peripheral.find('geoScanner'),'Attach your Geo Scanner before setup')
    cfg.center=position('Coordinates of the GEO SCANNER block')
    cfg.radius=32;cfg.scanInterval=120;cfg.allowed={};cfg.customCrops={}
    print('Seed inventories visible over the wired network:')
    for _,name in ipairs(peripheral.getNames()) do if peripheral.hasType(name,'inventory') then print(name) end end
    cfg.seedSource=input('Shared automatic seed BANK inventory name (blank to add later)','')
    print('No seed list or initial stock required. Harvested seeds replenish this bank.')
    local ids=input('Worker computer IDs, separated by spaces (can add later)','')
    for id in ids:gmatch('%d+') do cfg.allowed[tostring(tonumber(id))]=true end
    print('Coverage: 32 blocks in each direction from the scanner. Starts paused.')
    print('Farm network name is "'..cfg.group..'". Workers discover it automatically.')
  else
    assert(turtle,'Worker requires a turtle')
    Setup.pair(cfg)
    local tool=false
    if turtle.getEquippedLeft and turtle.getEquippedRight then
      local l,r=turtle.getEquippedLeft(),turtle.getEquippedRight()
      tool=(l and l.name=='minecraft:diamond_pickaxe') or (r and r.name=='minecraft:diamond_pickaxe')
    end
    -- Older CC builds may not expose equipped-item detail. The installer guide covers this.
    if not tool then print('Ensure this is a Mining Turtle (diamond pickaxe) with an Ender Modem.') end
    print('Give the coordinates of the chests this turtle should use. Use F3')
    print('Targeted Block coordinates. They can be anywhere it can walk to.')
    print('Put coal/charcoal in the turtle. Leave an empty horizontal neighbor.')
    input('Press Enter when ready','')
    require('farm.worker').refuel()
    cfg.stations={output=position('Chest/ME interface to PUT harvested items into')}
    if input('Is there a separate chest to TAKE fuel from? yes/no','yes')~='no' then
      cfg.stations.fuel=position('Chest to TAKE coal/charcoal from')
    end
    print('Output at '..U.key(cfg.stations.output)..
      (cfg.stations.fuel and ', fuel at '..U.key(cfg.stations.fuel) or ', no fuel chest'))
    local seedFound,seed=turtle.inspectDown()
    local function chest(name) return name=='minecraft:chest' or name=='minecraft:barrel' or name=='minecraft:trapped_chest' end
    if seedFound and chest(seed.name) then cfg.seedBlock=seed.name end
    cfg.seedBuffer=input('Wired inventory name of seed delivery chest BELOW (blank for dry run)','')
    if cfg.seedBuffer~='' then assert(cfg.seedBlock,'Place a vanilla seed-delivery chest/barrel below this turtle') end
    cfg.dock,cfg.dockHeading=require('farm.worker').calibrate()
    cfg.fuelReserve=256
    cfg.dryRun=input('Start in inspection-only mode? yes/no','yes')~='no'
    print('Parking cell recorded at '..U.key(cfg.dock)..'. Chests are visited, not attached.')
  end
  os.setComputerLabel('FarmBot-'..role..'-'..os.getComputerID())
  S.save('farm/config',cfg)
  print('Setup saved. Run farm start to launch. Startup will also launch on reboot.')
end
return Setup
