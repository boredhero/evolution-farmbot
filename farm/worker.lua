-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local S=require('farm.lib.store')
local C=require('farm.lib.crops')
local N=require('farm.lib.network')
local SeedRecipes=require('farm.lib.seed_recipes')
local Crafting=require('farm.lib.crafting')
local Compost=require('farm.lib.compost')
local Pickup=require('farm.lib.pickup')
local Soil=require('farm.lib.soil')
local Vines=require('farm.lib.vines')
local Traffic=require('farm.lib.traffic')
local Fuel=require('farm.lib.fuel')
local Worker={}
function Worker.inventory()
  local counts={}
  for slot=1,16 do
    local item=turtle.getItemDetail(slot)
    if item then counts[item.name]=(counts[item.name] or 0)+item.count end
  end
  return counts
end
local fuelItems=Fuel.values
Worker.refuel=Fuel.refuel
function Worker.compact()
  Worker.refuel()
  for source=2,16 do
    local item=turtle.getItemDetail(source)
    if item then
      for target=1,source-1 do
        local other=turtle.getItemDetail(target)
        if other and other.name==item.name and turtle.getItemSpace(target)>0 then
          turtle.select(source)
          if turtle.compareTo(target) then
            turtle.transferTo(target)
            if turtle.getItemCount(source)==0 then break end
          end
        end
      end
    end
  end
end
function Worker.calibrate()
  local origin=U.locate()
  -- Probe only empty cells, never displace a crop or decoration.
  local function probe(at)
    for turns=0,3 do
      local occupied=turtle.inspect()
      if not occupied and turtle.forward() then
        local q=U.locate();local heading=U.heading({x=q.x-at.x,y=q.y-at.y,z=q.z-at.z})
        assert(heading,'GPS did not measure a one-block horizontal move')
        assert(turtle.back(),'Could not return from heading calibration')
        for _=1,turns do turtle.turnLeft() end
        return ((heading-1-turns)%4)+1
      end
      turtle.turnRight()
    end
  end
  local h=probe(origin);if h then return origin,h end
  -- Recover a reboot inside a narrow vertical passage without assuming saved facing.
  for _,side in ipairs({'Up','Down'}) do
    local step=side=='Up' and turtle.up or turtle.down
    local back=side=='Up' and turtle.down or turtle.up
    local moved=0;local at=U.copy(origin)
    for _=1,8 do
      if turtle['inspect'..side]() or not step() then break end
      moved=moved+1;at.y=at.y+(side=='Up' and 1 or -1)
      h=probe(at);if h then break end
    end
    for _=1,moved do assert(back(),'Calibration return path became blocked') end
    if h then return origin,h end
  end
  error('Heading calibration needs fuel and horizontal air within 8 vertical blocks. No blocks were dug.',0)
