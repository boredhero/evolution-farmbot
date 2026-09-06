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
    print('Dock: output chest in front, fuel ABOVE, seed-delivery chest BELOW.')
    print('Put coal/charcoal in the turtle. Leave an empty horizontal neighbor for calibration.')
    input('Press Enter when ready','')
    require('farm.worker').refuel()
    local found,output=turtle.inspect();assert(found,'No output inventory in front')
    local fuelFound,fuel=turtle.inspectUp();assert(fuelFound,'No fuel chest above turtle')
    local function chest(name) return name=='minecraft:chest' or name=='minecraft:barrel' or name=='minecraft:trapped_chest' end
    -- Prove the output target takes items rather than trusting its block name.
    -- A chest with an ME Import Bus, an ME interface, a drawer or a modded
    -- barrel all pass; a wall or a decorative block does not.
    if not chest(output.name) then
      local accepted
      for slot=1,16 do
        if turtle.getItemCount(slot)>0 then
          turtle.select(slot)
          accepted=turtle.drop(1)
          -- Comes straight back, unless an import bus already ingested it.
          if accepted then turtle.suck(1) end
          break
        end
      end
      if accepted==false then
        error('The block in front ('..output.name..') would not take a test item. '..
          'Use a chest, barrel or ME interface as the output target.',0)
      elseif accepted==nil then
        print('Turtle is empty, so '..output.name..' could not be tested. Accepting it.')
      else
        print('Output target '..output.name..' accepted a test item.')
      end
    end
    assert(chest(fuel.name),'Use a vanilla chest/barrel above the turtle for fuel')
    cfg.outputBlock=output.name;cfg.fuelBlock=fuel.name
    local seedFound,seed=turtle.inspectDown()
    if seedFound and chest(seed.name) then cfg.seedBlock=seed.name end
    cfg.seedBuffer=input('Wired inventory name of seed delivery chest BELOW (blank for dry run)','')
    if cfg.seedBuffer~='' then assert(cfg.seedBlock,'Place a vanilla seed-delivery chest/barrel below this turtle') end
    cfg.dock,cfg.dockHeading=require('farm.worker').calibrate()
    cfg.fuelReserve=256
    cfg.dryRun=input('Start in inspection-only mode? yes/no','yes')~='no'
    print('Dock recorded at '..U.key(cfg.dock))
  end
  os.setComputerLabel('FarmBot-'..role..'-'..os.getComputerID())
  S.save('farm/config',cfg)
  print('Setup saved. Run farm start to launch. Startup will also launch on reboot.')
end
return Setup
