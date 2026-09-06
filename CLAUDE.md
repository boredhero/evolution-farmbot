# CLAUDE.md

Guidance for Claude Code sessions working in this repository.

## What this is

**Evolution FarmBot** — a ComputerCraft: Tweaked program (CC:T 1.119.0, Minecraft 1.21.1 Forge)
that runs an autonomous crop farm on the maintainer's FTB Evolution 1.39.0 server. An advanced
computer is the controller; mining turtles are workers. The controller discovers crops with an
Advanced Peripherals Geo Scanner, routes turtles with 3D A\*, records replant obligations
durably, and renders a tactical map plus an operations-statistics view onto two advanced monitor
walls.

This is a live deployment, not a toy. The maintainer is the sole operator (controller is in-game
computer #4). Breaking the controller loop breaks a running farm.

## Runtime constraints (these are not negotiable)

- Everything under `farm/`, plus `farm.lua`, `startup.lua`, `check.lua`, `update.lua`, runs
  **inside CC:Tweaked's Lua sandbox**, which is Lua 5.2-flavoured (Cobalt). No `goto` guarantees,
  no `io`, no `os.time` semantics you'd expect, no bit operators from 5.3+, no `os.exit`.
- **No external libraries, ever.** Whatever the code needs, it implements. The only "dependency"
  is the CC/Advanced Peripherals API surface.
- The dev-side tooling (`build.lua`, `tests/*.lua`) runs on host **Lua 5.4** and may use `io`.
  Runtime modules must not.
- The controller runs `parallel.waitForAny(...)` over cooperative loops. Anything that blocks
  without yielding stalls every other loop, including the RPC service the turtles depend on.
- Advanced computer terminal is **51 columns x 19 rows**. Console output wider than 51 columns
  wraps mid-word and reads as garbage.
- Files are delivered to in-game computers by the generated single-file installer. Adding a
  runtime module is fine; adding a build step or a package manager is not.

## Module map

Entry points:

| File | Role |
| --- | --- |
| `farm.lua` | CraftOS front door: `start`, `setup [role]`, `config`, `mode live\|dry`, `inspect`, `update`. Retries recoverable errors every 30s so GPS/controller boot order can't strand a worker. |
| `startup.lua` | Runs on boot; finishes an interrupted update, then `farm start`. |
| `check.lua` / `update.lua` | Thin CraftOS wrappers for `check update` / `update system`. |

Programs:

- `farm/controller.lua` — the controller. `parallel.waitForAny(networkLoop, scanLoop,
  displayLoop, playerLoop, consoleLoop, touchLoop, stopLoop)`. Holds the RPC handler (`handle`)
  for every worker message kind and the `farm>` console dispatch.
- `farm/worker.lua` — turtle program: request job, route, move, inspect, harvest, replant, dock,
  unload, refuel, journal.
- `farm/dashboard.lua` — draws map and stats views onto monitors; owns touch hit-testing.
- `farm/setup.lua` — interactive wizard, writes `farm/config`.
- `farm/updater.lua` — self-updater; manifest fetch, staged download, backup, install, reboot,
  crash recovery.

Libraries under `farm/lib/`:

`util` (time/keys/geometry), `store` (durable save/load with backup), `world` (packed obstacle
bitset), `path` (A\* with binary heap), `crops` (crop rules and goal positions), `network`
(protocol name), `seeds` (bank stock/deliver/store), `garden` (plots, intents, debts, tasks),
`metrics` (lifetime counters), `checksum` (Adler-32), `frame` (clipped framebuffer),
`command_history` (100-entry console recall), `players` (Player/Environment Detector polling),
`hardware` (peripheral survey → printable lines), `help` (console help text).

Generated, **never hand-edit**: `install.lua`, `release.json`. Both come from `lua build.lua`.

## Code style

Match the existing style exactly. It is deliberately terse:

```lua
-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 boredhero
local U=require('farm.lib.util')
local x=1;local y=2
if ok then return a end
```

- Every Lua file starts with those two SPDX/copyright lines.
- No spaces around `=`, `==`, `..` in dense expressions; statements separated with `;` on one
  line where they belong together.
- Short local names (`U`, `S`, `W`, `P`, `C`, `f`, `j`, `w`).
- Comments only where intent is non-obvious — why, not what. Do not add narration.
- **Do not reformat existing code** and do not introduce a competing idiom.

## Test discipline

Run everything with:

```sh
bash tests/check.sh          # needs lua 5.4, luac, rg; must exit 0
```

`check.sh` regenerates the installer, syntax-checks every Lua file with `luac -p`, then runs each
test file in turn.

- Tests are plain Lua scripts that `assert` behaviour and print `PASS <human sentence>` lines.
  The sentence describes the guarantee, not the mechanics.
- CC APIs (`peripheral`, `rednet`, `turtle`, `parallel`, `fs`, `os`) are mocked inside the test
  file itself. There is no framework.
- A new test file **must** be added to `tests/check.sh` or it never runs.
- `tests/build_dashboard_preview.lua` is a dev tool, not a test: it renders the real dashboard
  with fake data to `dashboard-*-preview.html`.

Prefer assertions that cannot drift. `tests/help.lua` reads `farm/controller.lua`, extracts every
`cmd=='...'` token from the dispatcher, and requires that `farm/lib/help.lua` documents exactly
that set — adding a console command without documenting it fails the suite. Copy that pattern
when you can.

## Release process

1. Edit `release-info.json`:
   `{"version": "X.Y.Z", "notes": "plain text, no quotes and no backslashes"}`
   (`build.lua` parses those fields with a pattern and will refuse quotes/backslashes in notes.)
2. `lua build.lua` — regenerates `release.json` (per-file size + Adler-32 manifest) and
   `install.lua` (single-file installer with every source embedded). It auto-discovers runtime
   modules with `rg --files farm -g '*.lua'`, so a new module needs **no** manifest edit.
3. `bash tests/check.sh` — must exit 0.
4. Commit source and both generated artifacts together.
5. Annotated tag: `git tag -a vX.Y.Z -m "FarmBot vX.Y.Z: <short summary>"`
6. `git push --atomic origin main refs/tags/vX.Y.Z`

Never move a published tag. The in-game updater fetches
`https://raw.githubusercontent.com/boredhero/evolution-farmbot/main/release.json`, compares
versions, then downloads each file from the **tag** ref — so a manifest can never mix files from
different main commits.

## Gotchas that have already cost time

- **`tests/controller_stop.lua` mocks `parallel.waitForAny` with positional parameters**
  (`function(network,scan,display,player,console,touch,stop)`). Adding a loop to the real
  `waitForAny` call silently shifts them and produces a baffling, unrelated failure. Update the
  mock signature in lockstep with `farm/controller.lua`.
- **`present and nil or hint` is not a conditional.** `and nil` collapses, so the fallback always
  wins. This bit `farm/lib/hardware.lua`. Use an explicit `if`.
- **The dashboard renders into a clipped framebuffer** (`farm/lib/frame.lua`). `F:write` silently
  drops out-of-bounds rows, so a layout bug fails invisibly rather than erroring. Reserve space
  explicitly instead of assuming it exists.
- **Every clickable dashboard control must render on the bottom one or two rows.** A tall monitor
  wall puts the top rows out of a player's reach in game. `tests/dashboard.lua` enforces this.
- **raw.githubusercontent serves `release.json` with `cache-control: max-age=300`** and ignores
  both cache-busting query strings and `Cache-Control: no-cache`. A release published moments ago
  can still read as "up to date" for up to five minutes. `check update` says so; don't "fix" it.
- **The Geo Scanner peripheral type is `geo_scanner` on some pack builds and `geoScanner` on
  others.** Both are probed. Keep it that way.
- Console lines must fit 51 columns (see above).

## Documentation layout

- `README.md` — for the person running the farm: what it does, hardware, install, day-to-day
  commands, what the screens mean, troubleshooting.
- `GETTING_STARTED.md` — the numbered first-time commissioning walkthrough. Link to it; don't
  duplicate it.
- `docs/ARCHITECTURE.md` — design and behaviour reference: crop model, pathfinding, durability,
  crop coverage table, dashboard internals, sources. Technical depth belongs here.

Keep the three in sync when behaviour changes, and add new console commands to
`farm/lib/help.lua`'s topic list (the suite will remind you).
