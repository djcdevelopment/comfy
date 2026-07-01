# Replicating the Valheim camera proof

This tutorial explains how to reproduce the camera-proof workflow we built from the handoff notes:
load a copied Valheim world, install BepInEx, run a small proof plugin, jump to extracted build
hotspots, control weather/time, and capture still images.

The important lesson is that the useful product was not the first idea, "make a perfect flythrough
video." The useful product became a controllable in-game camera assistant: the agent moves the player
to high-value coordinates, the human composes the shot, and the plugin captures weather/time variants.

## What this uses

- **Valheim local worlds**: copied `.db` / `.fwl` saves under
  `%USERPROFILE%\AppData\LocalLow\IronGate\Valheim\worlds_local`.
- **BepInExPack Valheim**: the mod loader installed into the Valheim game folder.
- **A small C# BepInEx plugin**: `ComfyCameraProof.dll`, built from this folder.
- **Valheim console commands**: enabled by launching Valheim with `-console`.
- **`waypoints.json`**: ranked world coordinates produced upstream from build-density/ownership data.
- **Unity/Valheim APIs**:
  - `Player.m_localPlayer` to find the local player.
  - direct `transform.position` placement for reliable camera/player movement.
  - `ZoneSystem.instance.GetGroundHeight(...)` for basic height checks.
  - `EnvMan.instance.SetForceEnvironment(...)` plus debug time fields for weather/time control.
  - `ScreenCapture.CaptureScreenshot(...)` for PNG stills.

## What this proves

Before investing in a full flight-path mod, this proof answers the risky questions:

1. Can the target save load in a local Valheim client?
2. Can BepInEx load a plugin in that client?
3. Can plugin code see `Player.m_localPlayer` after entering the world?
4. Can plugin code move the player/camera to absolute world coordinates?
5. Can plugin code control environment/time enough to make visual variants?
6. Can the workflow capture useful images from real extracted hotspots?

Once those are true, the pipeline has a practical path even if continuous video is too fragile.

## Why the workflow changed

The initial target was a continuous flythrough video. In practice, large world jumps in Valheim can
trigger loading screens, render stalls, player recreation, zone generation, and heavy ZDO cleanup. A
continuous video across distant world coordinates is therefore brittle.

The stronger workflow is:

1. Jump the operator to a ranked hotspot.
2. Let the human compose the shot in fly mode.
3. Run `capture` to collect time/weather variants from that exact perspective.
4. Repeat for the next hotspot.

This keeps the human in charge of aesthetics and lets the plugin do the repetitive mechanical work.

## Files in this kit

```text
handoffs/valheim-camera-proof/
  README.md
  TUTORIAL.md
  prepare-world-copy.ps1
  build-and-install.ps1
  ComfyCameraProof.csproj
  Plugin.cs
```

The plugin installs to:

```text
C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\plugins\ComfyCameraProof.dll
```

The waypoint input is copied to:

```text
C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\waypoints.json
```

## Setup

### 1. Copy the world save safely

Never load the source `.db` / `.fwl` directly. Copy it into Valheim's local worlds folder:

```powershell
.\handoffs\valheim-camera-proof\prepare-world-copy.ps1 -WorldName ComfyEra16
```

### 2. Install BepInEx

Install Thunderstore's BepInExPack Valheim into:

```text
C:\Program Files (x86)\Steam\steamapps\common\Valheim
```

The install is correct when this exists:

```text
C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\core\BepInEx.dll
```

### 3. Build and install the plugin

With .NET SDK installed:

```powershell
.\handoffs\valheim-camera-proof\build-and-install.ps1
```

If `dotnet` is not on PATH but installed normally, use:

```powershell
& "C:\Program Files\dotnet\dotnet.exe" build .\handoffs\valheim-camera-proof\ComfyCameraProof.csproj -c Release -p:ValheimDir="C:\Program Files (x86)\Steam\steamapps\common\Valheim"
Copy-Item .\handoffs\valheim-camera-proof\bin\Release\net472\ComfyCameraProof.dll "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\plugins\ComfyCameraProof.dll" -Force
```

### 4. Copy waypoints

```powershell
New-Item -ItemType Directory -Force "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config" | Out-Null
Copy-Item .\waypoints.json "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\waypoints.json" -Force
```

### 5. Launch Valheim with console enabled

```powershell
Start-Process -FilePath "C:\Program Files (x86)\Steam\steamapps\common\Valheim\valheim.exe" `
  -ArgumentList "-console" `
  -WorkingDirectory "C:\Program Files (x86)\Steam\steamapps\common\Valheim"
```

In Steam, you can also set launch options permanently to:

```text
-console
```

## First proof: empty world

