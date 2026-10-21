# Evolution FarmBot — architecture and behaviour reference

This is the design document. If you only want to run the farm, read the
[README](../README.md) and [GETTING_STARTED.md](../GETTING_STARTED.md) instead.

## How the farm defines itself

Plant supported crops where you want them. The next successful survey (normally every 120
seconds) discovers them; there is no crop-coordinate list, seed shopping list, or route to
program. This includes new Mystical Agriculture crop types following that mod's normal registry
naming.

- A turtle inspects maturity at the actual plant, then harvests it.
- An empty seed inventory does **not** prohibit a harvest. Guaranteed-seed crops can bootstrap
  from a single plant; probabilistic-seed crops can be harvested while other living plants of the
  same type remain.
- The controller durably records the planting obligation **before** authorizing a seed-crop
  harvest. Missing seeds leave a remembered gap, not a stopped turtle.
- Remaining plants of that crop receive harvesting priority. As soon as a turtle has matching
  seeds, filling those gaps takes priority over normal harvesting.
- The turtles retain working reserves and automatically pool additional seeds in a shared bank.
  That bank starts empty; no manually configured seed filters or initial stock are necessary.
  Items above the automatically calculated reserve go to ME, including edible planting items such
  as carrots and blueberries.
- Plant a different crop in an old spot and the observed replacement becomes the new plan. The
  turtle never breaks a replacement just to restore its old record.
- Only a hole caused by an authorized FarmBot harvest is remembered. Empty farmland does not
  automatically become a planting job. Removing an ordinary, unharvested plant retires that
  position at the next survey.
- To retire an already-empty **pending** replant spot, remove/change its farmland or put a
  replacement block/plant there. An empty pending gap alone cannot communicate whether you want
  restoration or deletion.

There is one biological limit: if a crop has probabilistic seed drops and only one known living
plant remains, the system preserves that final plant until a matching seed becomes available. It
does not pretend software can guarantee seeds from random drops. Torchflower seeds and pitcher
pods are also not renewable by simply harvesting their mature plants.

"Automatically discovered" means new placements of supported crops. Unknown tagged crops are
discovered and inspected, but not destructively guessed at. CC does not provide a universal
"this block's correct planting item and harvest behavior" API.

## Pathfinding and memory

The controller uses **three-dimensional A\***, with six movement directions, unit movement cost,
a Manhattan-distance heuristic, a binary-heap priority queue, and goal-directed tie breaking. It
searches for a reachable harvesting position above or beside each crop, not through the crop
itself. Cocoa uses an attachment-aware side approach.

The Geo Scanner supplies a 65 x 65 x 65 block cube at radius 32, centered on the scanner. Its
scan contains block names, tags and coordinates, **not crop growth state**. The worker gets
growth state with `turtle.inspect*()` when it visits. The scanner has no line-of-sight
requirement.

The obstacle map is saved as a compact bitset (~34 KB before serialization). Up to 128
route-cache entries are kept in memory, validated before reuse, and invalidated when the scanned
obstacle map changes. Workers inspect every movement destination and report unexpected
obstructions for replanning. Crop history and replant obligations survive restarts; the route
cache itself is rebuilt after reboot.

The controller owns a persisted, finite harvest round shared by every worker. At the start
of a round it snapshots currently eligible crop positions and groups them by block name.
Groups sort by known-ready count, then total due count; within a worker's current group,
distance orders the jobs. Growth still requires inspection: unknown maturity is not counted
as confirmed ripe. Existing leases prevent duplicate assignments. New growth waits for the
next round, so a continuously replenished large group cannot starve a singleton. Repairs
override batching. Removed, temporarily ineligible and unreachable jobs leave the current
round and can be reconsidered later. Worker-specific seed eligibility still applies.

Workers consume carried fuel and merge compatible partial stacks before requesting work.
Inventory pressure returns them when one empty slot remains. Fuel checks, explicit pauses
and recovery can still dock early. Temporary no-work replies and route failures wait and retry locally.
At unload, retain four planting items for the current batch and one for each other
outstanding replant or vulnerable last plant. Other planting items and byproducts go to
output. This replaces the old reserve of four items for up to eight unrelated crop types.

"Learning" here is explicit bookkeeping and adaptive revisit intervals, not an LLM or neural
network. A\* minimizes movement steps in the surveyed map; it does not optimize turtle turns or
guarantee globally optimal scheduling of the whole farm.

No navigation digging or attacks are used. Turtles move vertically without ladders. Doors,
ladders, water, crops and other non-air blocks are conservatively treated as obstacles, even if a
player could pass them. Leave air openings/aisles between your indoor and outdoor farms. Two
turtles may need a passing space in narrow corridors.