end
function Worker.run(cfg)
  assert(turtle,'Run the worker on a turtle.')
  cfg.session=tostring(os.getComputerID())..':'..tostring(os.epoch('utc'))
  local request=N.client(cfg)
  local saved=S.load('farm/data/worker',{pending=nil})
  if saved.commissioned==nil and ((saved.stations and saved.stations.output) or saved.pickupBatch) then saved.commissioned=true end
  saved.stats=saved.stats or {steps=0}
  Worker.refuel()
  local pos,heading=Worker.calibrate()
  local status='Starting';local active=false
  local pickupCells=saved.pickupCells or {};saved.pickupCells=pickupCells
  local pickupBatch=saved.pickupBatch
  local function checkpoint() saved.pos=pos;saved.heading=heading;saved.fuel=turtle.getFuelLevel();saved.status=status;S.save('farm/data/worker',saved) end
  local function rpc(kind,data)
    data=data or {};data.pos=U.copy(pos);data.fuel=turtle.getFuelLevel();data.status=status
    if kind~='step' then data.inventory=Worker.inventory() end
    data.dryRun=cfg.dryRun;data.stats=saved.stats
    return request(kind,data)
  end
  local function face(h)
    while heading~=h do
      local left=(heading-h)%4;local right=(h-heading)%4
      -- Heading is recalibrated after every boot, including crashes during turns.
      if left<right then assert(turtle.turnLeft());heading=((heading-2)%4)+1
      else assert(turtle.turnRight());heading=(heading%4)+1 end
    end
  end
  local function direction(target)
    assert(U.distance(pos,target)==1,'Target is not adjacent')
    if target.y==pos.y-1 then return 'Down' end
    if target.y==pos.y+1 then return 'Up' end
    face(assert(U.heading({x=target.x-pos.x,y=0,z=target.z-pos.z})))
    return ''
  end
  local function inspect(target)
    local side=direction(target)
    local ok,b=turtle['inspect'..side]()
    return ok and b or nil,side
  end
  local trail={}
  local function follow(path,homing,retreat)
    for i,nextPos in ipairs(path) do
      if U.distance(pos,nextPos)~=1 then return false,'Invalid route step' end
      if i%8==1 then
        local reply,err=rpc('status')
        if not reply then return false,err end
        active=reply.active
        if not active and not homing then return false,'paused' end
      end
      local permit
      for attempt=1,3 do
        permit=rpc('step',{target=nextPos})
        if not permit or permit.ok then break end
        status=permit and permit.reason or 'Waiting for traffic controller';sleep(0.2+os.getComputerID()%4*0.05)
      end
      if not permit or not permit.ok then
        return false,permit and permit.reason or 'Traffic controller unavailable',
          {pos=U.copy(nextPos),name='computercraft:turtle_advanced',traffic=true,peer=permit and permit.worker}
      end
      local side=direction(nextPos)
      local found,block=turtle['inspect'..side]()
      if found then
        rpc('blocked',{block=nextPos,name=block.name})
        return false,'Blocked at '..U.key(nextPos)..' by '..tostring(block.name),{pos=U.copy(nextPos),name=block.name,traffic=Traffic.turtle(block.name)}
      end
      if not cfg.dryRun then Pickup.collect(side) end
      local move=side=='Up' and turtle.up or side=='Down' and turtle.down or turtle.forward
      local ok,err=move()
      if not ok then
        rpc('blocked',{block=nextPos})
        return false,'Movement failed at '..U.key(nextPos)..': '..tostring(err or 'unknown obstacle')
      end
      if not retreat then trail[#trail+1]=U.copy(pos);if #trail>12 then table.remove(trail,1) end end
      pos=U.copy(nextPos);saved.stats.steps=saved.stats.steps+1
      if not cfg.dryRun then Pickup.collect('Down');pickupCells[U.key(pos)]=nil end
      -- Save at route boundaries; GPS supplies actual position after a crash.
      if i%16==0 then checkpoint() end
    end
    checkpoint();return true
  end
  local function clearVine(job,target)
    local block,side=inspect(target)
    if not Vines.allowed(job,target,block) then return true end
    if cfg.dryRun then return false,'Inspection mode preserves vines' end
    local ok,why=turtle['dig'..side]()
    if not ok then return false,'Vine at '..U.key(target)..': '..tostring(why) end
    if inspect(target) then return false,'Vine clearance not verified at '..U.key(target) end
    local recorded,reason=rpc('cleared_vine',{job=job,block=target})
    if not recorded then return false,reason end
    return true
  end
  local function navigate(goals,homing,initialPath,column)
    local lastError,lastObstacle
    for attempt=1,8 do
      for _,g in ipairs(goals) do if U.equal(pos,g) then return true end end
      local route,err
      if attempt==1 and initialPath then route={path=initialPath}
      else route,err=rpc('route',{goals=goals}) end
      if not route then
        lastError=tostring(err);status='Route: '..lastError
        local back=trail[#trail]
        if attempt>1 and back and U.distance(pos,back)==1 then
          if follow({back},true,true) then table.remove(trail) end
        end
        sleep(0.5+os.getComputerID()%4*0.1)
      else
        local fuel=turtle.getFuelLevel()
        if fuel~='unlimited' then
          local needed=#route.path
          if not homing then
            local home,why=request('route',{pos=route.goal or route.path[#route.path] or pos,goals={cfg.dock},preview=true})
            if not home then return false,why end
            needed=needed+#home.path+cfg.fuelReserve
          end
          if fuel<needed then return false,'Insufficient fuel for this route and safe return' end
        end
        local ok,reason,obstacle=follow(route.path,homing)
        if ok then return true end
        if reason=='paused' then return false,reason end
        if obstacle and obstacle.traffic and (not obstacle.peer or os.getComputerID()>tonumber(obstacle.peer)) then
          local back=trail[#trail]
          if back and U.distance(pos,back)==1 then
            local yielded=follow({back},true,true)
            if yielded then table.remove(trail);status='Yielding to another worker' end
          end
        end
        if column and obstacle and Vines.allowed(column,obstacle.pos,{name=obstacle.name}) and not cfg.dryRun then
          local cleared,why=clearVine(column,obstacle.pos)
          if not cleared then return false,why end
        end
        if column and column.mode=='cane' and obstacle and obstacle.name==column.name
          and obstacle.pos.x==column.pos.x and obstacle.pos.z==column.pos.z and obstacle.pos.y>column.pos.y then
          column.pos=U.copy(obstacle.pos);goals=C.goals(column)
        end
        lastError=tostring(reason);lastObstacle=lastError
        status='Replanning: '..lastError;sleep(1+os.getComputerID()%3)
      end
    end
    local detail=lastError or 'No route returned'
    if lastObstacle and lastObstacle~=lastError then detail=detail..'; last movement failure: '..lastObstacle end
    return false,'Route unavailable after retries: '..detail
  end
  local function getSlot(name)
    for slot=1,16 do local item=turtle.getItemDetail(slot);if item and item.name==name then return slot end end
  end
  local function freeSlots()
    local n=0;for i=1,16 do if turtle.getItemCount(i)==0 then n=n+1 end end;return n
  end
  -- Visit any of the six neighbours and use the matching inventory direction.
  local function approach(target,what)
    local goals={}
    for i=1,6 do goals[#goals+1]=U.add(target,U.dirs[i]) end
    local ok,err=navigate(goals,true)
    if not ok then return false,'Cannot reach the '..what..' chest at '..U.key(target)..': '..tostring(err) end
    local side=direction(target)
    local found,block=turtle['inspect'..side]()
    if not found then return false,'No block at the '..what..' chest coordinates '..U.key(target) end
    -- Learn the block on first visit, then refuse if it is ever swapped out.
    local seen=saved.stations and saved.stations[what]
    if seen and seen~=block.name then
      return false,'The '..what..' chest at '..U.key(target)..' changed from '..seen..' to '..block.name
    end
    if not seen then
      saved.stations=saved.stations or {};saved.stations[what]=block.name;S.save('farm/data/worker',saved)
    end
    return true,side
  end
  local function sweepDrops()
    if cfg.dryRun or not next(pickupCells) or not Pickup.room() then return false end
    local start=U.copy(pos);status='Collecting scattered crop drops'
    while next(pickupCells) and Pickup.room() do
      local key,target,dist
      for k,p in pairs(pickupCells) do
        local n=U.distance(pos,p);if not dist or n<dist then key,target,dist=k,p,n end
      end
      pickupCells[key]=nil
      local route=rpc('route',{goals={target}})
      if route then
        local fuel=turtle.getFuelLevel()
        local home=request('route',{pos=target,goals={cfg.dock},preview=true})
        if home and (fuel=='unlimited' or fuel>=#route.path+#home.path+cfg.fuelReserve) then
          local ok=follow(route.path,false)
          if ok then Pickup.collect('Down') end
        end
      end
    end
    checkpoint();return not U.equal(start,pos)
  end
  local stations=cfg.stations or {}
  local function dock(reason)
    sweepDrops()
    status='Dock: '..(reason or 'Seed resupply')
    print(status)
    local compostFuel=turtle.getFuelLevel()
    if not cfg.dryRun and (compostFuel=='unlimited' or compostFuel>=cfg.fuelReserve*2) then
      local plan=rpc('seed_plan')
      if plan and plan.compost and next(plan.compost) then
        local station=rpc('compost_station')
        if station and station.pos then
          status='Composting surplus seeds'
          local ok,side=approach(station.pos,'composter')
          if ok then
            local fresh=rpc('seed_plan')
            if fresh then
              local count,why=Compost.run(side,fresh.compost or {})
              if count>0 then print('Composted '..count..' surplus seeds') end
              if why then print(why) end
            end
          end
        end
      end
    end
    local outputSide=''
    if stations.output then
      local ok,side=approach(stations.output,'output')
      if not ok then return false,side end
      outputSide=side
    else
      local ok,err=navigate({cfg.dock},true)
      if not ok then return false,err end
      face(cfg.dockHeading)
      local found,b=turtle.inspect()
      if not found or b.name~=cfg.outputBlock then return false,'Output chest missing or replaced; refusing to drop items' end
    end
    status='Unloading: '..(reason or 'Seed resupply')
    Worker.refuel()
    local plan,planError=rpc('seed_plan')
    if not plan then return false,planError end
    local kept,types={},0;local fuelKept=0
    local bank=cfg.seedBuffer and cfg.seedBuffer~=''
    if bank then
      local exists,seedBlock=turtle.inspectDown()
      if not exists or seedBlock.name~=cfg.seedBlock then return false,'Seed-bank buffer missing below dock' end
      local stored,why=rpc('bank_store');if not stored then return false,why end
    end
    for slot=1,16 do
      local item=turtle.getItemDetail(slot)
      if item then
        turtle.select(slot)
        if Soil.isHoe(turtle.getItemDetail(slot,true)) then
          -- Keep carried recovery tools; never export them as stray harvest drops.
        elseif fuelItems[item.name] and turtle.getFuelLevel()~='unlimited' then
          local keep=math.min(item.count,math.max(0,64-fuelKept));fuelKept=fuelKept+keep
          if item.count>keep and (not turtle['drop'..outputSide](item.count-keep) or turtle.getItemCount(slot)~=keep) then return false,'Output chest full' end
        elseif plan.seeds[item.name] then
          -- Batch supplies plus essential replant items; export unrelated reserves.
          local limit=plan.keep and (plan.keep[item.name] or 0) or 4
          if limit>0 and not kept[item.name] and (plan.keep or types<8) then kept[item.name]=0;types=types+1 end
          local keep=kept[item.name] and math.min(item.count,limit-kept[item.name]) or 0
          if kept[item.name] then kept[item.name]=kept[item.name]+keep end
          local excess=item.count-keep
          if excess>0 then
            local bankCount=math.min(excess,(plan.needed or {})[item.name] or 0)
            if not bank and limit>0 and not kept[item.name] and bankCount>0 then return false,'Connect the shared seed bank to retain seeds for more crop types' end
            if bank and bankCount>0 then
              if not turtle.dropDown(bankCount) then return false,'Seed delivery buffer full' end
              local stored,why=rpc('bank_store');if not stored then return false,why end
              plan.needed[item.name]=plan.needed[item.name]-bankCount
            end
            -- Edible planting items (carrots, berries, etc.) still reach ME as surplus.
            local export=turtle.getItemCount(slot)-keep
            if export>0 and (not turtle['drop'..outputSide](export) or turtle.getItemCount(slot)~=keep) then return false,'Output chest full' end
          end
        elseif not turtle['drop'..outputSide]() or turtle.getItemCount(slot)>0 then return false,'Output chest full or inaccessible' end
      end
    end
    local empty
    for slot=1,16 do if turtle.getItemCount(slot)==0 then empty=slot;break end end
    if stations.fuel then
      if empty and Fuel.needed() then
        local ok,side=approach(stations.fuel,'fuel')
        if not ok then return false,side end
        Fuel.fill(side)
      end
    else
      -- The dedicated chest ABOVE the docking cell supplies coal/charcoal only.
      local fuelFound,fuelBlock=turtle.inspectUp()
      if fuelFound and fuelBlock.name==cfg.fuelBlock and empty and Fuel.needed() then
        Fuel.fill('Up')
      end
    end
    local level=turtle.getFuelLevel()
    if level~='unlimited' and level<cfg.fuelReserve then
      return false,'Add coal/charcoal to the fuel chest at '..(stations.fuel and U.key(stations.fuel) or 'above this turtle')
    end
    -- Park at the home cell so the controller can confirm a clean stop.
    if stations.output then navigate({cfg.dock},true) end
    status='Docked';return true
  end
  local function craftSeed(job)
    local pending=saved.crafting
    local recipe=pending and pending.recipe or SeedRecipes.find(job.seed,Worker.inventory())
    if not recipe then return false,'No carried ingredient for a verified seed recipe' end
    local station,err=rpc('craft_station',{target=pending and pending.target})
    if not station then return false,err end
    local ok,side=approach(station.pos,'crafting')
    if not ok then rpc('craft_done');return false,side end
    local _,block=turtle['inspect'..side]()
    if not block or block.name~='minecraft:crafter' then rpc('craft_done');return false,'Crafting station is not a Crafter' end
    local facing=(block.state and block.state.orientation or ''):match('^([^_]+)')
    local directions={north=1,east=2,south=3,west=4,up=5,down=6}
    local d=directions[facing]
    if not d then rpc('craft_done');return false,'Cannot determine Crafter output face' end
    local reached,why=navigate({U.add(station.pos,U.dirs[d])},true)
    if not reached then rpc('craft_done');return false,why end
    side=direction(station.pos)
    local peripheralSide=side=='Up' and 'top' or side=='Down' and 'bottom' or 'front'
    if not pending then
      pending={target=station.pos,seed=job.seed,recipe=recipe};saved.crafting=pending;checkpoint()
    end
    status='Crafting '..pending.seed
    local made,reason=Crafting.run(peripheralSide,pending.seed,pending.recipe,pending,checkpoint)
    if made or not pending.loaded then saved.crafting=nil;checkpoint();rpc('craft_done') end
    return made,reason
  end
  local function finishReplant(job)
    local block,side=inspect(job.pos)
    if block then
      -- Any occupant wins over a remembered gap, including the user's new crop.
      return false,'occupied'
    end
    local slot=getSlot(job.seed)
    if not slot then
      turtle['suck'..side]()
      slot=getSlot(job.seed)
    end
    if not slot and SeedRecipes.find(job.seed,Worker.inventory()) then
      local made,reason=craftSeed(job)
      if made then
        local reached,why=navigate(C.goals(job),true)
        if not reached then return false,why end
        return finishReplant(job)
      end
      if saved.crafting then return false,reason end
    end
    if not slot then return false,'deferred' end
    local function plant()
      if inspect(job.pos) then return false,'New occupant preserved' end
      slot=getSlot(job.seed);if not slot then return false,'No planting item after recovery' end
      turtle.select(slot)
      local ok,err=turtle['place'..side]()
      local planted=inspect(job.pos)
      if planted and (planted.name==job.name or planted.name==job.plantedName) then return true end
      return false,'Replant verification at '..U.key(job.pos)..': expected '..tostring(job.plantedName or job.name)
        ..', found '..(planted and planted.name or 'air')..(not ok and ' ('..tostring(err)..')' or '')
    end
    local ok,err=plant()
    if not ok and C.needsFarmland(job,cfg.customCrops) then
      local function probe()
        if inspect(job.pos) then return nil,'Crop cell occupied; soil left unchanged' end
        local origin=U.copy(pos)
        local reached,why=follow({job.pos},true)
        if not reached then return nil,'Cannot inspect soil: '..tostring(why) end
        local found,soil=turtle.inspectDown()
        local returned,reason=follow({origin},true)
        if not returned then error('Cannot return from soil inspection: '..tostring(reason),0) end
        return found and soil or nil
      end
      local restored,why=Soil.recover(job,cfg.customCrops,probe,function()
        if inspect(job.pos) then return false,'Crop cell is now occupied' end
        return turtle['place'..side]()
      end)
      if restored then ok,err=plant() else err=err..'; '..tostring(why) end
    end
    if not ok then return false,err end
    return true
  end
  local function harvest(job,token,nested)
    local block,side=inspect(job.pos)
    if job.repair then
      if block then return 'occupied','Adopting the block already here',block.state end
      if cfg.dryRun then return 'dry_run','Remembered gap inspected; no blocks changed' end
      local approval,why=rpc('begin',{job=job,token=token})
      if not approval then return 'waiting_seed',why end
      saved.pending={job=job,token=token};checkpoint()
      local planted,reason=finishReplant(job)
      if planted then return 'replanted' end
      if reason=='deferred' or reason=='occupied' then return reason end
      return 'error',reason
    end
    local ready,reason=C.ready(job,block)
    if not ready then return reason,nil,block and block.state end
    if job.mode=='cocoa' then
      local names={'north','east','south','west'}
      if side~='' or names[heading]~=block.state.facing then return 'support_changed','Cocoa approach differs from attachment' end
    end
    if cfg.dryRun then return 'dry_run','Mature crop inspected; no blocks changed',block.state end
    local approval,err=rpc('begin',{job=job,token=token})
    if not approval then return 'protected',err end
    if job.mode=='use' then
      local slot=getSlot(job.item)
      if not slot then return 'missing_seed','Missing interaction item: '..job.item end
      turtle.select(slot)
      local used,useError=turtle['place'..side]()
      if not used then return 'error','Crop interaction failed: '..tostring(useError) end
      sleep(0.25);turtle['suck'..side]()
      local after=inspect(job.pos)
      if not after or (after.name~=job.name and after.name~=job.plantedName) then return 'error','Interaction did not preserve the plant' end
      local stillReady=C.ready(job,after)
      if stillReady then return 'error','Interaction did not change maturity' end
      return 'harvested',nil,block.state
    end
    -- Write BEFORE digging. A restart can repair an interrupted replant.
    if job.seed then saved.pending={job=job,token=token};checkpoint() end
    -- Re-check after network/disk waits so a newly planted replacement is not mined.
    local current=inspect(job.pos)
    local stillReady,changedReason=C.ready(job,current)
    if not stillReady then return changedReason,'Plant changed while harvest was being authorized' end
    local ok,digError=turtle['dig'..side]()
    if not ok then
      return 'error','Harvest denied/failed: '..tostring(digError)
    end
    if job.mode=='cane' and job.rootY then
      -- Remove upper blocks top-down; never occupy a horizontal neighbour or dig the base.
      for y=job.pos.y-1,job.rootY+1,-1 do
        local target={x=job.pos.x,y=y,z=job.pos.z}
        local reached,why=follow({U.add(target,U.dirs[5])},true)
        if not reached then return 'error',why end
        local nextBlock,nextSide=inspect(target)
        if not nextBlock or nextBlock.name~=job.name then break end
        local dug,why=turtle['dig'..nextSide]()
        if not dug then return 'error',why end
      end
    end
    if job.accessCandidates and not nested and job.seed and not inspect(job.pos) then
      local origin=U.copy(pos);local parent={job=job,token=token}
      for _=1,4 do
        local access=rpc('access_job',parent)
        if not access or not access.job then break end
        saved.accessPending=parent;checkpoint()
        local reached,why=follow({job.pos},true)
        local outcome,detail,observed
        if reached then outcome,detail,observed=harvest(access.job,access.token,true)
        else outcome,detail='unreachable',why end
        local after
        if reached then after=inspect(access.job.pos) or false end
        local recorded,reason=rpc('result',{job=access.job,token=access.token,outcome=outcome,detail=detail,state=observed,after=after})
        assert(recorded,reason)
        saved.pending=parent;checkpoint()
        if reached then
          local returned,err=follow({origin},true)
          if not returned then error('Crop access return: '..tostring(err),0) end
        end
        saved.accessPending=nil;checkpoint()
        if not reached then break end
      end
    end
    if job.seed then
      local replanted,replantError=finishReplant(job)
      if not replanted then
        if replantError=='deferred' then return 'deferred','Gap remembered; collecting seeds from remaining plants',block.state end
        if replantError=='occupied' then return 'occupied','New occupant preserved',block.state end
        return 'error',replantError,block.state
      end
    end
    return 'harvested',nil,block.state
  end
  local hello,helloError=rpc('hello',{dock=cfg.dock,name=os.getComputerLabel(),seedBuffer=cfg.seedBuffer,dryRun=cfg.dryRun,remoteMode=true,stations=cfg.stations})
  assert(hello,helloError)
  if saved.accessPending then
    local recovered,why=rpc('recover',saved.accessPending);assert(recovered,why)
    saved.accessPending=nil
  end
  if saved.pending then
    status='Recovering harvest journal'
    local recovered,why=rpc('recover',saved.pending);assert(recovered,why)
    saved.pending=nil -- Controller owns the durable debt, even without seeds right now.
  end
  checkpoint()
  local function prepare(job,token)
    local item=job.seed or job.item
    if not cfg.dryRun and job.mode=='use' and not getSlot(item) then return false,'Put one '..item..' in the turtle for crop interactions' end
    if not cfg.dryRun and job.seed and not getSlot(job.seed) and SeedRecipes.find(job.seed,Worker.inventory()) then
      local made,reason=craftSeed(job)
      if made then return true,true end
      if saved.crafting or job.fetchSeed then return false,reason end
    end
    if cfg.dryRun or not item or getSlot(item) or (not job.fetchSeed and job.mode~='use') then return true,false end
    local ok,err=dock()
    if not ok then return false,err end
    local found,block=turtle.inspectDown()
    if not found or block.name~=cfg.seedBlock then return false,'Seed delivery chest missing BELOW dock' end
    local delivered,why=rpc('seed',{token=token})
    if not delivered then return false,why end
    for slot=1,16 do if turtle.getItemCount(slot)==0 then turtle.select(slot);break end end
    turtle.suckDown(math.min(64,delivered.count))
    if not getSlot(item) then return false,'Could not collect '..item..' from seed buffer below dock' end
    return true,true
  end
  local function heartbeat()
    while true do
      rednet.send(cfg.controller,{v=1,seq=-1,session=cfg.session,kind='heartbeat',
        data={pos=pos,fuel=turtle.getFuelLevel(),status=status,stats=saved.stats}},N.protocol(cfg))
      sleep(1)
    end
  end
  local function work()
    local needsDock=saved.dockReason or (not saved.commissioned and 'Startup' or false)
    while true do
      if saved.crafting then
        local made,reason=craftSeed({seed=saved.crafting.seed})
        if not made then error('Craft recovery: '..tostring(reason),0) end
        needsDock='Craft recovery complete'
      end
      Worker.compact()
      local control=rpc('control')
      if control and control.recover and control.recover~=cfg.recoverAck then
        pos,heading=Worker.calibrate();checkpoint()
        cfg.recoverAck=control.recover;S.save('farm/config',cfg)
        needsDock='Recovery requested';status='Recovery: returning to dock';print(status)
      end
      if needsDock or freeSlots()<=1 then
        saved.dockReason=needsDock or 'One empty inventory slot remaining';checkpoint()
        local ok,err=dock(saved.dockReason)
        if not ok then status=tostring(err);print(status);sleep(10)
        else needsDock=false;saved.dockReason=nil;saved.commissioned=true;checkpoint() end
      else
        local reply,err=rpc('job',{resume=saved.assignment and saved.assignment.key})
        if not reply then status=tostring(err);sleep(10)
        elseif reply.mode=='live' or reply.mode=='dry' then
          cfg.dryRun=reply.mode=='dry';S.save('farm/config',cfg)
          status='Mode: '..reply.mode;print(status)
        elseif not reply.job then
          status=reply.reason or 'Waiting'
          local fuel=turtle.getFuelLevel()
          if reply.returnHome and not U.equal(pos,cfg.dock) then needsDock=reply.reason or 'Paused'
          elseif fuel~='unlimited' and fuel<cfg.fuelReserve*2 then needsDock='Low fuel reserve'
          else sleep(reply.wait or 3) end
        else
          local job=reply.job;saved.assignment={key=job.key,crop=job.crop or job.name};checkpoint()
          local swept=false
          if pickupBatch and pickupBatch~=(job.crop or job.name) then swept=sweepDrops() end
          pickupBatch=job.crop or job.name;saved.pickupBatch=pickupBatch
          local prepared,restocked=prepare(job,reply.token)
          if prepared and swept then restocked=true end
          if not prepared then
            status=tostring(restocked);print(status)
            rpc('result',{job=job,token=reply.token,outcome='missing_seed',detail=status})
            sleep(5)
          else
          if restocked then
            local reroute=rpc('route',{goals=Vines.goals(job)})
            if reroute then reply.path=reroute.path;reply.goal=reroute.goal else reply.path=nil end
          end
          -- Budget a proven return path, rather than Manhattan distance through walls.
          local home,homeError=request('route',{pos=reply.goal,goals={cfg.dock},preview=true})
          local fuel=turtle.getFuelLevel()
          if not reply.path or not home or (fuel~='unlimited' and fuel<#reply.path+#home.path+cfg.fuelReserve) then
            rpc('release')
            if reply.path and home then needsDock='Fuel reserve for next job'
            else status=not home and tostring(homeError) or 'Waiting for a route';sleep(1) end
          else
            status=(cfg.dryRun and 'Inspecting ' or 'Farming ')..job.name
            local reached,why=navigate(Vines.goals(job),false,reply.path,job)
            if reached and job.vines and #job.vines>0 then
              for _,target in ipairs(job.vines) do
                if reached then reached,why=navigate(C.goals({pos=target}),false,nil,job) end
                if reached then reached,why=clearVine(job,target) end
              end
              if reached then reached,why=navigate(C.goals(job),false,nil,job) end
            end
            if reached then
              local outcome,detail,blockState=harvest(job,reply.token)
              local after
              if U.distance(pos,job.pos)==1 then after=inspect(job.pos) or false
              elseif outcome=='harvested' and job.mode=='cane' then after=false end
              local recorded,recordError=rpc('result',{job=job,token=reply.token,outcome=outcome,
                detail=detail,state=blockState,after=after})
              assert(recorded,recordError) -- Never discard an unacknowledged harvest journal.
              if outcome=='harvested' then Pickup.add(pickupCells,job);Pickup.collect('Down') end
              saved.pending=nil;saved.assignment=nil;checkpoint()
              if outcome=='error' then status=detail;print(detail);sleep(10) end
            else
              rpc('result',{job=job,token=reply.token,outcome='unreachable',detail=why})
              status='Waiting after route failure: '..tostring(why);sleep(1)
            end
          end
          end
        end
      end
    end
  end
  parallel.waitForAny(work,heartbeat)
end
return Worker
