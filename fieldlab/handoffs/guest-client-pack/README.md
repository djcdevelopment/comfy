# Comfy × Valheim — Guest Client Setup

You've been invited to join a modded Valheim world (`ComfyEra16`) that runs on our experimental
**network-cutover** stack: your connection is admitted and partly routed through our own gateway
(Lumberjacks) instead of vanilla Valheim alone. This guide gets you connected and shows you how to
see it working. ~10 minutes.

## What you need first

- **Your own licensed copy of Valheim on Steam.** You must use a *different* Steam account than the
  host — Valheim allows one session per license, so we can't share one account.
- Valheim updated to the current build (**0.221.12** at time of writing). Modded clients must match
  the server's version.
- The **join password** for the server — the host will send this to you directly. It is *not* in
  this pack.
- Server address (already filled in below): **`8.231.129.249:2456`**

## 1. Install BepInEx (the mod loader)

We can't redistribute BepInEx, so grab it from Thunderstore — it's the standard Valheim mod loader:

- Download **BepInExPack Valheim 5.4.2202** from
  <https://thunderstore.io/c/valheim/p/denikson/BepInExPack_Valheim/> (use version **5.4.2202**).
- Extract the archive and copy the **contents of its `BepInExPack_Valheim` folder** (the `BepInEx`
  folder, `doorstop_config.ini`, `winhttp.dll`, `start_game_bepinex.sh`, etc.) directly into your
  Valheim install folder — the one that contains `valheim.exe`. Typically:
  `C:\Program Files (x86)\Steam\steamapps\common\Valheim\`
- Launch Valheim once from Steam, reach the main menu, then quit. This first run generates the
  `BepInEx\plugins` and `BepInEx\config` folders.

> Prefer a mod manager? r2modman / Thunderstore Mod Manager also work — install the BepInExPack,
> then add `ComfyNetworkSense.dll` (next step) as a local mod.

## 2. Install the ComfyNetworkSense mod

- Copy **`ComfyNetworkSense.dll`** (included in this pack) into:
  `...\Valheim\BepInEx\plugins\`
- That's it. On the next launch the mod generates its own config with **safe defaults** — HUD on,
  no automation, no behaviour changes. You do **not** need a config file; nothing to edit.

## 3. Connect

1. Start Valheim from Steam (with BepInEx installed it loads the mod automatically — you'll see a
   console window and the NetworkSense HUD appears).
2. Pick or create a character.
3. **Start Game → Join Game → Join by IP →** `8.231.129.249:2456`
4. Enter the **join password** the host gave you.

You should spawn into `ComfyEra16` alongside the host.

## 4. See the cutover (and fly around)

The mod adds console commands (press **F5** to open the console). Useful ones:

- `network_sense_hud` — toggle the NetworkSense HUD overlay.
- `network_sense_panel` — open the debug drawer (network signals, telemetry).
- `network_sense_status` — print current state.
- `network_sense_godfly on` / `network_sense_godfly off` — **god mode + fly**, so you can zip around
  the world and follow the host. (The normal `god`/`fly` commands are blocked for clients on a
  dedicated server; this one works around that by design.)
  - With fly on: **jump** to rise, **crouch** to descend.

## What's actually happening (the "cutover")

- When you connected, the **admission decision** (are you allowed in, version/slot/duplicate checks)
  was answered by our **Lumberjacks gateway**, not vanilla Valheim's own handshake logic — a Harmony
  hook on the server intercepts your join and asks the gateway.
- During test windows, a tagged class of world objects is **redirected** to the gateway instead of
  being sent the vanilla way, and the gateway counts them as receipts.
- Your Valheim client itself is normal — the interception lives on the **server**. You're seeing our
  netcode layer sit *in front of* a real Valheim session. The HUD is your window into it.

Password/Steam sign-in are never handled by any of this — you log into Steam yourself and type the
join password yourself, exactly like any Valheim server.

## Troubleshooting

- **"Incompatible version" on join** → your Valheim isn't 0.221.12, or BepInEx/the mod didn't load.
  Confirm the console window appears at launch.
- **Rejected / can't connect** → double-check the IP:port and password; ask the host to confirm the
  server is up and (if the whitelist is on) that your SteamID was added.
- **No HUD** → run `network_sense_hud` from the F5 console.