## Durability model

- Controller debts are written to disk **before** harvest authorization, so a crash cannot lose
  the obligation to replant.
- The worker keeps an unacknowledged-transaction journal. Restart recovery hands unfinished work
  back to the controller without requiring you to insert a missing seed.
- Duplicate RPCs are response-cached per `worker:session:sequence`, so a retried request never
  mutates the ledger twice. Heartbeats reuse a sentinel sequence and are deliberately excluded
  from that cache.
- Leases expire after 120 seconds; a reconnecting worker recovers its existing assignment rather
  than acquiring a second one.
- Saved data lives under `farm/data/`. Do not delete it to fix an ordinary error.
- Positions unseen for seven days are pruned from history so abandoned crops cannot fill the
  disk.
- Disk-write failure prevents authorization rather than silently losing the journal. Very large
  farms may need a higher CC computer disk limit.

## Runtime constraints

Everything under `farm/` runs inside CC:Tweaked's Lua sandbox (Lua 5.2-flavoured Cobalt) with no
external libraries. The controller multiplexes seven cooperative loops with
`parallel.waitForAny`; anything that blocks without yielding stalls the RPC service the turtles
depend on. The advanced computer terminal is 51 columns by 19 rows, which is why console output
is written to fit 51 columns.

Module map, code style, test discipline and the release process are documented in
[CLAUDE.md](../CLAUDE.md).

## Server resource notes

The target server uses an Advanced Peripherals maximum paid scan radius of 32 and has powered
peripherals disabled, so its stationary scanner does not need FE. Other servers should check
their own scanner settings and energy requirements. The installer does not edit server
configuration.

The target server has 64 MiB disk per computer/turtle, 2 MiB file uploads, a 10 ms ideal
per-computer main-thread task budget and a 20 ms global task budget. Monitor limits remain 8 x 6;
existing monitor bandwidth is sufficient for both walls. Administrators configuring another
server should back up their configuration before changing limits. These are the deployment's
resource settings, not measured minimum requirements.

## The two war-room walls

Build each wall from Advanced Monitors facing the same direction: six across and six high for the
map, six across and five high for statistics. Connect one enabled wired modem to each assembled
wall and cable it into the controller's existing wired network. They are automatically detected,
including walls connected after the controller starts.

At text scale 0.5, the 6 x 6 map wall provides 121 x 81 character cells. The current UI leaves a
117 x 65 map area, enough for distinct positions across the entire 65 x 65 survey floor. The
statistics wall provides 121 x 67 character cells. The layouts also support other sizes,
including two 8 x 6 walls.

The first discovered wall defaults to the map; the second defaults to operations. Assignments and
view settings survive controller reboots. Both wall programs execute on the controller; the
monitors do not need computers, wireless modems, or their own installers.

### Map wall

- Top-down survey of the selected crop-height layer, with terrain/bed context.
- Crop markers distinguish last-seen ready/growing, unknown/stale, unsupported, excluded,
  in-flight operations and remembered replant gaps.
- Numbered turtle markers and current issued routes; gray cached-route overlay with an on/off
  touch control. Cached routes are historical successful plans, not guarantees that a path
  remains clear. The overlay is capped at 16,000 visited nodes per frame.
- Nearby players as facing arrows (`^ v < >` derived from yaw, north-up). The player nearest the
  controller is highlighted and captioned `YOU ARE HERE`, on the assumption that whoever is
  closest to the controller is the person standing at the screens; the caption reports how many
  floors away they are when they are not on the displayed layer. Requires a Player Detector, and
  reports exact coordinates only where the server leaves `enablePlayerPosRandomError` off.
- Touch controls for detected floors, zoom, panning, reset-to-auto, and selecting a crop for
  coordinates and observation details. Indoor and upper-floor beds are separate layers rather
  than being misleadingly stacked on the same map.

### Operations wall

- Current controller-session uptime, accumulated recorded controller uptime and session count.
- Durable lifetime harvest actions, confirmed replants, deferred replants, errors/path failures
  and successful survey count. These counters are independent of the seven-day per-position
  history and start when this telemetry version is first run; they do not invent historical
  totals from before installation.
- Current living/gap counts per crop type, last-observed maturity counts, lifetime harvests per
  type, and touch pagination when the list exceeds the wall height.
- Worker connection age/status, coordinates and fuel; current cached-route count and cache hits;
  recent activity.

