-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local args={...}
local S=require('farm.lib.store')
local command=args[1] or 'start'
if command=='update' or (command=='check' and args[2]=='update') then require('farm.updater').run();return end
if command=='setup' then require('farm.setup').run(args[2]);return end
local cfg=S.load('farm/config',nil)
if not cfg then require('farm.setup').run(args[2]);return end
if command=='inspect' then
  assert(turtle,'Use on a turtle')
  local method=args[2]=='down' and turtle.inspectDown or args[2]=='up' and turtle.inspectUp or turtle.inspect
  local ok,data=method();print(textutils.serialize(data));return
elseif command=='mode' then
  assert(cfg.role=='worker','Only workers have an inspection mode')
  assert(args[2]=='live' or args[2]=='dry','Use farm mode live or farm mode dry')
  cfg.dryRun=args[2]~='live';S.save('farm/config',cfg)
  print('Mode saved: '..args[2]..'. Run farm start.');return
elseif command=='stations' then
  assert(cfg.role=='worker','Only workers use chest stations')
  local saved=S.load('farm/data/worker',{})
  for _,which in ipairs({'output','fuel'}) do
    local at=(cfg.stations or {})[which]
    local seen=(saved.stations or {})[which]
    print(which..': '..(at and (at.x..','..at.y..','..at.z) or 'not set')..
      (seen and ('  ('..seen..')') or ''))
  end
  print('Change with: farm station output|fuel X Y Z');return
elseif command=='station' then
  assert(cfg.role=='worker','Only workers use chest stations')
  local which=args[2]
  assert(which=='output' or which=='fuel','Use farm station output|fuel X Y Z, or farm station fuel none')
  cfg.stations=cfg.stations or {}
  if args[3]=='none' then
    assert(which~='output','The output chest cannot be removed; give it new coordinates instead')
    cfg.stations.fuel=nil;print('Fuel chest removed. Refuel by hand or from the chest above the parking cell.')
  else
    local x,y,z=tonumber(args[3]),tonumber(args[4]),tonumber(args[5])
    assert(x and y and z,'Use farm station '..which..' X Y Z (F3 Targeted Block coordinates)')
    cfg.stations[which]={x=math.floor(x),y=math.floor(y),z=math.floor(z)}
    print(which..' chest moved to '..math.floor(x)..','..math.floor(y)..','..math.floor(z))
  end
  -- Forget the block remembered at the old spot so a swapped or relocated
  -- chest is accepted instead of being refused as tampering.
  local saved=S.load('farm/data/worker',{})
  if saved.stations and saved.stations[which] then
    saved.stations[which]=nil;S.save('farm/data/worker',saved)
    print('Forgot the previous '..which..' block; it will be learned again on arrival.')
  end
  S.save('farm/config',cfg)
  print('Run farm start.');return
elseif command=='config' then print(textutils.serialize(cfg));return
elseif command~='start' then print('Commands: setup [role], start, update, mode live|dry, station output|fuel X Y Z, stations, inspect [up|down], config');return end
local function run()
  if cfg.role=='gps' then shell.run('gps','host',tostring(cfg.pos.x),tostring(cfg.pos.y),tostring(cfg.pos.z))
  elseif cfg.role=='controller' then require('farm.controller').run(cfg)
  elseif cfg.role=='worker' then require('farm.worker').run(cfg)
  else error('Unknown role; run farm setup') end
end
while true do
  local ok,err=pcall(run)
  if ok or tostring(err):find('Terminated',1,true) then break end
  printError('FarmBot paused: '..tostring(err))
  S.save('farm/data/last-error',{time=os.epoch('utc'),message=tostring(err)})
  print('Journal preserved. Retrying in 30s (hold Ctrl+T to stop).')
  sleep(30) -- GPS/controller may boot after this turtle on a server restart.
end
