# NetworkSense Era16 Baseline Matrix

> **ERA-BOUND (July 4–8, mod 0.4.x, solo-OMEN).** Superseded as a pickup doc — do not start
> here. Current state: `GROUND-TRUTH.md`; live plan: `TEST-PROGRAM.md` (the matrix methodology
> returns at P2's baseline).

This is the pickup document for the Era16 NetworkSense baseline experiment.
It states the goal, the matrix shape, how each part is populated, and how to
tell whether the data is real or only staged.

Performance blocker plan:

```text
fieldlab/NETWORKSENSE-PERF-DEBUG-PLAN.md
```

## Goal

Produce a wide, known baseline before inviting human volunteers.

The baseline should answer:

- What does the real Era16 save look like across representative density bands?
- What does the modeled network pressure matrix predict across player count,
  observer range, RTT, server frame cost, and event profile?
- What does the desktop Valheim client actually experience when moved through
  those density bands?
- Which cells still need human or connected-client variance instead of setup
  discovery?

The durable source of truth is JSONL telemetry under:

```text
C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-network-sense\
```

Run packets under `fieldlab/runs/` are signed summaries of that source data.

## Matrix Shape

The modeled backstop is:

```text
6 density_bands
x 5 actor_players
x 4 observer_ranges
x 4 rtt_ms
x 5 server_process_ms
x 4 event_profiles
= 9,600 modeled rows
```

Axes:

```text
density_bands: open_control, sparse, light, mixed, dense, extreme
actor_players: 1, 5, 25, 50, 100
observer_ranges: self, near, mid, far
rtt_ms: 0, 50, 100, 200
server_process_ms: 2, 8, 16, 33, 55
event_profiles: movement_only, build_social, combat_build, event_surge
```

The gateway measured baseline slice is the local/single-player slice:

```text
actor_players = 1
rtt_ms = 0
server_process_ms = 2

6 density_bands x 4 observer_ranges x 4 event_profiles = 96 cells
```

The manual desktop rehearsal route is narrower and more reliable for the first
real client baseline:

```text
6 density_bands x 1 local desktop client x 60 second benchmark per stop
```

That route is the first data collection path to trust. The gateway 96-cell
check-in path is useful, but it is swarm/lab automation and should not block
the baseline.

## Population Sources

### 1. Modeled Matrix

Scenario:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\era16-density-pressure-matrix.yaml
```

Input:

```text
C:\work\ComfyStewardView\viewer\target\ComfyEra16.duckdb
```

Outputs:

```text
telemetry/era16-density-fixtures.json
telemetry/era16-pressure-matrix.csv
telemetry/matrix-summary.json
```

Done means:

- `matrix-summary.json` has `status: pass`.
- `matrix_row_count` is `9600`.
- `density_fixture_count` is `6`.
- The six fixtures include real-world coordinates for sparse, light, mixed,
  dense, and extreme density bands, plus synthetic `open_control`.

Known good run:

```text
fieldlab/runs/20260704-080932-era16-density-pressure-matrix
```

### 2. Desktop Client Density Rehearsal

This is the preferred next population step.

Stage the route and config:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-era16-teleport-rehearsal.yaml
```

Launch desktop Valheim with console:

```powershell
Start-Process "C:\Program Files (x86)\Steam\steam.exe" -ArgumentList "-applaunch 892970 -console"
```

In Valheim:

1. Load the Era16 world.
2. Press `F5`.
3. Run:

```text
network_sense_rehearsal teleport-route.tsv host_full
```

Route file:

```text
BepInEx\config\comfy-network-sense\teleport-route.tsv
```

Current route shape:

```text
route_01_open_control  0.00      0.00      settle 20s  benchmark 60s
route_02_sparse        1250.00   7750.00   settle 20s  benchmark 60s
route_03_light        -10250.00  7750.00   settle 20s  benchmark 60s
route_04_mixed        -1750.00   13250.00  settle 20s  benchmark 60s
route_05_dense        -4250.00   14250.00  settle 20s  benchmark 60s
route_06_extreme       3250.00   2250.00   settle 20s  benchmark 60s
```

The full route takes about 8 minutes plus world load time.

Done means:

- `event-timeline.jsonl` has `route_run start`, all six `route_XX_* start`
  and `route_XX_* end` markers, then `route_run end`.
- `benchmark-results.jsonl` has six new benchmark rows for the run session.
- `telemetry-client.jsonl` has fresh `client_live` rows for each density band.
- A rerun of the teleport rehearsal packet reports route completion, not
  merely `rehearsal_ready_not_running`.

### 3. Volunteer Readiness Packet

After the desktop route completes:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-era16-volunteer-readiness-baseline.yaml
```

Done means:

- No failed readiness gates.
- `client_telemetry`, `benchmark_capture`, `density_matrix`, and
  `teleport_route_contract` pass.
- `server_pulse_capture` passes when local host/server heartbeat rows are
  present.
- `continuous_client_window` passes only after there is at least one continuous
  30 minute client telemetry window.

The baseline can be internally useful with warnings. Do not invite volunteers
until the packet says the volunteer criteria are satisfied or the warnings are
explicitly accepted.

### 4. Gateway Matrix Baseline

Gateway endpoints:

```text
GET  http://127.0.0.1:8720/healthz
GET  http://127.0.0.1:8720/valheim/matrix/status
GET  http://127.0.0.1:8720/valheim/matrix/baseline?summary=1
POST http://127.0.0.1:8720/valheim/matrix/checkout
POST http://127.0.0.1:8720/valheim/matrix/report
```

The gateway joins:

- modeled rows from `modeled-pressure-matrix.csv`
- client JSONL measurements
- server heartbeat JSONL measurements
- gateway check-in result rows, if present

Done means for the 96-cell gateway slice:

- `GET /valheim/matrix/status` shows `done: 96`.
- `network/mcp/var/matrix/results.jsonl` has one reported row per 96-cell slice
  cell.
- `GET /valheim/matrix/baseline?summary=1` reports `covered_cells: 96`.

Important: a synthetic gateway scale test can make coverage look complete. For
publishable baseline claims, verify that measured rows came from real Valheim
JSONL or a clearly labeled synthetic source.

### 5. Connected Server Slice

This is later validation, not the first baseline blocker.

Purpose:

- Real bytes/sec and messages/sec under a dedicated server.
- Real RTT/jitter behavior.
- Host/server pulse behavior with connected clients.

Done means:

- `telemetry-server.jsonl` has `server_heartbeat` rows with connected players.
- Client telemetry has non-zero network counters when connected to the server.
- The readiness packet sees server pulse visibility.
- Any crossplay/join-code conditions are recorded in the run packet.

## Current State, 2026-07-04

Committed base:

```text
branch: networksense-matrix-pipeline
commit: 9fc3dec NetworkSense v0.4.0 + MCP matrix baseline pipeline
```

Working tree now includes a local ComfyNetworkSense `0.4.3` perf-probe build
that is not yet committed.

The `0.4.1` part addressed the first suspected NetworkSense main-thread
blocking paths observed in the desktop session:

- old behavior: synchronous JSONL appends from Unity update paths
- old behavior: per-sample global `FindObjectsByType<Character/Piece>` scans
- symptom: Valheim/BepInEx logs stopped after matrix checkout assigned the
  second cell, with no managed exception
- new behavior: async JSONL writer, throttled local physics-radius scans, and
  less per-frame allocation in route benchmark waiting

The `0.4.2` part adds measurement instead of another blind fix:

- `perf-hitches.jsonl` for frames over the configured hitch threshold
- `perf-sections.jsonl` for measured NetworkSense sections over the warning
  threshold
- `perf-engine-log.jsonl` for Unity/BepInEx log burst counters
- `perf-markers.jsonl` for manual `network_sense_perf_mark <label>` rows
- route/matrix phase context on perf rows
- `network_sense_perf_status` for live probe/writer health

The `0.4.3` part disables a likely post-load recurring stall:

- Desktop telemetry showed recurring 9-12s frame samples before the route
  command and during the first route stop.
- Dedicated-server heartbeat telemetry from the older autonomous stack showed
  expected 2-3 second heartbeats delayed into roughly 13-15 second gaps.
- The remaining always-on NetworkSense heartbeat path that scaled with the full
  save was `ZDOMan.instance.NrOfObjects()`, so 0.4.3 makes world ZDO counts
  opt-in and cached instead of polling them every server pulse.

Installed plugin DLL:

```text
C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\plugins\ComfyNetworkSense.dll
assembly version: 0.4.3.0
```

Desktop NetworkSense config should be:

```text
matrixCheckinEnabled = false
benchmarkDurationSeconds = 60
liveSampleIntervalSeconds = 0.5
serverPulseIntervalSeconds = 2
```

`matrixCheckinEnabled` must stay false for the manual desktop rehearsal. Turn it
on only for deliberate gateway/swarm check-in runs.

The last successful modeled matrix run was complete. The last complete
teleport-rehearsal packet was staged only and had `0/6` completed route stops.

## Known Traps

- Do not chase GPU-rendered Valheim clients in Docker Desktop/WSL2. The dense
  world path needs a real rendered desktop client or a purpose-built render-free
  bot.
- Do not let `matrixCheckinEnabled=true` on the desktop manual run. It will
  check out gateway cells and teleport the player before the operator command
  path runs.
- Do not trust gateway coverage unless the measured source is known. Synthetic
  scale-test rows are useful for gateway throughput, not gameplay baseline.
- If Valheim opens a window titled `Select BepInEx 5.4.23.3 - valheim` and logs
  only the two Mono path lines, close it and relaunch from Steam. That is before
  normal BepInEx chainloader startup.
- If logs stop with no managed exception, inspect main-thread work before adding
  more orchestration.

## Next Pickup Steps

1. Close any stale Valheim process.
2. Launch Valheim with `-console`.
3. Confirm BepInEx loads `ComfyNetworkSense 0.4.3`.
4. Load Era16.
5. After the player is spawned, run:

```text
network_sense_perf_status
network_sense_perf_mark load_spawned
```

6. For the next diagnostic pass, run the load-only and one-stop perf route from
   `fieldlab/NETWORKSENSE-PERF-DEBUG-PLAN.md` before the full six-stop route.
7. When ready for the six-stop baseline, run:

```text
network_sense_rehearsal teleport-route.tsv host_full
```

8. Watch:

```powershell
Get-ChildItem "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-network-sense" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 10 Name,LastWriteTime,Length
```

9. After any perf run, summarize:

```powershell
.\fieldlab\scripts\analyze-networksense-perf.ps1
```

10. After route completion, rerun:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-era16-teleport-rehearsal.yaml
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-era16-volunteer-readiness-baseline.yaml
```

11. Record the resulting run folders in this document or a new handoff.
