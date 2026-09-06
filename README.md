# Evolution FarmBot

Autonomous CC:Tweaked farming for FTB Evolution 1.39.0 / Minecraft 1.21.1.

The controller's live scan and both monitor dashboards have been commissioned on the server. Automated tests exercise the farming logic and mocked CC peripherals; **harvesting has not yet been tested with physical turtles on the live server**. Start a new worker in inspection-only mode.

**New to ComputerCraft? Start with [the beginner setup guide](GETTING_STARTED.md).**

On a computer or turtle's CraftOS prompt, download and run the complete installer:

```text
wget run https://raw.githubusercontent.com/boredhero/evolution-farmbot/main/install.lua
```

Choose `gps`, `controller`, or `worker` in the wizard. Configure the four GPS hosts first. The same bundle includes farming, both monitor dashboards, and the GPLv3 license. Monitors themselves do not get an installer.

## How the farm defines itself

Plant supported crops where you want them. The next successful survey (normally every 120 seconds) discovers them; there is no crop-coordinate list, seed shopping list, or route to program. This includes new Mystical Agriculture crop types following that mod's normal registry naming.

- A turtle inspects maturity at the actual plant, then harvests it.
- An empty seed inventory does **not** prohibit a harvest. Guaranteed-seed crops can bootstrap from a single plant; probabilistic-seed crops can be harvested while other living plants of the same type remain.
- The controller durably records the planting obligation **before** authorizing a seed-crop harvest. Missing seeds leave a remembered gap, not a stopped turtle.
- Remaining plants of that crop receive harvesting priority. As soon as a turtle has matching seeds, filling those gaps takes priority over normal harvesting.
- The turtles retain working reserves and automatically pool additional seeds in a shared bank. That bank starts empty; no manually configured seed filters or initial stock are necessary. Items above the automatically calculated reserve go to ME, including edible planting items such as carrots and blueberries.
- Plant a different crop in an old spot and the observed replacement becomes the new plan. The turtle never breaks a replacement just to restore its old record.
- Only a hole caused by an authorized FarmBot harvest is remembered. Empty farmland does not automatically become a planting job. Removing an ordinary, unharvested plant retires that position at the next survey.
- To retire an already-empty **pending** replant spot, remove/change its farmland or put a replacement block/plant there. An empty pending gap alone cannot communicate whether you want restoration or deletion.

There is one biological limit: if a crop has probabilistic seed drops and only one known living plant remains, the system preserves that final plant until a matching seed becomes available. It does not pretend software can guarantee seeds from random drops. Torchflower seeds and pitcher pods are also not renewable by simply harvesting their mature plants.

"Automatically discovered" means new placements of supported crops. Unknown tagged crops are discovered and inspected, but not destructively guessed at. CC does not provide a universal "this block's correct planting item and harvest behavior" API.

## Pathfinding and memory

The controller uses **three-dimensional A\***, with six movement directions, unit movement cost, a Manhattan-distance heuristic, a binary-heap priority queue, and goal-directed tie breaking. It searches for a reachable harvesting position above or beside each crop, not through the crop itself. Cocoa uses an attachment-aware side approach.

The Geo Scanner supplies a 65 × 65 × 65 block cube at radius 32, centered on the scanner. Its scan contains block names, tags and coordinates, **not crop growth state**. The worker gets growth state with `turtle.inspect*()` when it visits. The scanner has no line-of-sight requirement.

The obstacle map is saved as a compact bitset (~34 KB before serialization). Up to 128 route-cache entries are kept in memory, validated before reuse, and invalidated when the scanned obstacle map changes. Workers inspect every movement destination and report unexpected obstructions for replanning. Crop history and replant obligations survive restarts; the route cache itself is rebuilt after reboot.

"Learning" here is explicit bookkeeping and adaptive revisit intervals, not an LLM or neural network. A* minimizes movement steps in the surveyed map; it does not optimize turtle turns or guarantee globally optimal scheduling of the whole farm.

No navigation digging or attacks are used. Turtles move vertically without ladders. Doors, ladders, water, crops and other non-air blocks are conservatively treated as obstacles, even if a player could pass them. Leave air openings/aisles between your indoor and outdoor farms. Two turtles may need a passing space in narrow corridors.

## Hardware to assemble

Use your existing advanced computer as the controller and your two turtles as workers. Both war-room screens run on that same controller; no dedicated display computers are needed.