Use a small empty local world first. It gives a fast inner loop and proves the plugin mechanics without
Era16's load cost.

After entering the world, press `F5` and run:

```text
devcommands
god
fly
comfyproof_status
comfyproof_tp 0 80 0
comfyproof_tp 100 80 100
```

Expected proof files:

```text
C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-camera-proof-status.json
C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-camera-proof-move.json
```

`status.json` should show:

```json
{
  "plugin_loaded": true,
  "player_present": true,
  "waypoints_exists": true
}
```

`move.json` should show `ok: true` and an `after` position near the target.

## Batch capture test

In the empty world, test automated variants:

```text
comfyproof_variantstills 1 8 basic
```

Then scale slightly:

```text
comfyproof_variantstills 3 10 basic
```

Output:

```text
C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-gallery-proof\
```

The `basic` variant set captures:

- `morning_clear`
- `noon_clear`
- `sunset_clear`
- `night_clear`

The `weather` variant set captures:

- `clear_day`
- `misty_morning`
- `rain_day`
- `storm_night`

## Era16 proof

Load `ComfyEra16`. Expect the first load to be slow. A 1.3 GB save can show "not responding" while
Valheim connects portals, loads locations, generates terrain, and rebuilds state.

Run a small Era16 test first:

```text
devcommands
god
fly
comfyproof_hideplayer on
comfyproof_variantstills 1 45 basic
```

If that works, test three waypoints:

```text
comfyproof_variantstills 3 45 basic
```

Large-world symptoms that are expected:

- black screen or spinner during long-distance movement
- 1-2 second hard stops
- `Destroyed invalid prefab ZDO...` log spam
- `Loading dungeon`, `Force generating hmap`, and item attach-prefab warnings

Those are Valheim main-thread stalls from the large/modded save, not disk or memory pressure in the
observed run.

## Manual composition mode

This is the preferred production workflow.

Jump to a hotspot:

```text
comfyproof_tp 3290.2 80 2257.4
```

Then fly/rotate manually until the composition is good. Run:

```text
capture
```

For weather variants:

```text
capture weather
```

Output:

```text
C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-manual-captures\<timestamp>\
```

Each folder contains PNGs and `capture.json`.

This mode does not move the player. It captures the exact perspective the human chose.

## Useful commands

Movement:

```text
comfyproof_tp x y z
comfyproof_move
comfyproof_move x y z
```

Status:

```text
comfyproof_status
```

Hide/show local player:

```text
comfyproof_hideplayer on
comfyproof_hideplayer off
```

Weather/time:

```text
comfyproof_envs
comfyproof_env Clear
comfyproof_env Rain
comfyproof_env ThunderStorm
comfyproof_env noforce
comfyproof_time 0.25
comfyproof_time 0.5
comfyproof_time 0.72
comfyproof_time 0.9
comfyproof_time off
```

Automated captures:

```text
comfyproof_stills 10 20
comfyproof_variantstills 10 45 basic
comfyproof_variantstills 10 45 weather
```

Manual captures:

```text
capture
capture weather
comfyproof_capture basic
comfyproof_capture weather
```

## Troubleshooting

### F5 does not open the console

Valheim must be launched with `-console`. Relaunch with:

```powershell
Start-Process -FilePath "C:\Program Files (x86)\Steam\steamapps\common\Valheim\valheim.exe" `
  -ArgumentList "-console" `
  -WorkingDirectory "C:\Program Files (x86)\Steam\steamapps\common\Valheim"
```

Also try `Fn+F5` on keyboards where function keys are media keys.

### DLL will not overwrite

Valheim locks loaded plugin DLLs. Quit Valheim, then copy the DLL again.

### The player model appears in screenshots

Run:

```text
comfyproof_hideplayer on
```

Still and capture jobs hide the local player during screenshot calls by default.

### Era16 freezes or hard-stops

This is likely Valheim main-thread work from the huge save: ZDO cleanup, terrain generation, dungeon
loading, missing prefab cleanup, or similar. Use smaller tests and manual composition mode.

### Captures overwrite old files

Automated `comfyproof_variantstills` currently reuses names like `01_morning_clear.png`. Manual
`capture` writes timestamped folders and is safer for repeated production captures.

## How this could be used

- Build a ranked image gallery of player builds.
- Produce before/after or day/night/weather comparison packs.
- Let a curator quickly jump through hotspots found by the parser.
- Generate source media for a web gallery, Discord showcase, or event retrospective.
- Keep the human responsible for composition while automating coordinates, weather/time variants, and
  repetitive screenshot capture.

The core pattern generalizes: data finds the interesting places; a lightweight in-game tool gets the
human there; the human makes the aesthetic decisions.
