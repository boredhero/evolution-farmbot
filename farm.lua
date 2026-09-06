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
elseif command=='config' then print(textutils.serialize(cfg));return
elseif command~='start' then print('Commands: setup [role], start, update, mode live|dry, inspect [up|down], config');return end
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