- 1 Geo Scanner, directly touching the controller.
- 2 diamond pickaxes: upgrade both turtles to Mining Turtles.
- 7 Ender Modems: one per turtle, one on the controller, one on each of four GPS computers.
- 4 additional ordinary computers for GPS hosts. Advanced computers are not necessary for these.
- 2 worker docks, each with three vanilla chests/barrels: output in front, fuel above, seed-bank transfer buffer below.
- 1 shared seed-bank inventory. A double chest works initially; a larger inventory with CC inventory methods is useful for many MystAg types. There is no per-seed filter configuration.
- 66 Advanced Monitor blocks: a 6-wide × 6-high map wall and a 6-wide × 5-high statistics wall. Leave at least a one-block gap between walls so they do not attempt to merge. Larger walls work too. Ordinary monitors lack the color/touch interface used here.
- 6 wired modems plus networking cable: one at the controller, one at the seed bank, one at each dock's seed buffer, and one at each assembled monitor wall. Enable peripheral sharing by right-clicking the peripheral modems.
- 2 ME Import Buses on the **output** chests. Coal/charcoal in the fuel chests; ME Export Buses can keep these fueled automatically.

Do **not** attach ME Import Buses to the seed bank or its delivery buffers: those seeds are reserved for planting. The software exports surplus through the output chest instead.

Your player detector, environment detector, chat box, printer and speaker are not required for operation.

Dock side view (the seed bank is elsewhere, connected by wired modems):

```text
            [fuel chest]
            [ turtle  ] -> [output chest] -> ME Import Bus
            [seed buffer] -- wired cable -- [shared seed bank]
```

Leave a horizontal escape cell next to each turtle. All docks and all routes between farms must fit within the scanner cube. Do not move a configured dock or scanner without rerunning setup for the affected device.

## Step-by-step installation

### 1. Place the controller and scanner

Put them roughly between the farms, accounting for both their horizontal separation and the upper-floor MystAg bed. Record the Geo Scanner's **F3 Targeted Block** X/Y/Z coordinates. These must be the scanner block coordinates, not your player position or the computer's coordinates.

The target server uses an Advanced Peripherals maximum paid scan radius of 32 and has powered peripherals disabled, so its stationary scanner does not need FE. Other servers should check their own scanner settings and energy requirements. This installer does not edit server configuration.

The target server has 64 MiB disk per computer/turtle, 2 MiB file uploads, a 10 ms ideal per-computer main-thread task budget and a 20 ms global task budget. Monitor limits remain 8 × 6; existing monitor bandwidth is sufficient for both walls. Administrators configuring another server should back up their configuration before changing limits. These are the deployment's resource settings, not measured minimum requirements.

### 2. Build the GPS constellation

Place four computer blocks with Ender Modems in a non-coplanar arrangement. Example offsets from an arbitrary anchor `(X,Y,Z)`:

```text
A: X,   Y,   Z
B: X+4, Y,   Z
C: X,   Y,   Z+4
D: X,   Y+4, Z
```

Record each **computer block's** absolute coordinates. These are separate from the scanner coordinates. Keep the hosts in your existing forced-loaded server area.

### 3. Install the same file on all seven devices

The easiest installation is this command at each device's normal CraftOS prompt:

```text
wget run https://raw.githubusercontent.com/boredhero/evolution-farmbot/main/install.lua
```

