-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local S=require('farm.lib.store')
local C=require('farm.lib.crops')
local N=require('farm.lib.network')
local Worker={}
function Worker.inventory()
  local counts={}
  for slot=1,16 do
    local item=turtle.getItemDetail(slot)
    if item then counts[item.name]=(counts[item.name] or 0)+item.count end
  end
  return counts
end
local fuelItems={['minecraft:coal']=true,['minecraft:charcoal']=true,['minecraft:coal_block']=true}
function Worker.refuel()
  for slot=1,16 do
    local item=turtle.getItemDetail(slot)
    if item and fuelItems[item.name] then turtle.select(slot);turtle.refuel() end
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
  Worker.refuel()
  local pos,heading=Worker.calibrate()
  local status='Starting';local active=false
  local function checkpoint() saved.pos=pos;saved.heading=heading;S.save('farm/data/worker',saved) end
  local function rpc(kind,data)
    data=data or {};data.pos=U.copy(pos);data.fuel=turtle.getFuelLevel();data.status=status
    data.inventory=Worker.inventory()
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
  local function follow(path,homing)
    for i,nextPos in ipairs(path) do
      if U.distance(pos,nextPos)~=1 then return false,'Invalid route step' end
      if i%8==1 then
        local reply,err=rpc('status')
        if not reply then return false,err end
        active=reply.active
        if not active and not homing then return false,'paused' end
      end
      local side=direction(nextPos)
      local found,block=turtle['inspect'..side]()
      if found then
        rpc('blocked',{block=nextPos,name=block.name})
        return false,'obstructed'
      end
      local move=side=='Up' and turtle.up or side=='Down' and turtle.down or turtle.forward
      local ok,err=move()
      if not ok then
        rpc('blocked',{block=nextPos})
        return false,err or 'Movement failed'
      end
      pos=U.copy(nextPos)
      -- Save at route boundaries; GPS supplies actual position after a crash.
      if i%16==0 then checkpoint() end
    end
    checkpoint();return true
  end
  local function navigate(goals,homing,initialPath)
    for attempt=1,8 do
      for _,g in ipairs(goals) do if U.equal(pos,g) then return true end end
      local route,err
      if attempt==1 and initialPath then route={path=initialPath}
      else route,err=rpc('route',{goals=goals}) end
      if not route then status='Route: '..tostring(err);sleep(3)
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
        local ok,reason=follow(route.path,homing)
        if ok then return true end
        if reason=='paused' then return false,reason end
        status='Replanning: '..tostring(reason);sleep(1+os.getComputerID()%3)
      end
    end
    return false,'Route unavailable after retries'
  end
  local function getSlot(name)
    for slot=1,16 do local item=turtle.getItemDetail(slot);if item and item.name==name then return slot end end
  end
  local function freeSlots()
    local n=0;for i=1,16 do if turtle.getItemCount(i)==0 then n=n+1 end end;return n
  end
  local function dock()
    status='Returning to dock'
    local ok,err=navigate({cfg.dock},true)
    if not ok then return false,err end
    face(cfg.dockHeading)
    local found,b=turtle.inspect()
    if not found or b.name~=cfg.outputBlock then return false,'Output chest missing or replaced; refusing to drop items' end
    status='Unloading'
    Worker.refuel()
    local plan,planError=rpc('seed_plan')
    if not plan then return false,planError end
    local kept,types={},0
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
        if plan.seeds[item.name] then
          -- Keep a small working reserve; pool the rest for either turtle to use.
          if not kept[item.name] and types<8 then kept[item.name]=0;types=types+1 end
          local keep=kept[item.name] and math.min(item.count,4-kept[item.name]) or 0
          if kept[item.name] then kept[item.name]=kept[item.name]+keep end
          local excess=item.count-keep
          if excess>0 then
            local bankCount=math.min(excess,(plan.needed or {})[item.name] or 0)
            if not bank and keep==0 and bankCount>0 then return false,'Connect the shared seed bank to retain seeds for more crop types' end
            if bank and bankCount>0 then
              if not turtle.dropDown(bankCount) then return false,'Seed delivery buffer full' end
              local stored,why=rpc('bank_store');if not stored then return false,why end
              plan.needed[item.name]=plan.needed[item.name]-bankCount
            end
            -- Edible planting items (carrots, berries, etc.) still reach ME as surplus.
            local export=turtle.getItemCount(slot)-keep
            if export>0 and (not turtle.drop(export) or turtle.getItemCount(slot)~=keep) then return false,'Output chest full' end
          end
        elseif not turtle.drop() or turtle.getItemCount(slot)>0 then return false,'Output chest full or inaccessible' end
      end
    end
    -- The dedicated chest ABOVE the docking cell supplies coal/charcoal only.
    local fuelFound,fuelBlock=turtle.inspectUp()
    if fuelFound and fuelBlock.name==cfg.fuelBlock then
      local empty
      for slot=1,16 do if turtle.getItemCount(slot)==0 then empty=slot;break end end
      if empty then
        turtle.select(empty);turtle.suckUp(64);Worker.refuel()
        if turtle.getItemCount(empty)>0 then turtle.select(empty);turtle.dropUp() end
      end
    end
    local level=turtle.getFuelLevel()
    if level~='unlimited' and level<cfg.fuelReserve then return false,'Add coal/charcoal to the fuel chest above this turtle' end
    status='Docked';return true
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
    if not slot then return false,'deferred' end
    turtle.select(slot)
    local ok,err=turtle['place'..side]()
    if not ok then return false,'Replant failed: '..tostring(err) end
    local planted=inspect(job.pos)
    if not planted or (planted.name~=job.name and planted.name~=job.plantedName) then return false,'Could not verify replanted crop' end
    return true
  end
  local function harvest(job,token)
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
      if not after or after.name~=job.name then return 'error','Interaction did not preserve the plant' end
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
  local hello,helloError=rpc('hello',{dock=cfg.dock,name=os.getComputerLabel(),seedBuffer=cfg.seedBuffer,dryRun=cfg.dryRun})
  assert(hello,helloError)
  if saved.pending then
    status='Recovering harvest journal'
    local recovered,why=rpc('recover',saved.pending);assert(recovered,why)
    saved.pending=nil -- Controller owns the durable debt, even without seeds right now.
  end
  checkpoint()
  local function prepare(job,token)
    local item=job.seed or job.item
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
        data={pos=pos,fuel=turtle.getFuelLevel(),status=status}},N.protocol(cfg))
      sleep(5)
    end
  end
  local function work()
    local needsDock=true
    while true do
      if needsDock or freeSlots()<3 then
        local ok,err=dock()
        if not ok then status=tostring(err);print(status);sleep(10)
        else needsDock=false end
      else
        local reply,err=rpc('job')
        if not reply then status=tostring(err);sleep(10)
        elseif not reply.job then
          status=reply.reason or 'Waiting'
          if not U.equal(pos,cfg.dock) then needsDock=true else sleep(reply.wait or 10) end
        else
          local job=reply.job
          local prepared,restocked=prepare(job,reply.token)
          if not prepared then
            status=tostring(restocked);print(status)
            rpc('result',{job=job,token=reply.token,outcome='missing_seed',detail=status})
            sleep(5)
          else
          if restocked then
            local reroute=rpc('route',{goals=C.goals(job)})
            if reroute then reply.path=reroute.path;reply.goal=reroute.goal else reply.path=nil end
          end
          -- Budget a proven return path, rather than Manhattan distance through walls.
          local home,homeError=request('route',{pos=reply.goal,goals={cfg.dock},preview=true})
          local fuel=turtle.getFuelLevel()
          if not reply.path or not home or (fuel~='unlimited' and fuel<#reply.path+#home.path+cfg.fuelReserve) then
            rpc('release');needsDock=true
            if not home then status=tostring(homeError);sleep(5) end
          else
            status=(cfg.dryRun and 'Inspecting ' or 'Farming ')..job.name
            local reached,why=navigate(C.goals(job),false,reply.path)
            if reached then
              local outcome,detail,blockState=harvest(job,reply.token)
              local after=inspect(job.pos)
              local recorded,recordError=rpc('result',{job=job,token=reply.token,outcome=outcome,
                detail=detail,state=blockState,after=after or false})
              assert(recorded,recordError) -- Never discard an unacknowledged harvest journal.
              saved.pending=nil;checkpoint()
              if outcome=='error' then status=detail;print(detail);sleep(10) end
            else
              rpc('result',{job=job,token=reply.token,outcome='unreachable',detail=why})
              needsDock=true
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
