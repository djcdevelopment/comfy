# Handoff (Claude) — 2026-07-04

NetworkSense baseline-matrix session. Continues the Comfy comms-layer research
that was already underway with Codex. Read this before picking the work back up —
especially the "What was already working" and "Lessons learned" sections, because
this session took a long detour that a future agent should not repeat.

## 2026-07-07 Codex update

- ComfyNetworkSense is now 0.4.7 in source and the live Valheim/autonomous DLL
  copies were updated to assembly version `0.4.7.0`.
- The manual shadow proof passed earlier with `network_sense_lumberjacks_shadow`
  (`pass_shadow_movement_observed` in
  `fieldlab/runs/20260707-205433-valheim-lumberjacks-shadow-authority`).
- Added the route-backed command:
  `network_sense_lumberjacks_shadow_route teleport-route.tsv movement_only ws://127.0.0.1:4000 region-spawn`.
  It reuses the existing 6-stop Era16 teleport route, starts/stops a Lumberjacks
  shadow authority window at each stop, applies the existing small movement
  pattern during each benchmark, and tags rows in `lumberjacks-shadow.jsonl` with
  `run_label=shadow_route`, `route_stop_id`, and `route_phase`.
- Added FieldLab packet:
  `fieldlab/scenarios/valheim-lumberjacks-shadow-route.yaml` with command plan
  `fieldlab/command-plans/valheim-lumberjacks-shadow-route.ps1`.
  Staged run:
  `fieldlab/runs/20260707-210807-valheim-lumberjacks-shadow-route`.
  Current status is `staged_waiting_for_shadow_route`: route file, Lumberjacks
  health, installed mod version, and packet validation pass; no route-tagged rows
  yet because the in-game command still needs to run on the restarted 0.4.7 mod.

## The goal (unchanged)

Produce a **wide, known baseline** — server + client — across the Era16
density/pressure matrix, collected via the local MCP gateway, so that when real
human volunteers are invited they spend time on the cells where human variance
actually matters, not on setup discovery. "Matrix math on matrix math": cross the
modeled matrix (derived from the real save) with measured telemetry so every
combination has a value before anyone plays.

## What was already working (Codex, before this session)

The morning run packets in `fieldlab/runs/` (08:08–09:24) are the proof:

- `era16-density-pressure-matrix` — **the modeled backstop**. From the real Era16
  DuckDB cache it computes a **9,600-row** pressure matrix
  (6 density_bands × 5 actor_players × 4 observer_ranges × 4 rtt × 5
  server_process_ms × 4 event_profiles), each row keyed to real save density
  (build/total ZDOs, containers, creators) with modeled network expectations
  (estimated_udp_kbps, event rates, priority_expectation). Output:
  `telemetry/era16-pressure-matrix.csv`. **This is the wide known backstop and it
  already exists.**
- `valheim-era16-volunteer-readiness-baseline` — gate check before inviting
  volunteers. Latest = `baseline_ready_with_warnings`, **11/14 gates pass**,
  0 failed, 3 warnings (all connected-dimension: continuous window ≥30min,
  server pulses, live server visibility).
- `valheim-era16-teleport-rehearsal` — the in-game capture, staged
  (`rehearsal_ready_not_running`). The desktop client runs the 6-stop density
  route and writes per-cell benchmarks to local JSONL.

**The working strategy is simple and does not need a container swarm:** desktop
Valheim (mod installed) runs the teleport route in the Era16 world → per-cell
telemetry lands in the local JSONL (`.../BepInEx/config/comfy-network-sense/`) →
`run-experiment.ps1` scenarios read it → matrix + readiness packets. Per
`network/mcp/AGENTS.md`: *"JSONL telemetry is the durable source of truth."* It
**works solo** — teleport always sticks in a local world (no server anti-cheat).

## What this session built (committed — `9fc3dec`, branch `networksense-matrix-pipeline`)

Durable and useful, but built as a *parallel elaboration* on top of the working
path rather than continuing it:

