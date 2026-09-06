# Evolution FarmBot

Autonomous crop farming for ComputerCraft: Tweaked on FTB Evolution 1.39.0 / Minecraft 1.21.1.

You plant crops wherever you like. A computer with a Geo Scanner finds them, mining turtles walk
to them, check whether they are ripe, harvest and replant them, and two monitor walls show you a
live map of the farm and how it has been doing. There is no crop list to maintain, no route to
program, and no per-seed configuration.

> **Status:** the controller, surveying and both dashboards have been commissioned on a live
> server. Harvesting has been exercised by the test suite against mocked turtles, but not yet
> proven with physical turtles in production. Commission your first turtle in inspection-only
> mode and watch it complete a trip before you let it dig.

**Never used ComputerCraft before?** Follow [GETTING_STARTED.md](GETTING_STARTED.md) — it is a
numbered walkthrough from crafting the parts to the first harvest.

---

## What it does

- **Finds crops by itself.** Every 120 seconds the Geo Scanner surveys a 65x65x65 cube around the
  controller. Anything supported that you planted shows up on the next survey.
- **Harvests and replants.** A turtle travels to the plant, inspects it for real maturity, and
  harvests only when it is ready.
- **Never forgets a replant.** If seeds run out, the empty spot is recorded on disk *before* the
  harvest is allowed. When seeds arrive, filling those gaps jumps the queue. A server crash
  mid-harvest does not lose the obligation.
- **Runs its own seed bank.** Turtles keep a working reserve and pool the surplus into a shared
  chest. It starts empty and fills itself from harvests. Everything above the reserve goes to
  your ME system.
- **Routes in 3D.** A\* pathfinding around obstacles, with turtles avoiding each other. It never
  digs a tunnel and never attacks anything to get somewhere.
- **Shows you what is happening.** A tactical map wall and an operations-statistics wall, both
  touch-controlled, both driven by the controller — the monitors need no computers of their own.

