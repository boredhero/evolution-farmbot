# First-time setup

You are building one farm controller, four GPS beacons, two robot workers, and two screens. The screens are peripherals, not extra computers. You do not need to write any code or configure individual crop types.

This is a first in-game commissioning, not a field-proven installation. Start with one turtle in inspection mode and watch it complete a trip before enabling harvesting.

## 1. Shopping list

Reuse the **Advanced Computer** and **two turtles** you already have. Craft/find:

| Item | Quantity | Purpose |
| --- | ---: | --- |
| Ordinary Computers | 4 | GPS beacons |
| Ender Modems | 7 | One on each GPS computer, controller, and turtle |
| Diamond pickaxes | 2 | Make the turtles Mining Turtles |
| Geo Scanner | 1 | Finds blocks around both farms |
| Advanced Monitors | 66 | Map: 6 wide × 6 high; stats: 6 wide × 5 high |
| Wired Modems | 6 | Controller, bank, two seed buffers, two monitor walls |
| Networking Cable | As needed | Joins those six wired connections |
| Vanilla chests/barrels | 6 | Three per turtle dock |
| Shared seed-bank inventory | 1 | Prefer a double chest or larger CC-compatible inventory |
| ME Import Buses | 2 | Pull harvested surplus from the output chests into ME |
| Coal/charcoal | Several stacks | Initial turtle fuel and fuel-chest stock |
| ME Export Buses | 2 optional | Keep fuel chests supplied with coal/charcoal |

Use JEI to look up the pack's exact crafting recipes. A turtle needs its two upgrade slots occupied by a **diamond pickaxe** and an **Ender Modem**. Its Geo Scanner is not an upgrade: that block stays next to the controller.

Your ordinary monitors, printer, chat box, player detector, environment detector and speaker are not required. If some existing monitors are Advanced Monitors, they count toward the 66.

## 2. Build the GPS beacons first

GPS lets turtles determine their coordinates. It needs four computer blocks that are **not all on the same flat plane**. Choose an anchor position and place the computer blocks at these offsets:

```text
A: anchor
B: 4 blocks east of A
C: 4 blocks south of A
D: 4 blocks above A
```

Attach one Ender Modem to each computer. Keep all four in your existing forced-loaded area. You can build them on the roof or another convenient nearby location; they do not need cables to each other.

For each computer:

1. Point at the **computer block**, open F3, and note its **Targeted Block X/Y/Z** coordinates. Do not use your player coordinates or the modem's coordinates.
2. Right-click the computer. Its text interface is the **CraftOS terminal**.
3. Paste this command into that terminal and press Enter:

   ```text
   wget run https://raw.githubusercontent.com/boredhero/evolution-farmbot/main/install.lua
   ```

4. Choose `gps` when the installer asks for its role. Enter that computer's own coordinates.
5. Run `farm start`.

Repeat on all four. Leave them running.

If you administer the server, `tools/gps_beacons.py` can check already configured,
loaded GPS computers against their actual server positions, without typing coordinates:

```sh
python3 tools/gps_beacons.py --server-dir /path/to/server
```

Run it on the server host with RCON enabled in `server.properties`. To correct any
reported differences, stop workers first and rerun with `--apply`. It backs up GPS
configs and restarts affected running beacons. Unloaded beacons are not checked.
Recalibrate worker parking spots if they were recorded with incorrect GPS coordinates.
This tool corrects existing GPS configs; it does not install new beacons.

## 3. Place the controller and Geo Scanner

Put your Advanced Computer roughly between the farms. Attach one Ender Modem and place the Geo Scanner **directly against the computer**. Record the scanner block's Targeted Block coordinates.

The scanner reaches 32 blocks in each direction, including vertically. Both farms and the paths between them need to fit in that cube. The scanner stays still; the turtles travel.

Install the program on this computer using the same command, but finish the physical wired network below before completing the controller wizard. You can also wait to install until step 6.

## 4. Build both turtle docks

Coordinate-based output and fuel chests can be reached from any of their six sides,
including above or below. Leave at least one adjacent cell and a route to it clear.

Make this arrangement twice, with each turtle pointing toward its output chest:

```text
             [fuel chest]
             [  turtle  ] -> [output chest] -> ME Import Bus -> ME network
             [seed buffer]
```

- The three dock inventories should be vanilla chests/barrels for the setup checks.
- Put coal/charcoal inside both turtles and their upper fuel chests.
- Leave at least one horizontal neighbor empty so each turtle can leave and calibrate its direction.
- Connect the output chests to ME using Import Buses. Export Buses can supply the upper fuel chests if desired.
- Leave both lower seed buffers empty. The controller moves seeds through them automatically.

