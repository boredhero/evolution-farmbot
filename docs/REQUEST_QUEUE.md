# FarmBot request queue

Append requests in conversation order. Keep superseded requests and verify deployment before marking done.

| Order | Request | State |
| --- | --- | --- |
| 1 | Fleet-wide crop batches, largest ready group first, fair finite rotation | Previously deployed; retained |
| 2 | Greedy inventory, compact stacks, dump stray items and surplus planting items | Previously deployed; retained |
| 3 | Replant mismatch fixes and audit modded crops | Deployed; tests pass |
| 4 | Generic seed conversion for supported crops with real pack recipes; detect placed Crafter | Deployed; real canola-to-seed conversion verified |
| 5 | Detect composters and cull excess seeds after completed batches | Deployed 22:38; tests pass; protects seed stock, debts and active batches |
| 6 | BWG aloe and blueberry right-click harvest | Deployed; datapack enabled |
| 7 | Cactus upper-only harvest; preserve root | Deployed; tests pass |
| 8 | Torch-obstructed crop routes; accept tagged windswept sand | Deployed; tests pass |
| 9 | Sugar cane down to one root per visit | Deployed; tests pass |
| 10 | Exclude bamboo; finish each finite crop batch before switching | Deployed; tests pass |
| 11 | Map worker accuracy and semantic farmland/dirt tags | Position concern retracted; tags deployed |
| 12 | Purple B marker | Superseded by request 15 |
| 13 | Additional workers inherit existing shared chests | Deployed; tests pass |
| 14 | AUTO map displays colored crops from all farm heights | Deployed; tests pass |
| 15 | Keep blue numbered worker markers | Deployed; tests pass |
| 16 | Retain old maturity observations instead of reverting to question marks | Deployed 22:38; tests pass |
| 17 | Learned approximate crop growth estimates | Deployed 22:38; tests pass |
| 18 | Collect scattered drops around plants without taking chest contents | Deployed; full test suite passes |
| 19 | Finish all unvisited plants of current crop across heights, including later eligibility | Deployed; full test suite passes |
| 20 | One crop round survives unloading/refueling/restarts; all other crop rounds form a fleet cycle | Deployed; full test suite passes |
| 21 | Exclusive owner per crop round, globally completed types cannot repeat on another bot | Deployed; full test suite passes |
| 22 | Sugar cane growing into its approach cell must retarget and replan above new top | Deployed; full test suite passes |
| 23 | Lifetime system and individual worker statistics with clickable stats page | Deployed to controller 4 and workers 8/9; full suite passes; both workers recorded in durable stats |
| 24 | Hoe recovery for known farmland crops on tagged dirt; report crop cell and soil separately | Deployed to 4/8/9/21; full suite and file verification pass; actual tilling awaits carried hoe and suitable gap |
| 25 | Periodically clear ordinary hanging vines a few blocks above known crop spots, including empty planting gaps | Deployed to controller and workers 8/9/10/21; full suite passes |
| 26 | Fleet traffic-aware routes, transient turtle blockage recovery and waiting/replanning | Deployed v0.5.0; server restarted and four workers resumed |
| 27 | Investigate ComputerCraft responsiveness and identify measured controller/scheduler bottlenecks | Implemented and profiled: small writes 2-5ms; mailbox, indexed paths, event yields; two Lua threads active after restart; connectivity cache follow-up in v0.5.1 |
| 28 | Keep working across crop rounds until one empty inventory slot remains; avoid unnecessary dock trips | Deployed v0.5.0; server restarted and four workers resumed |
| 29 | Longer fuel endurance and useful carried backup coal | Deployed v0.5.0; server restarted and four workers resumed |
| 30 | Reach crops under torches without removing decorations | Deployed v0.5.3 to 4/8/9/10/21; public installer and files verified; controller/worker simulations pass; live under-torch harvest not yet observed |

Deployment 2026-10-20 22:27 verified active controller/worker, shared chest coordinates, one Crafter at 1789,65,3796, six blooming aloe plots and thirteen blueberry bushes.

Deployment 2026-10-20 22:38: composting, persistent observation symbols and learned estimates installed on computers 4 and 9; composter interaction tag loaded. Backup: `/home/noah/minecraft/farmbot-backups/crop-crafting-map-20261020-223704`. Reloads must be announced in advance.

Final runtime deployment: 2026-10-20 23:01, backup `/home/noah/minecraft/farmbot-backups/exclusive-crop-rounds-20261020-230120`. Controller active, cycle 1 / round 1 owned exclusively by worker 9 (wheat), 19 checked plants at verification. Live canola-to-seed conversion previously verified. Subsequent work is tracked in the numbered queue above.

Requests 26-29 also include durable assignment resume across restarts, removal of temporary no-work/route-failure docking, one-second RPC retry and half-second movement retry. Final release must be pushed and deployed before restarting the server.

2026-10-21 verification: v0.5.0 published and deployed before Minecraft restart; service resumed with computer_threads=2. Four workers resumed in the farm. v0.5.1 public installer and deployed file hashes verified. First minute: job assignment max28ms, movement permission max1ms, mutation journal max6ms; startup route max1103ms, routes in the second 30-second sample averaged18ms. Sixteen-worker simulations pass; live fleet has four workers.

Follow-up evidence after v0.5.3 deployment: live routes to shared docks can still hit the 60,000-node limit twice (soft/hard traffic), taking roughly 3 seconds. Fast movement replies remain responsive. Keep this routing follow-up open; the earlier short sample did not cover these crowded-dock cases.

31. Cactus on BWG windswept sand: live scanner uses minecraft:block/c:sands and minecraft:block/minecraft:sand. Shared tag lookup now accepts registry-qualified AP tags and normal turtle tags. Deployed v0.5.4 to 4/8/9/10/21; public main/tag installer and all runtime hashes verified. Live controller now discovers all seven cactus columns at Y=68 with roots Y=66; Subsequent live inventory confirmed worker 9 carrying 12 cactus. Full suite passes, including regression against the actual scanner tag format.

32. Fleet Settings menu and optional crop compacting: eight verified 9:1 conversions, planting-stock protection, Crafter discovery and concurrency, durable craft recovery. Deployed v0.6.0 to controller 4 and workers 8/9/10/21; full suite and public installer/runtime hash checks pass. Live worker 9 used Crafter 1789,65,3796: wheat 25->16, hay 0->1, wheat seeds unchanged at40; worker startup restored and farming resumed. All settings start off.
33. Additional Crafters automatically discovered and used: existing nearest-free station selection retained; all nine slots required for compacting.

34. Increase route retention: 128 -> 1,024, retaining occupancy/traffic validation and least-recently-used eviction. Map preview bounded independently. Deployed v0.6.1 to 4/8/9/10/21; full suite passes; all runtime and public main/tag installer hashes verified. No Minecraft restart required.