Both walls refresh every two seconds and only changed text rows are transmitted. Positions arrive
via worker telemetry (normally within five seconds); full surveys normally run every 120 seconds.
**Crop maturity is last observed by a turtle, not a magical continuously live scanner value.**
Observations older than three scan intervals are labeled stale. Uptime counts the running
controller, including pauses, excludes offline periods, and may lose the final unsaved fraction
of a minute after abrupt shutdown. Lifetime harvests are actions, not harvested item quantities.

All clickable controls are rendered on the bottom one or two rows, because a tall monitor wall
puts the top rows out of a player's reach in game.

To generate local layout previews from the actual renderer with **simulated data**, run
`lua tests/build_dashboard_preview.lua`, then open `dashboard-map-preview.html` and
`dashboard-stats-preview.html`. These previews are not screenshots of a real farm.

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
| BWG blueberries and aloe | Right-click mature plants with a retained stick; preserve bush/aloe base; interaction datapack required |
| Vanilla sweet berries | Mature harvest/replant with berries |
| Cocoa | Mature pods attached to jungle logs; attachment-aware placement |
| Sugar cane | Clear every upper block in one visit, preserve one root; tagged sand/dirt and mud |
| Melons and pumpkins | Harvest fruit blocks wherever present, as requested; stems remain untouched |
| Nether wart | Mature harvest/replant on soul sand |
| Torchflower and pitcher crop | Recognize mature plants and planting items; need external sniffer seeds/pods for sustainable repeated harvesting |
| Cactus | Clear every upper block from above, preserve root, accept tagged sand including BWG windswept sand |
| Bamboo | Explicitly excluded |
| Silent Gear flax/fluffy, Occultism datura, Ars magebloom, Eternal Starlight crinoa/pungency, Supplementaries flax | Audited planting items and maturity; lower-half handling where appropriate |
| Kelp | Top harvesting only where reachable from air above; submerged routes are intentionally not supported |
| Glow berries and upper rope tomatoes | Optional interaction compatibility datapack below; never broken as a fallback |

This is not a generic tree, mushroom, chorus, or every-mod-plant harvester. New unsupported
tagged crops are inspect-only. Rope-logged **base** tomatoes are currently skipped; ordinary
ground tomatoes and optional upper rope tomatoes are distinct cases.

### Optional right-click compatibility

`compat-datapack/` contains a Minecraft 1.21.1 datapack adding cave vines, upper rope
tomatoes, BWG blueberry bushes and blooming aloe to `computercraft:turtle_can_use`. It does not modify drops or enable arbitrary block
interactions. The live farm installs this compatibility pack.

To enable these optional crops, install that directory as
`world/datapacks/evolution-farmbot-interactions`, reload datapacks, and put a few ordinary sticks
in the shared bank. The worker selects a stick and uses `turtle.place*()` for the approved
interaction, checks that the plant remains, and checks that maturity changed. Without the tag, it
reports the unsupported interaction and leaves the plant intact. Blueberries and aloe require this datapack.

## Update mechanism

