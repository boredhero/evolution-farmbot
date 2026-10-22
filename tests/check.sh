#!/usr/bin/env bash
set -eu
cd -- "$(dirname -- "$0")/.."
lua build.lua
while IFS= read -r file; do luac -p "$file"; done < <(rg --files -g '*.lua')
lua tests/run.lua
lua tests/batches.lua
lua tests/crop_compat.lua
lua tests/crop_access.lua
lua tests/crafting.lua
lua tests/compacting.lua
lua tests/compost.lua
lua tests/growth.lua
lua tests/growth_tools.lua
lua tests/packing.lua
lua tests/pickup.lua
lua tests/worker.lua
lua tests/controller.lua
lua tests/controller.lua modern
lua tests/controller_access.lua
lua tests/controller_stop.lua
lua tests/worker_modes.lua
lua tests/command_history.lua
lua tests/players.lua
lua tests/network.lua
lua tests/stations.lua
lua tests/hardware.lua
lua tests/help.lua
lua tests/storage.lua
lua tests/calibration.lua
python3 tests/gps_beacons.py
lua tests/dashboard.lua
lua tests/lifetime.lua
lua tests/soil.lua
lua tests/vines.lua
lua tests/journal.lua
lua tests/traffic.lua
lua tests/scaling.lua
lua tests/path_scaling.lua
lua tests/route_cache.lua
lua tests/path_components.lua
lua tests/mailbox.lua
lua tests/fuel.lua
lua tests/energy.lua
lua tests/retries.lua
lua tests/updater.lua

lua tests/blocked.lua
