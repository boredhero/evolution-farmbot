-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local args={...}
if args[1] and args[1]~='system' then print('Use: update system');return end
require('farm.updater').run()