`check update` and `update system` are available at both the CraftOS prompt and the running
controller's `farm>` prompt. They read
[release.json](https://raw.githubusercontent.com/boredhero/evolution-farmbot/main/release.json),
compare versions, show the release notes, and require confirmation before touching anything.

- Every file is downloaded from the release **tag**, so one check can never combine files from
  different `main` commits.
- Each download is verified against the manifest's size and Adler-32 checksum. A corrupt or
  truncated download never changes the running installation.
- The old program files are backed up first; a mid-install disk failure restores them and removes
  only newly installed program files.
- `update system` at the controller first pauses the farm and waits for workers to dock. If a
  worker is still out, it refuses and tells you to try again.
- Config, crop memory, replant debts and statistics are never release targets.
- An interrupted install is finished by `startup.lua` on the next boot; recovery is idempotent.
- raw.githubusercontent serves the manifest with `cache-control: max-age=300` and ignores
  cache-busting query strings, so a release published within the last five minutes can still read
  as up to date.

New runtime modules under `farm/` are discovered automatically by `build.lua` and listed in the
manifest; generated/user data and development tests are not distributed.

## Verification

Run the complete local suite with:

```sh
bash tests/check.sh
```

It builds and syntax-checks the installer/modules, checks A\* against BFS on randomized maps,
tests full-radius paths and crop rules, exercises live-layout/replant state transitions, executes
actual worker and controller loops with mocked CC APIs, tests seed transfer and persistent
storage, verifies installer backup behavior, and asserts that every console command is
documented. These simulations are not a substitute for the in-game commissioning steps.

Local test prerequisites: Lua 5.4 (including `luac`), Bash, and ripgrep. The installed game
program uses CC's built-in Lua and does not require those packages in Minecraft.

## Sources

The crop rules were checked against the installed mod jars' blockstates, loot tables and relevant
bytecode, including BWG 2.6.0, Cottonly 0.16.6, Hexerei 0.5.0.3, Actually Additions 1.3.26,
Farmer's Delight 1.3.2, Immersive Engineering 12.4.2, Mystical Agriculture 8.0.27, CC:Tweaked
1.119.0 and Advanced Peripherals 0.7.62b.

Relevant upstream references:

- [CC monitor color, text scale and touch capabilities](https://tweaked.cc/peripheral/monitor.html)
- [CC turtle movement, inspection, placement and inventory API](https://tweaked.cc/module/turtle.html)
- [CC block details and block state](https://tweaked.cc/reference/block_details.html)
- [Advanced Peripherals Geo Scanner result format and configuration](https://docs.advanced-peripherals.de/0.7/peripherals/geo_scanner/)
- [CC GPS constellation setup](https://tweaked.cc/guide/gps_setup.html)
- [Wired inventory transfers](https://tweaked.cc/generic_peripheral/inventory.html)
- [Maintainer discussion of the 1.21 turtle-use tag regression](https://github.com/cc-tweaked/CC-Tweaked/issues/2011) and [the corresponding fix](https://github.com/cc-tweaked/CC-Tweaked/commit/4710ee5bcc4c8d256d6dfe477450911a00915b60)
- [BWG's upstream 1.21.1 project](https://github.com/Potion-Studios/Oh-The-Biomes-Weve-Gone/tree/1.21.1)

### Soil tags, map and harvest routing

Discovery accepts semantic Minecraft/common/legacy Forge sand, dirt and farmland tags, including
NeoForge villager farmlands, with vanilla/MA fallbacks. Tags such as `maintains_farmland` are not
soil tags and are not accepted. Unsupported crop identities remain inspect-only.
AUTO projects crops from all heights; manual Y controls isolate a floor. Blue worker numbers are
independent of the red player arrow, and the legend includes actual XYZ coordinates.
Verified harvest results update occupancy immediately, allowing side approaches through newly
cleared rows beneath torches without waiting for another scanner sweep.

### Seed crafting

`seed_recipes.lua` catalogs verified one-ingredient pack recipes. `crafting.lua` handles an empty
vanilla Crafter with a durable insertion/output journal. The controller automatically discovers
and leases machines. Workers approach the output face, insert one ingredient, pulse redstone and
verify the seed output. An interrupted or unexpected recipe never silently consumes another input.

### Composting and estimated growth

`compost.lua` derives eligible quantities only for actual planting seeds from completed batches,
excluding in-flight leases and replant debts. It preserves at least 16 seeds across available bank
stock and the worker, plus any larger worker reserve. Workers discover the nearest vanilla composter,
use the game's own compostability checks, empty finished compost into bone meal, and send output to ME.
Unsupported seeds, unavailable machines and low fuel fall back to normal unloading. No ME extraction
or deletion of arbitrary items is performed. Add `minecraft:composter` to the interaction datapack.

`growth.lua` learns smoothed durations from observed planting-to-ripe harvest cycles. It estimates
remaining time from last-inspected age, explicitly including sampling delay and possible offline time.
Old maturity observations remain visible, dimmed; `e` marks estimated ripe, never an inspected ripe
state. Workers always inspect and authorize actual maturity. New crop types show learning until a
measured cycle is available.

### Exclusive crop rounds and shared fleet cycles

The controller persists `batches.owners`, `workers`, `pending`, `visited`, `finished` and `cycle`.
One round is one crop type assigned exclusively to one worker; all rounds form a shared fleet cycle.
Assignments are saved before dispatch, but locations become checked only on acknowledged results.
Releasing a job for fuel or a route budget restores eligibility without releasing crop ownership.
After reboot, transient lease tokens reset while pending plants and crop ownership persist.
Repair work respects other workers' crop ownership. Completed types cannot be reopened by another
worker until all accessible types finish. Growing-plant inspection timers never filter a round;
physical route failures may still cool down. Column crops have a stable root-based visit identity.

`pickup.lua` collects loose items from air and recognized plants only, never arbitrary inventories.
Workers opportunistically collect along movement, then sweep a deduplicated 3x3 neighborhood around
harvested plants before changing crop types or unloading. Collection goals preserve their actual Y
levels and use crop roots for tall columns. Routes remain non-destructive and return-fuel-budgeted.
New sugar cane/cactus growth blocking an old top approach updates the target and raises the approach,
without changing the job token/root identity. Obstacles immediately update controller occupancy.

Lifetime statistics: tap **STATS** at the bottom of either monitor. The page preserves lifetime farm harvest/replant totals and shows favorite crops, controller uptime, scans, and individual bot harvests, replants, inspections, errors and blocks traveled. PREV BOT/NEXT BOT includes offline bots; MAP returns to the farm. Per-bot attribution and travel begin with v0.4.1; older totals are not retroactively assigned. Counts are harvest actions, not item yields.

For soil recovery, put a hoe in each worker inventory. Hoes are retained during unloading. If replanting a known farmland crop fails, the worker inspects the soil beneath the empty planting cell, uses a carried hoe on tagged dirt, verifies farmland, then retries planting. Two uses allow coarse/rooted dirt conversion; game rules decide whether modded soil is tillable. Existing crops, non-dirt supports and special-support crops are preserved. Errors distinguish the planting coordinate from the soil coordinate. A missing hoe leaves the repair debt pending.

Vine maintenance runs during crop visits: ordinary minecraft:vine blocks in the crop column up to three blocks above it are cleared top-down. A vine occupying a remembered replant gap is also removed, with the planting debt preserved. Other blocks, glow-berry vines and neighboring columns are untouched. New vines are discovered by regular scans or inspected route obstacles; inspection-only mode never clears them.

Fleet responsiveness: the controller uses linear crop-population counts and small atomic mutation records between full checkpoints, including recovery from the backup snapshot. Synthetic tests cover 16 workers and 4096 plants; live capacity depends on farm layout and hardware. Workers reserve the next movement cell, report positions every second, favor routes away from other upcoming paths, and wait or back out when blocked. Turtle encounters use short-lived avoidance instead of rescanning the entire farm. Per-operation latency samples are recorded in farm/data/performance every 30 seconds.

Workers persist their unfinished crop assignment, current round, pickup queue and required docking work. On reboot they locate themselves with GPS and request their unfinished crop first; an established worker does not return home just because it restarted. A completed crop transitions directly to the next available type. Ordinary RPC retries start after one second; movement-permission retries after half a second. A dedicated receiver preserves incoming messages while a single ordered handler processes durable mutations; heartbeat and traffic replies bypass expensive searches.

Pathfinding uses numeric voxel indices and cooperative queued-event yields, not timer sleeps. Valid routes survive crop inspections and relax planned traffic avoidance only when it changes the search. Fuel refills target 8000 stored movement fuel (within the turtle limit) plus one carried backup stack, replenished when visiting the fuel chest. Carried fuel is consumed automatically as needed. No new configuration switches are required.

Surveyed connectivity is cached independently of worker traffic. Identical scans retain it; occupancy changes invalidate it. Completed components reject unreachable destinations before repeated A* searches. Slow routes retain bounded diagnostics for live profiling.

Crops below torches can be reached through a freshly harvested neighboring crop: the worker steps into that gap, inspects and harvests the blocked same-crop neighbor, then retreats and replants the gap. Both planting obligations are durable. This requires a single-block replant crop in the same unfinished round and two carried planting items; it does not remove torches, uproot immature neighbors, or take another worker's crop round.

Block tag lookup accepts both normal identifiers (c:sands) and Advanced Peripherals 0.8 registry-qualified identifiers (minecraft:block/c:sands), in list or boolean-map form. This is shared by sand, dirt, farmland, crop and interaction checks.

Fleet compacting preferences live in controller state.settings.compacting, with individual explicit opt-in keys. The shared seed_plan includes recipes only after subtracting planting reserves and produce needed for seed conversion. Workers refresh this plan before each craft, obtain the existing exclusive Crafter reservation and process one 9:1 recipe at a time before unloading. compact_crafting inserts single items to populate all nine slots, validates the entire grid, pulses once and verifies the output delta. Durable inventory baselines distinguish partial insertion from completed output after a restart. Disabled grids or failed recipes return owned inputs when their counts remain verifiable; unexpected contents retain the recovery journal. Vanilla carrot, potato and beetroot crates are deliberately omitted because this pack removes those crafting recipes.

The controller retains 512 routes by default, configurable in Settings to 32, 64, 128, 256, 512 or 1,024 routes and evicts the least recently used entry at capacity. Each reuse validates current geometry and fleet traffic. The map previews at most 128 cached routes and 16,000 route points per frame, independently of retention. Keys still require an exact start and destination list.
