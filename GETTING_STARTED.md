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

## 3. Place the controller and Geo Scanner

Put your Advanced Computer roughly between the farms. Attach one Ender Modem and place the Geo Scanner **directly against the computer**. Record the scanner block's Targeted Block coordinates.

The scanner reaches 32 blocks in each direction, including vertically. Both farms and the paths between them need to fit in that cube. The scanner stays still; the turtles travel.

Install the program on this computer using the same command, but finish the physical wired network below before completing the controller wizard. You can also wait to install until step 6.

## 4. Build both turtle docks

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

The map updates every two seconds; maturity is what a turtle last inspected. A full survey normally runs every 120 seconds, so newly planted areas may take up to that long to appear.

## 9. Enable harvesting, then add the second turtle

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
