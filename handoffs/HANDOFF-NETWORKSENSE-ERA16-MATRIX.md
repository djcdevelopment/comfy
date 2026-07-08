# Handoff: NetworkSense Era16 Matrix

Date: 2026-07-04

Read first:

```text
fieldlab/NETWORKSENSE-ERA16-MATRIX.md
fieldlab/NETWORKSENSE-PERF-DEBUG-PLAN.md
```

That document is the durable experiment spec: goal, matrix axes, population
paths, done criteria, current state, known traps, and next pickup steps.

Current branch:

```text
networksense-matrix-pipeline
```

Important current state:

- The 9,600-row modeled Era16 pressure matrix exists and has a known good packet
  at `fieldlab/runs/20260704-080932-era16-density-pressure-matrix`.
- The desktop six-stop rehearsal is the next trusted population step.
- The last complete rehearsal packet was staged only: route completion was `0/6`.
- `matrixCheckinEnabled` must be false for the desktop manual rehearsal.
- A local, uncommitted `ComfyNetworkSense 0.4.3` build is installed in the
  Valheim plugin folder. It includes the 0.4.1 async-writer/local-scan fix plus
  the 0.4.2 perf probe and the 0.4.3 heartbeat world-count fix.
- The installed desktop assembly version is `0.4.3.0`.
- Restart Valheim before testing so BepInEx loads `ComfyNetworkSense 0.4.3`.
- Autonomous server/client plugin DLLs are staged as 0.4.3, but any already
  running dedicated server still needs a restart before it loads the new DLL.
- First diagnostic run should be the load-only / one-stop perf isolation pass in
  `fieldlab/NETWORKSENSE-PERF-DEBUG-PLAN.md`, not the full six-stop route.
- Data-stream note: the 0.4.1 desktop stream showed recurring 9-12s long-frame
  rows roughly every 10-15 seconds, starting before the route command. The
  older autonomous dedicated-server heartbeat stream also showed 13-15s gaps
  where 2-3s heartbeat rows were expected. The likely NetworkSense contributor
  was recurring `ZDOMan.instance.NrOfObjects()` in server heartbeats; 0.4.3
  disables that by default.
- Headless note: server/gateway can run in Docker, but the Steam-Headless client
  path is not a proven substitute for the desktop route. Client01 launch was
  retried after fixing display/user startup races; Valheim still did not become
  a durable in-world process, and the prior real launch crashed in native Mono
  under llvmpipe.

Useful in-game commands after loading Era16:

```text
network_sense_perf_status
network_sense_perf_mark load_spawned
```

Full route command when ready:

```text
network_sense_rehearsal teleport-route.tsv host_full
```

After any perf run:

```powershell
.\fieldlab\scripts\analyze-networksense-perf.ps1
```

After completion, rerun:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-era16-teleport-rehearsal.yaml
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-era16-volunteer-readiness-baseline.yaml
```
