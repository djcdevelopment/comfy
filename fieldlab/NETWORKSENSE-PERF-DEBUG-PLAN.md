# NetworkSense Main-Thread Hitch Debug Plan

> **ERA-BOUND (July 4–8, mod 0.4.x, solo-OMEN).** Superseded as a status doc; the H1–H5
> hypothesis methodology remains valid and gets reconciled against the new connected baseline in
> `TEST-PROGRAM.md` P2 step 14. Current state: `GROUND-TRUTH.md`.

Date: 2026-07-04

This plan targets the current blocking issue in the Era16 NetworkSense baseline:
Valheim can hit multi-second frame hitches or shut down during the route
rehearsal, before the six-stop baseline is complete.

The working assumption is not "NetworkSense is fixed by 0.4.1." The working
assumption is: we need enough in-game timing evidence to separate Valheim
world-scale costs from NetworkSense costs, then remove or isolate the confirmed
blocking path.

## Implementation Status

Built and installed locally on 2026-07-04:

```text
ComfyNetworkSense 0.4.3
C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\plugins\ComfyNetworkSense.dll
assembly version: 0.4.3.0
```

The `0.4.2` build added:

- `NetworkSensePerfProbe` with frame hitch rows, section timing rows, engine-log
  aggregate rows, and manual perf marker rows.
- `[Perf]` config entries for hitch thresholds, section thresholds, engine-log
  sampling, and sample interval.
- `[Sampling] sceneScanEnabled` and `sceneScanIntervalSeconds` for isolating the
  local physics-radius scan path.
- Route and matrix phase labels: resolve target, teleport, settle, benchmark
  start/window/wait, timeout cancel, report/export, and idle.
- Telemetry writer queue/depth/drop/fault counters.
- In-game console commands:

```text
network_sense_perf_status
network_sense_perf_mark <label>
```

Analysis helper:

```powershell
.\fieldlab\scripts\analyze-networksense-perf.ps1
```

That helper reads the latest perf JSONL session by default and writes:

```text
fieldlab/runs/<timestamp>-networksense-perf-analysis/telemetry/perf-summary.json
fieldlab/runs/<timestamp>-networksense-perf-analysis/raw/perf-timeline.md
```

Deferred optional work: `ProfilerRecorder` counter capture and repeated-warning
suppression were not added in this pass. The implemented probe is enough for
Test A and Test B below.

The `0.4.3` build disables a likely recurring stall:

- Desktop 0.4.1 telemetry showed post-load hitches before the route command,
  then during the first route stop. Long-frame samples landed roughly every
  10-15 seconds, including 9.4s, 9.7s, 11.1s, 9.6s, 12.6s, 10.2s, and 9.7s
  frames.
- Autonomous dedicated-server heartbeat rows from the 0.3.0 stack were also
  delayed: expected 2-3 second rows arrived roughly every 13-15 seconds before
  world-save/backup work made gaps larger.
- The remaining always-on NetworkSense path that scaled with the whole save was
  `ServerPulseBroadcaster.CaptureServerHeartbeat -> ZDOMan.instance.NrOfObjects()`.

Fix:

- `serverHeartbeatWorldZdoCountEnabled = false` by default.
- `serverHeartbeatWorldZdoCountIntervalSeconds = 300` when explicitly enabled.
- `worldZdoCountOnSevereHitchEnabled = false` by default so the perf probe does
  not call the same world-count function while reporting a hitch.

After restarting Valheim/server on 0.4.3, the first validation is simple: the
post-load telemetry stream should no longer show recurring 10-second long-frame
samples or server heartbeat gaps caused by NetworkSense heartbeat world counts.

## Headless Status

Headless server/gateway is viable:

- Docker is reachable.
- The autonomous stack can run `valheim-server` and `comfy-gateway`.
- The dedicated server has loaded Era16-scale state and logs about 9.15 million
  ZDOs.

Headless gameplay-client benchmarking is not currently proven:

- The Steam-Headless client container has a Valheim install and a valid Steam
  session, but the reliable desktop-route path still needs a rendered client.
- A previous Steam-Headless Valheim launch reached menu/connect flow and then
  crashed in native Mono code with `SIGSEGV` under llvmpipe software rendering.
- The autonomous client init script was patched to wait for `DISPLAY=:55` and
  launch Steam as the `default` user instead of root, fixing two container
  startup issues. After those fixes, Valheim still did not become a durable
  client process during the retry.

Conclusion: use the headless stack for server/gateway checks and save/load
server telemetry. Do not treat it as a replacement for the desktop Era16
client perf run until the Steam-Headless Valheim client stays in-world and
  writes fresh `ComfyNetworkSense 0.4.3` perf rows.

