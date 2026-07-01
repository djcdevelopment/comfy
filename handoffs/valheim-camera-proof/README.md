# Valheim camera proof kit

This kit answers the blocking question before building the full flight-path mod:

> Can this machine load the target world, load a BepInEx plugin, see `Player.m_localPlayer`, move the
> player/camera to waypoint coordinates, and write proof files?

Do this before Segment 3. If any step fails, fix that environment problem first.

## 1. Prepare a disposable world copy

From the repo root:

```powershell
.\handoffs\valheim-camera-proof\prepare-world-copy.ps1 -WorldName ComfyEra16
```

This copies `erasave/ComfyEra16.db` and `erasave/ComfyEra16.fwl` into Valheim's local worlds folder.
The source files are not modified.

## 2. Load the world manually

1. In Steam, set Valheim launch options to `-console`.
2. Launch Valheim.
3. Start Game, pick or create a character, select `ComfyEra16`, and enter the world.
4. Press `F5`, then run:

```text
devcommands
god
fly
```

Done means the world opens and you can move freely in fly mode.

## 3. Install BepInEx

Install Thunderstore's BepInExPack Valheim into the Valheim install folder, then launch once. Done
means this folder exists:

```text
C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\plugins
```

## 4. Build and install the smoke plugin

After BepInEx is installed, use Visual Studio Build Tools, Rider, or another C# compiler to build
`ComfyCameraProof.csproj`. If `dotnet` is available:

```powershell
.\handoffs\valheim-camera-proof\build-and-install.ps1
```

The script copies the built DLL into:

```text
C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\plugins
```

If `dotnet` is not available on the machine, open the project in an IDE or install the .NET SDK /
Build Tools. This checkout currently does not have a compiler on `PATH`.

Copy the waypoint fixture or real output into BepInEx config before testing `F9`:

```powershell
Copy-Item .\waypoints.json "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\waypoints.json"
```

## 5. In-game proof

Enter the copied world with BepInEx installed:

- `F8`: writes a status proof file.
- `F9`: teleports to the first waypoint in `waypoints.json`, then writes a movement proof file.

The F5 console equivalents are more reliable while iterating:

```text
comfyproof_status
comfyproof_move
```

For a fast empty-world inner loop, skip `waypoints.json` and pass explicit coordinates:

```text
comfyproof_tp 0 80 0
comfyproof_tp 100 80 100
comfyproof_move 0 80 0
```

For an overnight still-capture pass against `waypoints.json`:

```text
comfyproof_stills 10 12
```

That captures up to 10 waypoints, waiting 12 seconds after each move before taking the screenshot.
Outputs go to:

```text
BepInEx\config\comfy-gallery-proof\
```

To amortize each expensive jump/load, capture multiple moods before moving to the next waypoint:

```text
comfyproof_variantstills 10 20 basic
comfyproof_variantstills 10 20 weather
```

`basic` captures morning/noon/sunset/night clear variants. `weather` captures clear, misty, rain, and
storm variants. The timer is conservative: after each move, the plugin waits for the player position
to stabilize, then waits the requested settle seconds, then starts capturing variants.

Manual environment controls:

```text
comfyproof_envs
comfyproof_env Clear
comfyproof_env Rain
comfyproof_env ThunderStorm
comfyproof_env noforce
comfyproof_time 0.5
comfyproof_time off
comfyproof_hideplayer on
comfyproof_hideplayer off
```

Still capture hides the local player model by default during screenshots.

Manual composition mode:

```text
capture
capture weather
comfyproof_capture basic
```

Frame the shot yourself, then run `capture`. The plugin stays at the current position, hides the
local player during screenshots, cycles through the selected mood variants, and writes a timestamped
folder under:

```text
BepInEx\config\comfy-manual-captures\
```

Use the large Era16 save only for final verification that real waypoint coordinates land near visible
builds. Use an empty local world for plugin mechanics, camera movement, timing, and file-output tests.

Expected proof files:

```text
C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-camera-proof-status.json
C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-camera-proof-move.json
```

Done means the status file says `player_present: true`, and the movement file contains the target and
result positions.

## Why this exists

The full Segment 3 mod is only worth building after these primitives work:

- the world save loads
- BepInEx loads plugins
- `Player.m_localPlayer` exists once in-world
- plugin code can move the player/camera
- plugin code can read/write local files
- extracted coordinates land near visible builds