- **ComfyNetworkSense 0.1.0 → 0.4.0**
  - `AutoCharacterSelectPatches` — drives FejdStartup character-select + connect
    for headless/swarm clients; hostname-derived character. `COMFY_AUTOJOIN`.
  - Server heartbeat — the dedicated server now writes `telemetry-server.jsonl`
    every pulse regardless of connected clients (aggregate bytes/sec, msgs/sec,
    players, world ZDO count). Client sampler gated off on a dedicated server.
    **This is genuinely useful** — it makes the headless server a self-sufficient
    server-side recorder and addresses the `server_pulse_capture` readiness warning.
  - `MatrixCheckinRunner` — swarm clients poll the gateway for a matrix cell,
    teleport, measure load-time, benchmark, report. `COMFY_MATRIX_CHECKIN`.
    **Never smoke-tested live in-game.**
- **comfy-gateway**
  - `toolsurface/matrix.py` — check-in/dispatch loop (seed/checkout/report/status)
    and `valheim_matrix_baseline` — the matrix-on-matrix join: modeled CSV
    (baseline slice: actor_players=1, rtt=0, server_process_ms=2 → 96 cells)
    crossed with measured server + client data → per-cell {modeled, measured,
    delta, covered} + coverage summary. **Reads whatever telemetry you point it
    at — genuinely useful and transport-agnostic.**
  - HTTP routes (`/valheim/matrix/*`) + MCP tools for all of the above.
  - `network/mcp/Dockerfile` + `.dockerignore` — gateway code is now baked into
    an image; compose `build:`s it instead of running from a read-only bind mount.
- **Field lab** — compose gateway build + `COMFY_AUTOJOIN`/`COMFY_MATRIX_CHECKIN`/
  `COMFY_GATEWAY_URL` on the client anchor; swarm clone step folds in the Valheim
  character dirs; runtime/generated trees gitignored
  (`fieldlab/autonomous/state` ~30GB, `fieldlab/runs`, `network/mcp/var`).

## Options tried to get REAL connected client data — and why each stalled

The session spent most of its length trying to stand up a *connected rendered
client* to produce real network numbers. This is the detour.