## Local Evidence

Era16 scale:

- Known modeled save size: about 9.15 million ZDOs.
- Game log during desktop load:

```text
ConnectPortals => Connected 4472 portals.
[ Connected 1121 portals ]
Loaded 18004 locations
```

Observed log burst during load:

```text
07/04/2026 16:19:58  Failed to get attach prefab: 52 warnings
07/04/2026 16:19:59  Failed to get attach prefab: 90 warnings
07/04/2026 16:20:00  Failed to get attach prefab: 38 warnings
07/04/2026 16:20:01  Failed to get attach prefab: 56 warnings
```

The `0.4.1` run loaded and started the route, so the patched DLL was active:

```text
build_version: 0.4.1
route_rehearsal host_full start
route_run start stops=6 file=teleport-route.tsv
route_01_open_control teleport moved=True target=0,80,0
```

Even after the `0.4.1` async-writer/local-scan patch, the client telemetry
caught two large frame hitches on the first stop:

```text
frame_time_ms = 10285.96
frame_time_ms = 9755.181
```

The process then shut down cleanly enough to run Valheim save/quit work:

```text
Game - OnApplicationQuit
PrepareSave: clone done in 1609ms
PrepareSave: ZDOExtraData.PrepareSave done in 6123 ms
Saved 9155572 ZDOs
World saved (32175.3968ms)
Unloading unused Assets ... Total: 4799.049700 ms
```

This means there are at least two issues:

- A route/startup hitch during normal play.
- A very expensive world-save/shutdown path, expected at this save scale but
  important to keep out of measurement windows.

## External Facts Used

Unity facts to anchor the plan:

- Unity normally runs user code on the main thread unless moved into the job
  system or background work explicitly.
- `Object.FindObjectsByType` can be expensive when many objects are returned;
  Unity notes that avoiding sorting can save significant time for many results.
- `Physics.OverlapSphereNonAlloc` avoids garbage allocation but is still a
  main-thread physics query with a fixed buffer.
- `ProfilerMarker` is the intended low-overhead way to mark expensive script
  blocks for the Unity profiler.
- `ProfilerRecorder` can read profiler counters/marker data from the player.
- `Application.logMessageReceivedThreaded` can be invoked from different
  threads, so its handler must avoid Unity API calls and only record thread-safe
  state.
- `GC.Alloc` profiler samples represent managed allocations that can contribute
  to later garbage collection stalls.

References:

- https://docs.unity3d.com/6000.2/Documentation/Manual/job-system-overview.html
- https://docs.unity3d.com/6000.4/Documentation/ScriptReference/Object.FindObjectsByType.html
- https://docs.unity3d.com/6000.4/Documentation/ScriptReference/Physics.OverlapSphereNonAlloc.html
- https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Unity.Profiling.ProfilerMarker.html
- https://docs.unity3d.com/6000.2/Documentation/ScriptReference/Unity.Profiling.ProfilerRecorder.html
- https://docs.unity3d.com/6000.4/Documentation/ScriptReference/Application-logMessageReceivedThreaded.html
- https://docs.unity3d.com/6000.1/Documentation/Manual/profiler-markers.html

## Hypotheses

### H1: Valheim Portal Or World-Load Work Is Blocking

Signals:

- Hitches line up with `ConnectPortals`, `[ Connected ... portals ]`,
  `Loaded ... locations`, `Unloading unused assets`, region transitions, or
  teleport boundaries.
- NetworkSense section timers are small during the same frame.
- Hitches happen with telemetry disabled or in perf-only mode.

Likely resolution:

- Treat load/portal time as an explicit measured field, not benchmark time.
- Add a quiet-period gate before starting each benchmark.
- Increase settle time only when the destination has not been quiet for N
  seconds.
- If portal work dominates specific coordinates, avoid measuring those stops
  until the portal graph is understood or pre-warmed.

### H2: Unity/BepInEx Log Spam Is Blocking

Signals:

- Hitches line up with hundreds of repeated Unity warnings per second.
- `Application.logMessageReceivedThreaded` counters spike immediately before
  hitch rows.
- No NetworkSense section timer accounts for the full stall.

Likely resolution:

- Identify the save objects/items causing attach-prefab warnings.
- Make the perf probe count repeated messages without echoing or amplifying
  them.
- Do not add more per-warning logging from our mod.
- If needed for experiments, add a local suppress/count-only mode for repeated
  non-NetworkSense warning text.

### H3: NetworkSense Sampling Is Still Too Expensive

Signals:

