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
| BWG blueberries; vanilla sweet berries | Mature bushes on grass; harvest and replant with berries |
| Cocoa | Mature pods attached to jungle logs; attachment-aware placement |
| Sugar cane | Top-down harvesting above an intact root on sand/red sand |
| Melons and pumpkins | Harvest fruit blocks wherever present, as requested; stems remain untouched |
| Nether wart | Mature harvest/replant on soul sand |
| Torchflower and pitcher crop | Recognize mature plants and planting items; need external sniffer seeds/pods for sustainable repeated harvesting |
| Bamboo and cactus | Top harvesting with root retained; conservative soil rules |
| Kelp | Top harvesting only where reachable from air above; submerged routes are intentionally not supported |
| Glow berries and upper rope tomatoes | Optional interaction compatibility datapack below; never broken as a fallback |

This is not a generic tree, mushroom, chorus, or every-mod-plant harvester. New unsupported
tagged crops are inspect-only. Rope-logged **base** tomatoes are currently skipped; ordinary
ground tomatoes and optional upper rope tomatoes are distinct cases.

### Optional right-click compatibility

`compat-datapack/` contains a Minecraft 1.21.1 datapack adding only cave vines and upper rope
tomatoes to `computercraft:turtle_can_use`. It does not modify drops or enable arbitrary block
interactions. **It is prepared locally, not installed on the server.**

To enable these optional crops, install that directory as
`world/datapacks/evolution-farmbot-interactions`, reload datapacks, and put a few ordinary sticks
in the shared bank. The worker selects a stick and uses `turtle.place*()` for the approved
interaction, checks that the plant remains, and checks that maturity changed. Without the tag, it
reports the unsupported interaction and leaves the plant intact. Blueberries do not require this
datapack.

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