1. **Container rendered client** (Steam-Headless + Proton, `valheim-client-01`):
   - Steam login required manual UI (no cached session at first; now remembered
     as `waryfool` / `76561197976161749`).
   - Valheim "update" **stalled at Preallocating** — Steam `fallocate` wedges on
     the Windows Docker bind mount (`/mnt/games` = `C:\`). Eventually completed.
   - **GPU wall (dead end):** container has **no `/dev/dri`**; Valheim falls back
     to `llvmpipe` (software Vulkan) and **double-faults loading the world**. The
     mod never even loaded that session. GPU passthrough to Docker-Desktop/WSL2
     for Vulkan *game rendering* is not viable. The menu can render on llvmpipe
     (that's where the clean 60fps solo samples came from); the dense world cannot.
2. **Headless client** (`valheim.exe -batchmode -nographics` via Proton):
   inconclusive — the launch didn't take (Steam app-state), so `-nographics` was
   never actually exercised. There is **no native Linux client binary**
   (`valheim.x86_64` absent; the install is the Windows `valheim.exe`).
3. **Desktop client → container server:** the client reached the server
   (`New connection` in the server log) but the Steam-networking handshake failed
   with `k_EResultInvalidState` / `problem 5003` — a **crossplay mismatch** (server
   was crossplay-OFF, modern client defaults crossplay-ON; no password prompt =
   handshake never completed). Fix applied: **server flipped to `CROSSPLAY=true`**
   → it registered and produced **join code `990144`**. The join-with-code path
   was set up but not completed; Derek ended up in a solo world instead.
4. **MCP check-in scale test** (synthetic swarm, the one clearly-good experiment):
   throughput is **flat ~480 collections/sec from 5 to 30 workers**, gateway at
   **28% CPU / 58 MB**, host at **57/127 GB (70 GB free)**. **MCP collection is
   never the bottleneck.** (A first run showed a false "collapse" at 20+ workers —
   that was a harness bug: `urllib` opened a fresh TCP connection per request and
   exhausted host ephemeral ports; fixed with keep-alive.)

## Lessons learned

- **Check for the existing working pipeline before building.** The matrix capture
  already worked (solo desktop rehearsal → local JSONL → scenarios). This session
  built a container swarm + gateway check-in + crossplay server in parallel. The
  handoffs, run packets, and `AGENTS.md` were the map; read them first.
- **The baseline does not need a live rendered-client swarm.** The modeled
  9,600-cell matrix *is* the wide backstop, and a **solo** desktop rehearsal gives
  the real client-side density baseline. The only dimension that genuinely needs a
  connected server is real network bytes/rtt — one narrow slice, not the baseline.
- **Rendering a Vulkan game headless in a GPU-less Docker Desktop/WSL2 container
  is a wall** (double-fault). Do not chase GPU passthrough here. The dedicated
  *server* runs headless fine because it renders nothing.
- **Steam realities:** one online session per account; a local dedicated-server
  join needs crossplay aligned on both sides (server `CROSSPLAY`, client toggle).
- **Docker-Desktop-on-Windows gotchas** (all cost time this session): stale
  bind-mounted `.py` served by a long-running process (bake code into an image);
  a stray native `python.exe` squatting on `:8720` shadowing the container port;
  Steam `Preallocating` stalls on bind-mount filesystems.
- **Anchor on server-side + solo-client + modeled matrix.** Treat
  connected/swarm/scaled data as a later, deliberate effort — not a blocker for
  the baseline.

## Current state (right now)

- Committed: `9fc3dec` on branch `networksense-matrix-pipeline` (not merged/pushed).
- `valheim-server` up with `-crossplay`, join code **`990144`**, world ComfyEra16
  (~9.16M ZDOs), server heartbeat writing (0 players at rest).
- `comfy-gateway` up (baked image) with matrix + baseline tools; verified over HTTP.
- Desktop Valheim: mod **0.4.0**; `[Matrix]` check-in enabled as `viking1`
  (`matrixGatewayUrl=http://127.0.0.1:8720`); `waryfool` added to server
  `adminlist.txt`.
- Matrix baseline: modeled 96/96 cells present; measured side is **synthetic only**
  (from the scale test) — needs a real rehearsal to become meaningful.
- A watcher is armed on the desktop telemetry to catch a rehearsal run.

## Recommended next steps (the working path first)

1. **Capture real client-side baseline the Codex way** (solo, no server needed):
   in the Era16 world, F5 →
   `network_sense_rehearsal teleport-route.tsv host_full`. It walks the 6 density
   cells and writes per-cell fps/frame-time/load-time to the desktop JSONL.
2. **Collect it** with `run-experiment.ps1` on the rehearsal/readiness scenario
   (reads the desktop telemetry). Optionally point `valheim_matrix_baseline` at
   that telemetry (env `COMFY_MATRIX_MODELED_CSV` + a results source) to fold real
   measurements into the join.
3. **Re-run `valheim-era16-volunteer-readiness-baseline`** — the live server
   heartbeat should flip `server_pulse_capture`; a ≥30-min connected/solo session
   closes `continuous_client_window`.
4. **Connected network numbers (later, deliberate — not blocking):** either finish
   the desktop → crossplay-server join (code `990144`) for real rtt/bytes, or build
   the render-free ZNet/headless bot for scale. The server heartbeat already
   captures the server side of this.
5. **Housekeeping:** merge `networksense-matrix-pipeline` → `main` (repo's normal
   flow is direct-to-main) and push.

## Key pointers

- Modeled matrix: `fieldlab/runs/*-era16-density-pressure-matrix/telemetry/era16-pressure-matrix.csv`
  (staged copy for the gateway: `network/mcp/var/matrix/modeled-pressure-matrix.csv`).
- Matrix baseline tool: `network/mcp/comfy_gateway/toolsurface/matrix.py`
  (`valheim_matrix_baseline`) + `GET /valheim/matrix/baseline[?summary=1]`.
- Mod: `network/mod/ComfyNetworkSense/` (0.4.0). Runner:
  `Core/Services/MatrixCheckinRunner.cs`; server pulses: `ServerPulseBroadcaster.cs`.
- Scenarios: `fieldlab/scenarios/`; runners: `fieldlab/command-plans/`,
  `fieldlab/scripts/run-experiment.ps1`.
- Strategy/plan: `docs/thesis-gold-local-lab-plan.md`, `network/mcp/AGENTS.md`.

## Principles to keep (from the plan / AGENTS.md)

- JSONL telemetry is the durable source of truth. Local files first.
- Every experiment is a reproducible, signed run packet.
- Prove claims with a number and a reproduction path; no "works great".
- Check what already exists before building parallel infrastructure.

## Continuation: 2026-07-07 0.4.8 Route + Portal/Spawner Fix

User observed that `network_sense_lumberjacks_shadow_route` did not appear to
teleport and that the Era16 world was stuttering every ~10s after load.

What the log showed:

- Teleport did fire: `route_01_open_control shadow_route_teleport moved=True`
  and the region moved from `35:-1` to `0:0`.
- Valheim then recreated the local player during the teleport/load transition:
  `Starting respawn`, `Local player destroyed`.
- Old 0.4.7 route coroutine threw a `NullReferenceException` while reading the
  stale local-player transform. This left the route state/sidecar stuck until
  Valheim restart.
- Era16 load showed `ConnectPortals => Connected 5593 portals` and
  `ConnectSpawners => Connected 20255 spawners and 65184 'done' spawners`,
  matching the suspected single-thread portal/spawner connection path.

Built and installed `ComfyNetworkSense` 0.4.8:

- Hardened `RunLumberjacksShadowRoute`:
  waits for a stable local player after teleport, reacquires the player before
  benchmark movement, and always restores benchmark duration / stops
  `LumberjacksShadowAuthorityRunner` / exports / resets `_routeRunning` in
  `finally`.
- Added `Core/Services/PortalConnectionCache.cs`:
  host/server-only cached replacement for Valheim portal matching, based on the
  local `scratch/ComfyMods/BetterServerPortals` algorithm. Config:
  `[PortalFix] portalConnectionCacheEnabled=true`,
  `portalConnectionCacheIntervalSeconds=5`,
  `portalConnectionCacheLogIntervalSeconds=60`.
- Added `Core/Services/SpawnerConnectionCache.cs`:
  cached O(n) spawner connection replacement based on the local
  `scratch/ComfyMods/Atlas` `ConnectSpawners` patch. Config:
  `[SpawnerFix] spawnerConnectionCacheEnabled=true`.
- Updated `CHANGELOG.md`, `COMMANDS.md`, `README.md`, `manifest.json`.

Install/validation:

- Build command passed:
  `C:\work\dotnet9\dotnet.exe build C:\work\comfy\network\mod\ComfyNetworkSense\ComfyNetworkSense.csproj -c Release -p:PluginOutputPath=C:\work\comfy\network\mod\ComfyNetworkSense\__no_copy__`
- Installed DLL to live Steam plugin folder and all `fieldlab/autonomous/state`
  plugin copies.
- Live DLL:
  `C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\plugins\ComfyNetworkSense.dll`,
  assembly version `0.4.8.0`, size `228864`, timestamp `2026-07-07 21:46:34`.
- Live config explicitly has `[PortalFix]` and `[SpawnerFix]` enabled.
- Valheim was closed when installed, so the live DLL copy succeeded.

Next in-game check:

1. Relaunch Valheim with `-console`.
2. Load Era16 as host. In `BepInEx/LogOutput.log`, expect:
   `Portal connection cache enabled; interval=5s.`
   `Spawner connection cache processed ...`
   and then portal summaries every 60s.
3. Run:
   `network_sense_lumberjacks_shadow_route teleport-route.tsv movement_only ws://127.0.0.1:4000 region-spawn`
4. Watch for route phases. The first stop should no longer crash after the
   teleport/load respawn. If stutters persist, compare `perf-hitches.jsonl` before
   and after the portal/spawner cache rows.

Post-relaunch validation:

- BepInEx loaded `ComfyNetworkSense 0.4.8`.
- User reported the world felt "1000x better" after relaunch/loading.
- Log showed portal cache active:
  `Portal connection cache enabled; interval=5s.`
- Log showed the spawner cache handled the large pass:
  `Spawner connection cache processed spawned=85439 targets=20255 connected=20255 done=65184.`
- A single vanilla `ConnectPortals => Connected 5593 portals` still appeared
  during world load, but subsequent periodic portal handling is the cached
  NetworkSense loop (`Portal connection cache processed portals=15133 ...`).
- `perf-hitches.jsonl` no longer showed recurring 0.4.7-style 10s-30s
  `shadow_route` hitches after the initial 0.4.8 world/respawn load window.
- Live route validation continued:
  stop 1 completed, `Lumberjacks shadow authority stopping; no Valheim position
  corrections were applied`, stop 2 started, and the user reported they
  successfully portalled and survived with god/fly enabled.