- Hitches line up with `ClientTelemetrySampler.Capture`, scene scan,
  `ServerPulseBroadcaster.Update`, `BenchmarkRunner.Update`, or HUD/panel draw.
- Hitches disappear when scan/pulse/logging toggles are disabled.
- `perf-hitches.jsonl` attributes most of the frame to a NetworkSense section.

Likely resolution:

- Make build/entity scans opt-in or amortized over many frames.
- Add a hard per-frame scan budget.
- Keep benchmark frame probes allocation-free.
- Reduce sample frequency during teleport/load windows.

### H4: Telemetry Writer Backpressure Is Blocking Or Losing Data

Signals:

- Writer queue depth grows during dense load.
- Hitches line up with enqueue/flush or disk I/O.
- Telemetry stops before process shutdown without matching game log markers.

Likely resolution:

- Batch writes per file and flush at fixed intervals.
- Expose queue depth, dropped row count, and writer fault count.
- Prefer bounded lossy telemetry under stress over blocking the game loop.

### H5: Save/Shutdown Cost Is Being Mistaken For Gameplay Cost

Signals:

- Hitches line up with `OnApplicationQuit`, `PrepareSave`,
  `ZDOExtraData.PrepareSave`, `Saved ... ZDOs`, or `World saved`.

Likely resolution:

- Exclude shutdown windows from route performance summaries.
- Add explicit `shutdown_save` and `world_save` markers when detected in logs.
- Do not stop Valheim during a measurement window unless the goal is save-cost
  measurement.

## Instrumentation To Add

Add a `NetworkSensePerfProbe` service to the mod.

Config:

```ini
[Perf]
perfProbeEnabled = true
hitchThresholdMs = 250
severeHitchThresholdMs = 2000
sectionWarnThresholdMs = 25
engineLogProbeEnabled = true
perfSampleIntervalSeconds = 1
```

Files:

```text
perf-hitches.jsonl
perf-sections.jsonl
perf-engine-log.jsonl
```

Frame-level fields:

```text
timestamp_utc
session_id
build_version
frame_unscaled_delta_ms
frame_wall_ms
hitch_level
region_id
route_state
route_stop_id
benchmark_running
latest_engine_log_time
latest_engine_log_type
latest_engine_log_message
engine_log_count_last_second
engine_warning_count_last_second
gc_total_memory_bytes
gc_gen0_count
gc_gen1_count
gc_gen2_count
writer_queue_depth
writer_dropped_rows
world_zdos
```

Section timers implemented in `0.4.2`:

```text
ComfyNetworkSense.Update
ComfyNetworkSense.FlushMainThreadMessages
ComfyNetworkSense.TelemetryCoordinator.Update
ComfyNetworkSense.TryStartAutoRehearsal
ComfyNetworkSense.TryResolveGroundHeight
ComfyNetworkSense.TryTeleport
ComfyNetworkSense.ResolveRouteTarget
TelemetryCoordinator.Update
TelemetryCoordinator.RegisterServerPulseRpc
TelemetryCoordinator.HandleShortcuts
TelemetryCoordinator.BenchmarkRunner.Update
TelemetryCoordinator.ClientTelemetrySampler.Capture
TelemetryCoordinator.ScoreCalculator.Calculate
TelemetryCoordinator.ServerPulseBroadcaster.Update
TelemetryCoordinator.DrawHud
BenchmarkRunner.Toggle
BenchmarkRunner.Update
BenchmarkRunner.Finalize
ClientTelemetrySampler.RecordFrame
ClientTelemetrySampler.Capture
ClientTelemetrySampler.SceneScan
ClientTelemetrySampler.P95
ServerPulseBroadcaster.Update
ServerPulseBroadcaster.CaptureServerHeartbeat
ServerPulseBroadcaster.CapturePulse
RunTeleportRoute.ResolveRouteTarget
RunTeleportRoute.TryTeleport
MatrixCheckinRunner.ResolveTarget
MatrixCheckinRunner.TryTeleport
MatrixCheckinRunner.BuildMetrics
MatrixCheckinRunner.StepMovementPattern
MatrixCheckinRunner.TryResolveGroundHeight
MatrixCheckinRunner.TryTeleportInternal
```

Route/matrix waits are not timed as single sections because they intentionally
span multiple frames. They are recorded as `route_state`, `route_stop_id`, and
`route_phase` context on hitch and section rows.

Implementation notes:

- Use `Stopwatch.GetTimestamp()` for internal wall-clock timings.
- Use `ProfilerMarker` around the same sections so Unity Profiler can show them.
- Use `Application.logMessageReceivedThreaded` only to increment counters and
  store the latest message text; do not call Unity APIs from that handler.
