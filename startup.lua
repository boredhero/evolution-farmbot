-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
-- Evolution FarmBot startup
if fs.exists('farm/update-pending.json') then
  local ok,err=pcall(function() require('farm.updater').recover() end)
  if not ok then printError('Update recovery required: '..tostring(err));return end
  os.reboot()
end
shell.run('farm.lua','start')