Place a shared seed-bank inventory nearby. It may start empty: normal harvesting fills it. **Do not connect an ME Import Bus to the bank or either lower seed buffer.**

## 5. Connect the wired peripherals and screens

Build the map wall **6 wide × 6 high**, and the statistics wall **6 wide × 5 high**, all Advanced Monitors facing the same direction within each wall. Leave a gap between the two walls.

Use wired modems and Networking Cable to connect these six points on one network:

```text
                         +-- shared seed bank
                         +-- turtle 1 lower seed buffer
controller -- cable -----+-- turtle 2 lower seed buffer
                         +-- map monitor wall
                         +-- statistics monitor wall
```

The GPS beacons and moving turtles communicate wirelessly; do not tether the turtles with cables.

Right-click the wired modems on the chests and monitor walls to enable peripheral sharing. The game displays names such as `minecraft:chest_0` or `monitor_0`. Write down the **shared bank name** and each turtle's **lower buffer name**. These are device names, not crop configuration.

Only one wired modem is needed on each assembled monitor wall. No code is installed into monitor blocks.

## 6. Configure the controller

In the Advanced Computer's terminal, run the installation command from step 2. Choose `controller` and enter:

- The default farm-network name; keep it identical on both workers.
- The **Geo Scanner's** block coordinates.
- The shared **seed-bank inventory name**. The wizard lists visible inventories.
- Worker IDs if known, or leave that question blank for now.

The wizard displays the controller's computer ID—write it down. If needed, the ordinary CraftOS command `id` shows it too.

Run `farm start`. The controller begins surveying but starts **paused**.

## 7. Configure the first turtle

Keep the second turtle off for the first test. On the first turtle, run the same installation command, choose `worker`, and enter:

- The same default farm-network name.
- The controller's computer ID.
- The wired inventory name of the seed buffer **below this turtle**.
- `yes` for inspection-only mode.

The wizard checks the dock and calibrates position/facing. Record the turtle's computer ID.

On the running controller, enter `allow` followed by that number. For example, if the turtle is ID 12:

```text
allow 12
```

Then run `farm start` on the turtle.

## 8. Assign the screens and test movement

At the controller's `farm>` prompt, run:

```text
screens
```

It lists the actual connected screen names. The first defaults to the map, the second to statistics. To change assignments, use the actual names, for example:

```text
screen monitor_0 map
screen monitor_1 stats
```

Now enter these commands on the controller, one at a time:

```text
status
crops
start
```

Watch the turtle visit plants and return to the dock. In inspection mode it moves, consumes fuel and may unload inventory, but **does not harvest or plant**. Confirm it can reach the indoor and outdoor farms. Keep clear air paths; it will not mine doors or walls to get through.

The controller batches crop types across the fleet by default. `status` shows the harvest
round and each worker's current crop batch. Workers merge partial stacks and keep working
until one empty slot remains. Necessary fuel/seed resupply, explicit pause and recovery
can return early; temporary no-work replies and route failures do not send workers home. No scheduler option needs configuring.

The map updates every two seconds; maturity is what a turtle last inspected. A full survey normally runs every 120 seconds, so newly planted areas may take up to that long to appear.

## 9. Enable harvesting, then add the second turtle

After setup, updated workers can be switched centrally at the controller's `farm>`
prompt: `worker 9 mode live` enables harvesting for worker 9, and `worker 9 mode dry`
restores inspection mode. `farm worker 9 mode live` is also accepted. Mode changes
apply between jobs, survive restarts, and wait for offline workers to reconnect.
Use `start` on the controller to enable work; changing a mode does not unpause it.
Use `worker 9 recover` to recalibrate its position/facing and retry docking between
jobs. This preserves inventory and replant records, and also works while it is
retrying a failed unload. A powered-off worker must be turned on to receive commands.

1. At the controller, run `pause` and wait for the first turtle to return.
2. Hold Ctrl+T in the turtle terminal to stop its program and return to the CraftOS prompt.
3. Run these two commands there:

   ```text
   farm mode live
   farm start
   ```

4. At the controller, run `start` again.
5. Watch harvesting, replanting, unloading and refueling once. Missing seeds can create remembered replant gaps; the turtle should keep working and recover them from later harvests.
6. Configure and test the second turtle the same way, pairing its own ID and entering its own seed-buffer name.

Afterward, adding or replacing supported crops is automatic. There is no per-crop planting list to maintain. The program starts on device reboot; you do not need another Minecraft server restart to install or update Lua code.

## If a step fails