- Add queue-depth/dropped-row counters to `TelemetryLogWriter`.
- Avoid global object counts in every frame. If we need object counts, capture
  them only on a severe hitch or via an explicit operator command.

## Test Matrix

Each test should run with a fresh session id and write a packet note with config.

### Test A: Load Only

Goal: isolate Era16 load/portal/log warning cost.

Steps:

1. Launch Valheim with `ComfyNetworkSense 0.4.3`.
2. Load Era16.
3. Do not run route.
4. Stand still for 2 minutes after player spawn.

Expected signal:

- If hitches occur before any route command, they are load/portal/log/sample
  startup related.

### Test B: Perf-Only Route

Goal: isolate teleport/load from telemetry sampling.

Config:

```ini
writeTelemetryLogs = true
liveSampleIntervalSeconds = 999
serverPulseIntervalSeconds = 999
perfProbeEnabled = true
```

Steps:

1. Run a one-stop route to `open_control`.
2. Run one-stop routes to each density coordinate.
3. No benchmark; just teleport and wait for quiet.

Expected signal:

- If 10s hitches remain, base teleport/zone/portal work dominates.

### Test C: Route With Client Sampling, No Scene Scan

Goal: test the cheap telemetry path.

Config:

```ini
liveSampleIntervalSeconds = 0.5
sceneScanEnabled = false
serverPulseIntervalSeconds = 999
```

Expected signal:

- If hitches disappear versus normal route, scene scan/physics query remains
  suspect.

### Test D: Route With Scene Scan

Goal: quantify local physics scan cost.

Config:

```ini
sceneScanEnabled = true
sceneScanIntervalSeconds = 2
```

Expected signal:

- `ClientTelemetrySampler.SceneScan` should stay below section warning threshold.
- If the 4096 collider buffer saturates, record `scene_scan_truncated=true`.

### Test E: Route With Server Pulse

Goal: quantify host/server heartbeat and per-peer pulse cost.

Config:

```ini
serverPulseIntervalSeconds = 2
```

Expected signal:

- Solo local heartbeat should be cheap.
- Per-peer scans should be measured separately during later connected tests.

### Test F: Save/Shutdown

Goal: measure save cost separately from gameplay.

Steps:

1. Load Era16.
2. Stand still 1 minute.
3. Quit normally.

Expected signal:

- This produces the `PrepareSave` and `World saved` cost baseline.
- Do not mix this with route performance claims.

## Analysis Packet

Add a fieldlab analyzer:

```text
fieldlab/scripts/analyze-networksense-perf.ps1
```

Inputs:

```text
event-timeline.jsonl
telemetry-client.jsonl
telemetry-server.jsonl
perf-hitches.jsonl
perf-sections.jsonl
perf-engine-log.jsonl
BepInEx/LogOutput.log
Player.log
```

Outputs:

```text
telemetry/perf-hitch-summary.json
telemetry/perf-section-summary.json
raw/perf-timeline.md
```

Summary fields:

```text
max_frame_ms
hitch_count_250ms
hitch_count_1000ms
hitch_count_2000ms
top_sections_by_total_ms
top_sections_by_max_ms
engine_warning_bursts
route_stop_hitches
save_shutdown_hitches
writer_dropped_rows
```

## Resolution Rules

Use evidence, not guesses:

- If NetworkSense sections explain the hitch, fix that code path before rerun.
- If Valheim engine logs explain the hitch, mark it as load/portal/save cost and
  keep benchmark windows outside it.
- If both contribute, split the route into phases: teleport/load, quiet settle,
  benchmark.
- If the process exits without a crash dump and with `OnApplicationQuit`, treat
  it as an operator/game shutdown until proven otherwise.
- If the process exits without `OnApplicationQuit`, capture crash dumps and
  inspect `Player.log`/Windows Event Viewer before changing telemetry logic.

## First Implementation Pass

Done:

1. Added `NetworkSensePerfProbe`.
2. Added `[Perf]` config entries.
3. Wrapped the main section timers.
4. Added engine-log counters using `Application.logMessageReceivedThreaded`.
5. Added writer queue depth and dropped-row counters.
6. Added route/matrix state fields: current flow, stop id, and phase.
7. Built and installed `ComfyNetworkSense 0.4.3`.
8. Added `fieldlab/scripts/analyze-networksense-perf.ps1`.

Next:

1. Run Test A and Test B only.
2. Run the analyzer.
3. Read `perf-hitches.jsonl` and `perf-sections.jsonl` before running the full
   six-stop rehearsal again.
