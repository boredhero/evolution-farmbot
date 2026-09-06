#!/usr/bin/env bash
set -eu
cd -- "$(dirname -- "$0")/.."
lua build.lua
while IFS= read -r file; do luac -p "$file"; done < <(rg --files -g '*.lua')
lua tests/run.lua
lua tests/worker.lua
lua tests/controller.lua
lua tests/controller_stop.lua
lua tests/command_history.lua
lua tests/players.lua
lua tests/network.lua
lua tests/stations.lua
lua tests/hardware.lua
lua tests/help.lua
lua tests/storage.lua
lua tests/calibration.lua
lua tests/dashboard.lua
lua tests/updater.lua
