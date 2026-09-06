-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local args={...}
if args[1]~='update' then print('Use: check update');return end
require('farm.updater').run()