Stop at that step and record the exact message plus the computer/turtle ID. Do not delete `farm/data/`: it contains the farm memory and unfinished-replant records. `history` and `status` at the running controller show what it is waiting on. Hold Ctrl+T to return to CraftOS when you need to run a setup or installer command.

If the download command fails, download [install.lua](https://raw.githubusercontent.com/boredhero/evolution-farmbot/main/install.lua) in your desktop browser, drag it into the open in-game terminal, then type `install`.

For crop coverage, limits and recovery details, see [README.md](README.md). GPLv3 license text is included in [LICENSE](LICENSE) and in the installer.

## Easier-to-read screens (v0.2.0)

Both screens now default to text scale **1**, twice the old character size. Crop tiles use crop-type colors; their symbols still mean `R` ripe when inspected, `g` growing when inspected, `?` unseen/stale, `!` replant gap, and `*` busy. Colors are reused across species (CC has 16 palette entries); tap a tile for its exact crop name. Stats use matching crop-name colors and paginate the list.

Run `hardware` at the `farm>` prompt to list every peripheral the controller can currently see, with each monitor's role, the dimension read from the Environment Detector and how many players are in range. Anything required that is missing is named `MISSING` along with how to fix it, which is the fastest way to catch a wired modem whose ring was never lit.

If you attach a Player Detector to the controller's wired network, the map draws everyone nearby as a facing arrow and highlights whoever is closest to the controller with a `YOU ARE HERE` caption; add an Environment Detector so players in other dimensions are filtered out. Neither is required. While at least one player is in range the map refreshes every 0.5s instead of every 2s, so markers keep up with walking.

All touch controls sit on the bottom one or two rows of each screen, so you can reach them standing on the floor without jumping or pillaring. Touch **TEXT - / TEXT +** on either screen to change its font size. On the map, **Z- / Z+** changes map zoom, **Y- / Y+** changes crop floor, and N/S/W/E pans. New map views start at 2x zoom; existing views keep their old zoom. Use **TEXT -** to reach scale 0.5 and **Z-** to reach 1x for the full-radius, individually resolved overview on a 6x6 map. Scale 1 trades overview detail for readability; nearby cells can merge when zoomed all the way out.

Alternatively, at the controller prompt: `screen monitor_0 scale 1` (use the actual name from `screens`).

## Updating without reconfiguring

On v0.2.3 or later, **Up / Down** at `farm>` recalls older/newer commands. Edit the recalled line normally and press Enter to execute it; arrows alone do not run anything. The last 100 commands are saved FIFO across restarts (new entries evict the oldest), excluding blank lines and consecutive duplicates. This command history is separate from the existing `history` command, which displays crop activity. Update-confirmation answers are not added to command history.

On v0.2.1 or later, type **`stop`** or **`exit`** at the controller's `farm>` prompt to return to normal CraftOS without Ctrl+T. It pauses new farming, keeps the controller available while workers finish their jobs and dock, saves state, then exits. `status` shows what it is waiting for; `start` cancels a pending stop. `pause` is different: it leaves the controller/dashboard running. At CraftOS, use `farm start` to reopen the controller (still paused), then `start` at `farm>` when you want harvesting enabled.

If you installed before v0.2.0, hold Ctrl+T on the **paused controller**, run the installer command once more, then run `reboot`. Your configuration, crop memory and statistics stay in place. This adds the updater; it does not require a Minecraft server restart. Existing GPS hosts can keep running the earlier compatible GPS program while you update the controller.

From then on, either of these commands works at the controller's `farm>` prompt **or** at a stopped computer's CraftOS prompt:

```text
check update
update system
```

Both check the repository's `release.json`, display installed/available versions and release notes, and ask `Install ...? [y/N]`. Nothing is installed without **yes**. All files listed by the release are downloaded, including new modules. Downloads use a version tag, not a moving mix of files from main. The updater checks file sizes, corruption checksums and Lua syntax, stages the release, backs up the old program, and then installs. A successful update reboots **that CC computer only**.

The running controller pauses farming after confirmation and refuses to install until known workers are at their docks and have no active job leases. If it tells you to wait, let them return and run the command again. When updating a turtle or using the stopped CraftOS prompt, first pause farming on the controller and let every turtle finish its work and dock. Update devices individually; this is not a fleet-wide rollout. Run `start` on the controller when ready to resume.

Backups remain under `farm/install-backups/update-*`. Handled installation failures roll back changed program files; interrupted transactions have a recovery journal checked at startup. If damage prevents startup/recovery code itself from loading, retain the backups and journal and ask for help—do not delete farm data. Old, unlisted modules are deliberately not deleted automatically. Checksums detect accidental corruption, not a malicious repository owner; the trusted source is this repository over HTTPS.

## Additional workers and automatic seed crafting

Install the current FarmBot code on another Mining Ender Turtle and run `farm setup worker`.
It discovers the controller and inherits its existing output/fuel chest coordinates. Give it coal,
place it in its own clear parking cell, and let GPS record that cell. On the controller, run
`allow <id>`, then start the worker with `farm start`. Use `worker <id> mode live` on the
controller when ready. Each worker has its own parking space; shared chests need no duplicate setup.

A vanilla Crafter can sit near the crops or controller, anywhere inside scanner coverage.
Keep it empty, unpowered, and leave its output face accessible. Workers discover it and insert
one ingredient, pulse it, and receive the seeds through its output face. The controller reserves
the machine for one worker at a time. This uses verified single-ingredient recipes from this pack,
including modded recipes; plants with no such recipe still need their actual seed drops.

For blueberry/aloe picking, install `compat-datapack` as
`world/datapacks/evolution-farmbot-interactions`, run `/reload`, and give each worker one stick.
The worker retains the stick and picks the plants without breaking their base.

A vanilla composter is also discovered automatically anywhere in the scanned area. Leave a reachable
face for the turtle; no modem or coordinates are required. Update the interaction datapack once when
adding composting support. Finished-batch surplus seeds are composted; protected supplies and edible
produce are retained/exported normally. No composter means normal ME unloading continues.

Workers share one crop cycle, but each crop round belongs to only one worker. Adding a worker gives
it an unfinished, unowned crop type. Returning to unload does not abandon its current crop. Loose
crop drops are collected on paths and in a nearby sweep automatically; no new setup is needed.

Lifetime statistics: tap **STATS** at the bottom of either monitor. The page preserves lifetime farm harvest/replant totals and shows favorite crops, controller uptime, scans, and individual bot harvests, replants, inspections, errors and blocks traveled. PREV BOT/NEXT BOT includes offline bots; MAP returns to the farm. Per-bot attribution and travel begin with v0.4.1; older totals are not retroactively assigned. Counts are harvest actions, not item yields.

For soil recovery, put a hoe in each worker inventory. Hoes are retained during unloading. If replanting a known farmland crop fails, the worker inspects the soil beneath the empty planting cell, uses a carried hoe on tagged dirt, verifies farmland, then retries planting. Two uses allow coarse/rooted dirt conversion; game rules decide whether modded soil is tillable. Existing crops, non-dirt supports and special-support crops are preserved. Errors distinguish the planting coordinate from the soil coordinate. A missing hoe leaves the repair debt pending.

Vine maintenance runs during crop visits: ordinary minecraft:vine blocks in the crop column up to three blocks above it are cleared top-down. A vine occupying a remembered replant gap is also removed, with the planting debt preserved. Other blocks, glow-berry vines and neighboring columns are untouched. New vines are discovered by regular scans or inspected route obstacles; inspection-only mode never clears them.

Fleet responsiveness: the controller uses linear crop-population counts and small atomic mutation records between full checkpoints, including recovery from the backup snapshot. Synthetic tests cover 16 workers and 4096 plants; live capacity depends on farm layout and hardware. Workers reserve the next movement cell, report positions every second, favor routes away from other upcoming paths, and wait or back out when blocked. Turtle encounters use short-lived avoidance instead of rescanning the entire farm. Per-operation latency samples are recorded in farm/data/performance every 30 seconds.

Workers persist their unfinished crop assignment, current round, pickup queue and required docking work. On reboot they locate themselves with GPS and request their unfinished crop first; an established worker does not return home just because it restarted. A completed crop transitions directly to the next available type. Ordinary RPC retries start after one second; movement-permission retries after half a second. A dedicated receiver preserves incoming messages while a single ordered handler processes durable mutations; heartbeat and traffic replies bypass expensive searches.

Pathfinding uses numeric voxel indices and cooperative queued-event yields, not timer sleeps. Valid routes survive crop inspections and relax planned traffic avoidance only when it changes the search. Fuel refills target 8000 stored movement fuel (within the turtle limit) plus one carried backup stack, replenished when visiting the fuel chest. Carried fuel is consumed automatically as needed. No new configuration switches are required.

Crops below torches can be reached through a freshly harvested neighboring crop: the worker steps into that gap, inspects and harvests the blocked same-crop neighbor, then retreats and replants the gap. Both planting obligations are durable. This requires a single-block replant crop in the same unfinished round and two carried planting items; it does not remove torches, uproot immature neighbors, or take another worker's crop round.