Supported crops include vanilla farmland crops, all normally named Mystical Agriculture crops,
Farmer's Delight, Actually Additions, Immersive Engineering hemp, Cottonly, Hexerei sage, BWG
blueberries, cocoa, sugar cane, melons, pumpkins, nether wart, bamboo, cactus and kelp. See the
[full crop table](docs/ARCHITECTURE.md#crop-coverage). Crops it does not recognise are visited and
inspected but never destroyed.

## What you need

| Item | Qty | Purpose |
| --- | ---: | --- |
| Advanced Computer | 1 | The controller |
| Geo Scanner | 1 | Placed **touching** the controller; finds the crops |
| Mining Turtles | 2 | Workers (a turtle plus a diamond pickaxe) |
| Ordinary Computers | 4 | GPS beacons, so turtles know where they are |
| Ender Modems | 7 | One per turtle, one on the controller, one per GPS beacon |
| Advanced Monitors | 66 | Map wall 6 wide x 6 high, stats wall 6 wide x 5 high |
| Wired Modems | 6 | Controller, seed bank, both dock buffers, both monitor walls |
| Networking Cable | as needed | Joins those six |
| Chests / barrels | 6 | Three per turtle dock |
| Shared seed bank | 1 | A double chest or anything larger |
| ME Import Buses | 2 | On the **output** chests only |
| Coal or charcoal | a few stacks | Turtle fuel |

Optional: a **Player Detector** and an **Environment Detector** on the controller's wired
network. They add the live player overlay ("YOU ARE HERE") to the map. Without them everything
else works identically.

Ordinary monitors will not work — the interface needs advanced monitor colour and touch.

**Dock layout**, per turtle (the seed bank lives elsewhere, joined by cable):

```text
            [fuel chest]
            [ turtle  ] -> [output chest] -> ME Import Bus
            [seed buffer] -- wired cable -- [shared seed bank]
```

Leave a free cell beside each turtle to step aside into. Every dock and every route between farms
must fit inside the scanner cube. Leave air gaps between indoor and outdoor beds — doors,
ladders and water are treated as walls.

Do **not** put an ME Import Bus on the seed bank or the dock buffers. Those seeds are reserved
for replanting; the surplus leaves through the output chest.

## Install

At the CraftOS prompt of each device (right-click the computer or turtle):

```text
wget run https://raw.githubusercontent.com/boredhero/evolution-farmbot/main/install.lua
```

The installer asks for a role — `gps`, `controller`, or `worker` — and then walks you through
that device's settings. It writes all program files plus a startup entry, backs up anything it
replaces, and preserves existing FarmBot configuration and saved data. You never copy or type Lua
code, and nothing is installed into the monitors.

Order matters: **the four GPS beacons first**, then the controller, then the turtles.

The whole commissioning sequence, with coordinates, docks, wiring and the first test run, is in
[GETTING_STARTED.md](GETTING_STARTED.md).

## Running it day to day

Start the controller with `farm start`. It comes up **paused** and immediately begins surveying.
At its `farm>` prompt:

```text
help
```

That lists every command; `help scan` explains one in full. Arrow keys recall your last 100
commands.

| Command | What it does |
| --- | --- |
| `status` | Running or paused, crop and worker counts, replant gaps, survey age, errors |
| `hardware` | Every peripheral the controller can see, with anything missing named `MISSING` |
| `crops` | How many of each crop the last survey found |
| `history` | Per-position record: what was there, what happened, why |
| `inventories` | Wired inventory names, for use during setup |
| `start` / `pause` | Enable work / stop handing out new work |
| `stop` (`exit`, `quit`) | Pause, wait for turtles to dock, save, exit to CraftOS |
| `scan` | Survey now instead of waiting for the next one |
| `screens` | Which monitor wall is showing what |
| `screen NAME map\|stats` | Assign a wall a role |
| `screen NAME scale 0.5\|1\|1.5\|2` | Set a wall's text size |
| `allow ID` | Pair a turtle by its computer ID |
| `exclude X Y Z` / `include X Y Z` | Leave one crop alone / undo that |
| `check update` / `update system` | See if there is a new version / install it |

At the CraftOS prompt (not the `farm>` prompt): `farm start`, `farm setup [controller|worker|gps]`,
`farm config`, `farm mode live`, `farm mode dry`, `farm inspect [up|down]`.

`farm mode dry` is inspection-only: the turtle travels and inspects but never digs or places.
That is the mode to commission a new turtle in. `farm mode live` turns harvesting on.

Hold **Ctrl+T** in any terminal to stop that program.

### Changing your farm

Just plant. The next survey picks it up; run `scan` if you are impatient. Plant something
different in an old bed and the replacement becomes the new plan — the turtle will not rip it out
to restore what used to be there.

Removing an ordinary, unharvested plant retires that position at the next survey. To retire a
spot that is already an empty *pending* replant, break or change its farmland, or put something
else there; an empty gap on its own cannot tell the controller whether you want it restored or
forgotten.

If one particular plant should be left alone permanently, `exclude X Y Z` it. It stays on the map
marked excluded.

## What the screens show

The first wall the controller finds becomes the **map**; the second becomes **stats**. Use
`screens` to see which is which and `screen NAME map` / `screen NAME stats` to swap them. All
touch controls sit on the bottom rows so you can reach them on a tall wall. Assignments survive
reboots.

**Map wall** — a top-down view of one floor of the survey. Each crop is a coloured tile whose
symbol tells you its last known state: `R` ready, `g` growing, `?` unknown or stale, `!` a
remembered replant gap, `*` a turtle working it now, `x` excluded. Numbered markers are your
turtles, with their current routes drawn in. Nearby players appear as facing arrows, and the one
closest to the controller is captioned `YOU ARE HERE`. Touch controls pick the floor, zoom, pan,
and select a crop to read its coordinates and last observation.

**Stats wall** — uptime, lifetime harvests, confirmed and deferred replants, errors and survey
count; then per-crop living/gap counts and last-observed maturity; then each worker's status,
position and fuel.

Important: **maturity is what a turtle last saw, not a live reading.** The scanner reports where
blocks are, not how grown they are. Anything not looked at recently is labelled stale.

Details of every marker, counter and control are in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#the-two-war-room-walls).

## Updating

At the controller's `farm>` prompt (or at CraftOS):

```text
check update
update system
```

`check update` only looks and reports. `update system` pauses the farm, waits for the turtles to
dock, downloads the release, verifies every file's checksum, backs up what it replaces, installs
and reboots. Your config, crop memory, replant debts and statistics are never overwritten. Update
the turtles the same way.

One quirk worth knowing: GitHub caches the release manifest for five minutes, so a release
published moments ago can still report "up to date". Wait and check again.

## Troubleshooting

| Symptom | Likely cause and fix |
| --- | --- |
| `Attach the Geo Scanner directly to the controller` | The scanner must be a block touching the controller. Run `hardware` to confirm what is seen. |
| Something says `MISSING` in `hardware` | That peripheral is absent or its wired modem ring is not lit — right-click the modem to enable sharing. |
| Turtle says it is not paired | Run `allow ID` on the controller with the turtle's computer ID. |
| Nothing happens after `start` | Work only begins once a survey has succeeded. Check `status` for the survey age and any scanner error. |
| A turtle never reaches part of the farm | Something on the route is treated as a wall (door, ladder, water, crops). Open a clear air aisle; it will not mine through. |
| `crops` does not list a bed you planted | Outside the 65x65x65 scanner cube, on an unsupported crop, or the survey has not run yet — try `scan`. |
| Turtle stops with a fuel or storage error | Refuel the fuel chest, or clear the output chest / ME system. It refuses to drop items on the ground. |
| Monitor walls are swapped | `screens`, then `screen monitor_0 map` and `screen monitor_1 stats` with the real names. |
| Text too small or too large on a wall | `screen NAME scale 0.5` (whole farm on a 6x6 wall) through `scale 2`. |
| A worker died or the server restarted mid-job | Nothing to do. Restart it; unfinished work and replant debts are journalled and handed back automatically. |

Errors that might resolve themselves are retried every 30 seconds, so GPS and controller boot
order cannot permanently strand a turtle. Saved state lives in `farm/data/` — do not delete it to
fix an ordinary error.

Some situations genuinely need you: a full ME system, an unreachable farm, or losing the last
viable seed source for a crop with random seed drops.

## Digging deeper

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how crops are modelled, pathfinding, the
  durability guarantees, the full crop table, dashboard internals, the optional interaction
  datapack, and sources.
- [CLAUDE.md](CLAUDE.md) — module map, code style, test discipline and the release process, for
  anyone changing the code.
- `bash tests/check.sh` runs the whole suite (needs Lua 5.4, `luac`, ripgrep). It is not a
  substitute for in-game commissioning.

## License

Copyright (C) 2026 boredhero. Licensed under the **GNU General Public License, version 3 only**
(`GPL-3.0-only`). See [LICENSE](LICENSE) and [NOTICE](NOTICE). The installer ships both files and
writes them onto the in-game computer alongside the source modules.