Alternatively, download [install.lua](https://raw.githubusercontent.com/boredhero/evolution-farmbot/main/install.lua) to your desktop. Open the computer/turtle terminal, drag that file into the Minecraft window, accept the import if prompted, then run:

```text
install
```

The installer writes all program modules and `startup.lua`, backs up any replaced program/startup files, and preserves existing FarmBot configuration and saved data. It asks for a role on a fresh device. You do not copy or type Lua code.

The same installer now includes both dashboards. **Nothing is uploaded into the monitor blocks themselves.** For an already-installed controller, pause farming, let workers dock, hold Ctrl+T, import the updated `install.lua`, run `install`, then `reboot`. Keep the workers updated with the same bundle too. A normal controller/computer reboot is sufficient for program updates; the Minecraft server does not need another restart.

An administrator can alternatively copy the installer into a device's server-side CC directory after resolving its exact computer ID. Do not copy files into guessed IDs.

### 4. Configure and launch the GPS hosts first

On each GPS computer, choose `gps` in the installer and enter that host's own absolute computer-block coordinates. Then run:

```text
farm start
```

Do this on all four hosts. They will automatically host GPS on subsequent boots.

### 5. Build the docks and connect the seed bank

Face each turtle toward its output chest. Put the fuel chest directly above and the seed-transfer chest directly below. Add some coal/charcoal to each turtle and each fuel chest.

Connect the controller, seed bank, and both lower seed buffers on one wired network. Right-click the inventory modems to enable sharing; note their displayed names, such as `minecraft:chest_0`. Each lower buffer must have its own name and must differ from the bank.

Nothing needs to be put in the seed bank initially. Any seeds you already have may optionally be deposited there.

### 6. Configure the controller

Choose `controller` in the installer. Keep the default farm-network name. Enter the scanner coordinates and shared seed-bank inventory name. Setup lists the inventory names visible to this controller.

Enter the turtle IDs if you already know them, or leave the pairing list empty and add them below. Run `farm start`. The controller initially starts **paused** and begins surveying.

### 7. Configure each turtle

Choose `worker`. Enter the controller's computer ID and the wired inventory name of **that turtle's lower seed buffer**. Keep the default inspection-only setting (`yes`). Setup checks the dock and measures position/facing using GPS.

On the controller, pair each turtle if you did not enter its ID during setup:

```text
allow TURTLE_ID
```

Replace `TURTLE_ID` with the actual number. Then run `farm start` on the turtle.

### 8. Commission one turtle in inspection mode

Start with the second turtle off. At the controller prompt, use:

```text
status
crops
start
```

The first turtle should visit crop positions, inspect them, and return to its dock. Inspection mode consumes movement fuel and can unload inventory, but does not harvest or plant anything.

Check that the indoor, upper-floor and outdoor plants appear in `crops`. Watch one complete trip between farms. Use `history` to see maturity findings or errors. If a route is blocked by a doorway, create an air opening rather than expecting the turtle to mine through it.

### 9. Enable live harvesting

At the controller, run `pause` and let the turtle return. Hold Ctrl+T in the turtle terminal to stop its program, then run:

```text
farm mode live
farm start
```

Run `start` on the controller again. Watch a mature crop harvest/replant, an output unload, and a refuel. Plant a different supported crop in one bed and verify discovery within the next survey. Start and commission the second turtle after the first works correctly.

From then on, adding crops or changing your planting layout requires **no crop configuration**. The bank is automatically replenished from harvests. Normal server chunk loading and any necessary FTB Chunks fake-player permissions still apply; a denied action is reported rather than bypassed.

## The two war-room walls

Build each wall from Advanced Monitors facing the same direction: six across and six high for the map, six across and five high for statistics. Connect one enabled wired modem to each assembled wall and cable it into the controller's existing wired network. They are automatically detected, including walls connected after the controller starts.

At text scale 0.5, the 6 × 6 map wall provides 121 × 81 character cells. The current UI leaves a 117 × 65 map area, enough for distinct positions across the entire 65 × 65 survey floor. The statistics wall provides 121 × 67 character cells. The layouts also support other sizes, including two 8 × 6 walls.

The first discovered wall defaults to the map; the second defaults to operations. To choose their assignments explicitly, use these commands **at the running controller's `farm>` prompt**:

```text
screens
screen monitor_0 map
screen monitor_1 stats
```

Use the actual peripheral names printed by `screens`, not assumed IDs. Assignments and view settings survive controller reboots. If the walls are swapped, swap their roles with those commands. Both wall programs execute on the controller; the monitors do not need computers, wireless modems, or their own installers.

### Map wall

- Top-down survey of the selected crop-height layer, with terrain/bed context.
- Crop markers distinguish last-seen ready/growing, unknown/stale, unsupported, excluded, in-flight operations and remembered replant gaps.
- Numbered turtle markers and current issued routes; gray cached-route overlay with an on/off touch control. Cached routes are historical successful plans, not guarantees that a path remains clear. The overlay is capped at 16,000 visited nodes per frame.
- Touch controls for detected floors, zoom, panning, reset-to-auto, and selecting a crop for coordinates and observation details. Indoor and upper-floor beds are separate layers rather than being misleadingly stacked on the same map.

### Operations wall

- Current controller-session uptime, accumulated recorded controller uptime and session count.
- Durable lifetime harvest actions, confirmed replants, deferred replants, errors/path failures and successful survey count. These counters are independent of the seven-day per-position history and start when this telemetry version is first run; they do not invent historical totals from before installation.
- Current living/gap counts per crop type, last-observed maturity counts, lifetime harvests per type, and touch pagination when the list exceeds the wall height.
- Worker connection age/status, coordinates and fuel; current cached-route count and cache hits; recent activity.

Both walls refresh every two seconds and only changed text rows are transmitted. Positions arrive via worker telemetry (normally within five seconds); full surveys normally run every 120 seconds. **Crop maturity is last observed by a turtle, not a magical continuously live scanner value.** Observations older than three scan intervals are labeled stale. Uptime counts the running controller, including pauses, excludes offline periods, and may lose the final unsaved fraction of a minute after abrupt shutdown. Lifetime harvests are actions, not harvested item quantities.

To generate local layout previews from the actual renderer with **simulated data**, run `lua tests/build_dashboard_preview.lua`, then open `dashboard-map-preview.html` and `dashboard-stats-preview.html`. These previews are not screenshots of a real farm.

## Crop coverage

| Crop | Behavior |
| --- | --- |
| Wheat, carrots, potatoes, beetroot | Mature harvest, immediate or remembered same-seed replant |
| All normally named Mystical Agriculture `*_crop` blocks, including inferium | Age 7; same `*_seeds`; vanilla/MA farmland |
| Actually Additions canola, coffee, rice, flax | Age 7; exact mod planting items |
| Farmer's Delight cabbage, onions, ground tomatoes | Their correct maturity and seed/onion items |
| Farmer's Delight rice panicles | Harvest upper age-3 panicle, preserve rice base |
| Immersive Engineering industrial hemp | Upper half only, preserve farmland/root |
| Cottonly cotton; Hexerei sage | Age 7; cotton seeds / singular `sage_seed`; deferred replants supported |
| BWG blueberries; vanilla sweet berries | Mature bushes on grass; harvest and replant with berries |
| Cocoa | Mature pods attached to jungle logs; attachment-aware placement |
| Sugar cane | Top-down harvesting above an intact root on sand/red sand |
| Melons and pumpkins | Harvest fruit blocks wherever present, as requested; stems remain untouched |
| Nether wart | Mature harvest/replant on soul sand |
| Torchflower and pitcher crop | Recognize mature plants and planting items; need external sniffer seeds/pods for sustainable repeated harvesting |
| Bamboo and cactus | Top harvesting with root retained; conservative soil rules |
| Kelp | Top harvesting only where reachable from air above; submerged routes are intentionally not supported |
| Glow berries and upper rope tomatoes | Optional interaction compatibility datapack below; never broken as a fallback |

This is not a generic tree, mushroom, chorus, or every-mod-plant harvester. New unsupported tagged crops are inspect-only. Rope-logged **base** tomatoes are currently skipped; ordinary ground tomatoes and optional upper rope tomatoes are distinct cases.

### Optional right-click compatibility

`compat-datapack/` contains a Minecraft 1.21.1 datapack adding only cave vines and upper rope tomatoes to `computercraft:turtle_can_use`. It does not modify drops or enable arbitrary block interactions. **It is prepared locally, not installed on the server.**

To enable these optional crops, install that directory as `world/datapacks/evolution-farmbot-interactions`, reload datapacks, and put a few ordinary sticks in the shared bank. The worker selects a stick and uses `turtle.place*()` for the approved interaction, checks that the plant remains, and checks that maturity changed. Without the tag, it reports the unsupported interaction and leaves the plant intact. Blueberries do not require this datapack.

## Commands and recovery

Controller prompt: `status`, `crops`, `history`, `inventories`, `screens`, `screen NAME map|stats`, `start`, `pause`, `scan`, `allow ID`, `exclude X Y Z`, `include X Y Z`.

CraftOS prompt: `farm start`, `farm setup [controller|worker|gps]`, `farm config`, `farm mode live`, `farm mode dry`, `farm inspect [up|down]`.

Startup retries recoverable errors every 30 seconds so GPS/controller boot order does not permanently stop a worker. Hold Ctrl+T to stop. The controller's running/paused state persists; workers finish an already-started replant before honoring a pause and homing. Pending replant obligations remain remembered while paused.

Saved data lives under `farm/data/`. Do not delete it to fix an ordinary error. Controller debts are written before harvest authorization; the worker also keeps an unacknowledged transaction journal. Restart recovery hands unfinished work back to the controller without requiring you to insert a missing seed.

Fuel and storage still have finite capacity. The system budgets return routes, rechecks routes after obstructions, and refuses to throw items into the world when its output chest is missing. A full ME output/seed bank, an inaccessible farm, or physical removal of the last viable seed source can require a physical fix. Very large farms may also need a higher CC computer disk limit; disk-write failure prevents authorization rather than silently losing the journal.

## Verification and sources

Run the complete local suite with:

```sh
bash tests/check.sh
```

It builds and syntax-checks the installer/modules, checks A* against BFS on randomized maps, tests full-radius paths and crop rules, exercises live-layout/replant state transitions, executes actual worker and controller loops with mocked CC APIs, tests seed transfer and persistent storage, and verifies installer backup behavior. These simulations are not a substitute for the in-game commissioning steps above.

Local test prerequisites: Lua 5.4 (including `luac`), Bash, and ripgrep. The installed game program uses CC's built-in Lua and does not require those packages in Minecraft.

## License

Copyright (C) 2026 boredhero. Licensed under the **GNU General Public License, version 3 only** (`GPL-3.0-only`). See [LICENSE](LICENSE) and [NOTICE](NOTICE). The standalone installer includes both files and writes them to the in-game computer along with the source modules.

## References

The crop rules were checked against the installed mod jars' blockstates, loot tables and relevant bytecode, including BWG 2.6.0, Cottonly 0.16.6, Hexerei 0.5.0.3, Actually Additions 1.3.26, Farmer's Delight 1.3.2, Immersive Engineering 12.4.2, Mystical Agriculture 8.0.27, CC:Tweaked 1.119.0 and Advanced Peripherals 0.7.62b.

Relevant upstream references:

- [CC monitor color, text scale and touch capabilities](https://tweaked.cc/peripheral/monitor.html)
- [CC turtle movement, inspection, placement and inventory API](https://tweaked.cc/module/turtle.html)
- [CC block details and block state](https://tweaked.cc/reference/block_details.html)
- [Advanced Peripherals Geo Scanner result format and configuration](https://docs.advanced-peripherals.de/0.7/peripherals/geo_scanner/)
- [CC GPS constellation setup](https://tweaked.cc/guide/gps_setup.html)
- [Wired inventory transfers](https://tweaked.cc/generic_peripheral/inventory.html)
- [Maintainer discussion of the 1.21 turtle-use tag regression](https://github.com/cc-tweaked/CC-Tweaked/issues/2011) and [the corresponding fix](https://github.com/cc-tweaked/CC-Tweaked/commit/4710ee5bcc4c8d256d6dfe477450911a00915b60)
- [BWG's upstream 1.21.1 project](https://github.com/Potion-Studios/Oh-The-Biomes-Weve-Gone/tree/1.21.1)

## Release updates and readable displays

Version **0.2.1** includes `stop` / `exit` at the controller prompt: pause, let workers finish and dock, save, and return to CraftOS without a keyboard shortcut. It also includes v0.2.0's `check update` / `update system` at both the running controller prompt and CraftOS. These check [release.json](release.json), show notes, and require confirmation before updating the current device. New runtime modules are discovered automatically by the build and listed in the manifest. Config, crop memory, replant debts and statistics are not release targets. See the [update and screen controls guide](GETTING_STARTED.md#updating-without-reconfiguring).

Displays now default to scale 1 for larger text, with touch controls for text size, crop-colored map tiles and matching stats labels. Growth status remains a separate symbol; a color never implies a ripe crop. Use scale 0.5 plus map zoom 1 for a fully resolved 65x65 overview on a 6x6 wall.

Release workflow: edit `release-info.json` (bump the semantic version), run `bash tests/check.sh` to regenerate `release.json` and `install.lua`, commit all source and generated artifacts, and create/push the matching `vX.Y.Z` tag alongside main. Never move a published version tag. Runtime Lua files under `farm/` are auto-discovered; generated/user data and development tests are not distributed. A manifest points exclusively at its matching release tag, so a check cannot combine files from different main commits.
