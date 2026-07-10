# Fieldlab

> **START HERE (2026-07-09):** current state of the world → [GROUND-TRUTH.md](GROUND-TRUTH.md)
> · live phased plan → [TEST-PROGRAM.md](TEST-PROGRAM.md) · topology + traps →
> [MULTIPLAYER-NETWORK-SETUP.md](MULTIPLAYER-NETWORK-SETUP.md) · live dashboard → `status/`.
> The Era16 pickup docs below are **era-bound (July 4–8)** and no longer the entrypoint.
> ⚠️ The "Autonomous Valheim Lab" (OMEN Docker) topology in this file is **dead** — Docker
> Desktop publishes no UDP; the server lives on am4 (see the setup runbook).

`fieldlab/` is the working directory for reproducible Thesis Gold experiments.

The purpose is to turn networking and native-runtime claims into field packets that another
developer, collaborator, or future agent can rerun.

Era-bound (July 4–8) NetworkSense Era16 baseline pickup docs:

```text
fieldlab/NETWORKSENSE-ERA16-MATRIX.md
fieldlab/NETWORKSENSE-PERF-DEBUG-PLAN.md
fieldlab/VALHEIM-LUMBERJACKS-FEASIBILITY.md
```

First proof target:

```text
Thesis Gold networking integration with Lumberjacks
-> no-mod fallback path
-> progressive enhancement path
-> visible traffic classification and prioritization
-> consistent player experience under pressure
```

## Packet Standard

Every experiment run should produce:

- `goal`
- `approach`
- `method`
- `results`
- `signature`
- reproducible steps
- publishable field notes
- technical overview
- quick start

Run folders live under:

```text
fieldlab/runs/
```

Each run should include:

```text
experiment.yaml
environment.json
commands.ps1
raw/
telemetry/
captures/
results.json
report.md
publish.md
quickstart.md
signature.json
```

## Privacy Rule

Public outputs use Viking aliases by default.

Keep any real-name mapping local and private:

```text
fieldlab/private/
```

That folder is ignored by git.

## First Scenario

Bootstrap prerequisites if needed:

```powershell
.\fieldlab\scripts\install-dotnet9.ps1
.\fieldlab\scripts\bootstrap-lumberjacks.ps1
```

Start here:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\thesis-gold-progressive-enhancement.yaml
```

The first scenario is intentionally conservative. It creates a run folder, captures environment
details, records git state, writes packet files, records expected traffic classes, and runs the two
direct Lumberjacks test projects when the checkout is available.

Current baseline commands:

```text
C:\work\dotnet9\dotnet.exe test Game.sln
```

## Runtime Scenario

After the unit baseline is green, run the native runtime smoke gate:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\lumberjacks-native-runtime-smoke.yaml
```

This scenario expects a reachable Postgres backend on `127.0.0.1:5433`. If Docker is installed and
available in `PATH`, the command plan will try to start Lumberjacks' Docker Postgres automatically.
If not, it records `blocked_missing_database` in `telemetry/runtime-summary.json` instead of hanging.

If Docker is unavailable, bootstrap a portable Windows Postgres backend:

```powershell
.\fieldlab\scripts\bootstrap-windows-postgres.ps1
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\lumberjacks-native-runtime-smoke.yaml
```

The Windows bootstrap downloads the EDB PostgreSQL binary archive under `C:\work\tools`, starts a
user-owned Postgres process on `127.0.0.1:5433`, creates the `game` database/user, and loads
Lumberjacks' `infra/docker/init.sql` schema.

If WSL Ubuntu networking is known to forward loopback ports correctly, this alternative also works:

```powershell
.\fieldlab\scripts\bootstrap-wsl-postgres.ps1
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\lumberjacks-native-runtime-smoke.yaml
```

The WSL bootstrap invokes Ubuntu as `root`, installs Postgres, creates the `game` database/user, and
loads Lumberjacks' `infra/docker/init.sql` schema. On some WSL mirrored-network setups Windows
processes cannot reliably connect back to the WSL Postgres listener; use the Windows bootstrap in
that case.

Useful overrides:

```powershell
$env:FIELDLAB_LUMBERJACKS_PATH = "C:\work\Lumberjacks"
$env:FIELDLAB_PGHOST = "127.0.0.1"
$env:FIELDLAB_PGPORT = "5433"
$env:FIELDLAB_GAME_DB_CONNECTION = "Host=127.0.0.1;Port=5433;Database=game;Username=game;Password=game"
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\lumberjacks-native-runtime-smoke.yaml
```

Use `-KeepRunning` when you want to inspect the live services after the probes:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\lumberjacks-native-runtime-smoke.yaml -KeepRunning
```

## Era16 Density Matrix Scenario

Generate real save-density fixtures and a pressure matrix from the StewardView Era16 DuckDB cache:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\era16-density-pressure-matrix.yaml
```

The scenario writes:

```text
telemetry/era16-density-fixtures.json
telemetry/era16-pressure-matrix.csv
telemetry/matrix-summary.json
```

Override the cache path when needed:

```powershell
$env:FIELDLAB_ERA16_DUCKDB = "C:\work\ComfyStewardView\viewer\target\ComfyEra16.duckdb"
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\era16-density-pressure-matrix.yaml
```

This packet generates load targets only. The next runtime packet should replay selected matrix rows
through Lumberjacks and compare observed UDP/WebSocket behavior against the modeled priority
expectations.

## Valheim To Lumberjacks Feasibility

The first bridge spike is intentionally narrow: prove that a live Valheim BepInEx plugin process
can speak the Lumberjacks Gateway protocol before attempting visual projection, shadow authority,
or any ZDO/transport patching.

Start Lumberjacks and keep it running:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\lumberjacks-native-runtime-smoke.yaml -KeepRunning
```

Restart Valheim with `ComfyNetworkSense 0.4.5`, then run:

```text
network_sense_lumberjacks_probe ws://127.0.0.1:4000 region-spawn 12
```

With `ComfyNetworkSense 0.4.5`, run the local-only projection spike:

```text
network_sense_lumberjacks_projection start ws://127.0.0.1:4000 region-spawn
network_sense_lumberjacks_projection status
network_sense_lumberjacks_projection stop
```

Capture or re-check the packet:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-lumberjacks-bridge-feasibility.yaml
```

Probe rows are written under `BepInEx\config\comfy-network-sense\lumberjacks-bridge-probes.jsonl`.
Projection rows are written under `BepInEx\config\comfy-network-sense\lumberjacks-projection.jsonl`.
`pass_sidecar_protocol` only proves side-channel protocol reachability; it does not prove Valheim
ZDO transport replacement or physics authority replacement.

With `ComfyNetworkSense 0.4.6`, run the shadow movement authority spike:

```text
network_sense_lumberjacks_shadow start ws://127.0.0.1:4000 region-spawn
# move the local player for 60-120 seconds
network_sense_lumberjacks_shadow status
network_sense_lumberjacks_shadow stop
```

Capture or re-check the shadow packet:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-lumberjacks-shadow-authority.yaml
```

Shadow rows are written under `BepInEx\config\comfy-network-sense\lumberjacks-shadow.jsonl`.
This is measurement only: it compares trajectories and does not apply Valheim corrections.

## Volunteer Readiness Baseline

Before inviting volunteer players, run the Valheim Era16 readiness packet:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-era16-volunteer-readiness-baseline.yaml
```

It consumes ComfyNetworkSense telemetry from:

```text
BepInEx\config\comfy-network-sense\
```

and writes:

```text
telemetry/volunteer-readiness-summary.json
telemetry/baseline-metrics.json
telemetry/teleport-route-contract.json
raw/setup-inventory.json
```

Use environment variables to make resource-profile runs explicit:

```powershell
$env:FIELDLAB_RESOURCE_PROFILE = "server_4c_16gb"
$env:FIELDLAB_WSL_MEMORY_GB = "16"
$env:FIELDLAB_WSL_PROCESSORS = "4"
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-era16-volunteer-readiness-baseline.yaml
```

The packet dry-runs the requested WSL envelope by default and records whether `.wslconfig`
already matches it. Inspect or apply the same profile directly:

```powershell
.\fieldlab\scripts\set-wsl-resource-profile.ps1 -Profile server_4c_16gb
.\fieldlab\scripts\set-wsl-resource-profile.ps1 -Profile server_4c_16gb -Apply
```

Only stop running WSL distros when you are ready for the change to take effect:

```powershell
.\fieldlab\scripts\set-wsl-resource-profile.ps1 -Profile server_4c_16gb -Apply -ShutdownWsl
```

The readiness packet can apply the profile for a named run when the same action is explicitly
requested:

```powershell
$env:FIELDLAB_RESOURCE_PROFILE = "server_4c_16gb"
$env:FIELDLAB_APPLY_WSL_LIMITS = "1"
$env:FIELDLAB_WSL_SHUTDOWN = "1"
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-era16-volunteer-readiness-baseline.yaml
```

`host_full` does not remove existing WSL limits unless `FIELDLAB_CLEAR_WSL_LIMITS=1` is set.
Windows client affinity and priority are still recorded as requested profile data rather than
silently changed.

## Teleport Rehearsal

Stage or verify the internal route rehearsal:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-era16-teleport-rehearsal.yaml
```

This packet generates `telemetry/teleport-route.tsv`, copies it to the NetworkSense config folder
when available, and writes the in-game command sequence to `raw/valheim-console-commands.txt`.

After starting Valheim with the rebuilt ComfyNetworkSense plugin and loading the Era16 test world,
run the one-shot rehearsal command:

```text
network_sense_rehearsal teleport-route.tsv host_full
```

Then rerun the rehearsal packet and the volunteer readiness baseline.

For the current Era16 main-thread hitch investigation, summarize the
ComfyNetworkSense 0.4.3 perf JSONL files with:

```powershell
.\fieldlab\scripts\analyze-networksense-perf.ps1
```

## Autonomous Valheim Lab

Stage the WSL/Docker lab without starting containers:

```powershell
.\fieldlab\scripts\run-autonomous-valheim-lab.ps1 -Clients 1 -Profile host_full
```

Run the private autonomous stack:

```powershell
.\fieldlab\scripts\run-autonomous-valheim-lab.ps1 -Clients 1 -Profile host_full -Start
```

The runner builds ComfyNetworkSense, checks or applies the requested WSL profile, refreshes the
readiness/rehearsal route packets, copies the local `ComfyEra16.db/.fwl` save from
`%USERPROFILE%\AppData\LocalLow\IronGate\Valheim\worlds_local` into Docker's server config,
stages Docker state under `fieldlab/autonomous/state`, writes `raw/valheim-lab.env`, and starts:

```text
valheim-server
comfy-gateway
valheim-client-01..04
```

Clients are Steam-Headless containers. On first use, each persistent client home still needs a
valid Steam login and a Valheim install under `/mnt/games/GameLibrary/Steam/steamapps/common/Valheim`. After that,
the container init script copies `ComfyNetworkSense.dll`, the auto-rehearsal config, and
`teleport-route.tsv`, then launches Valheim toward the private server. No in-game command is
required; the mod starts the route after the local player is available.

Steam-Headless runs with elevated container permissions because its upstream Compose templates
require that path for the desktop, Flatpak, and device setup used by the rendered client.

Use `-WorldName` and `-WorldSourceDir` when testing a different local world save.

To apply WSL limits and restart WSL before the run:

```powershell
.\fieldlab\scripts\run-autonomous-valheim-lab.ps1 `
  -Clients 1 `
  -Profile server_4c_16gb `
  -ApplyWslLimits `
  -ShutdownWsl `
  -Start
```

## Related Docs

- `docs/thesis-gold-local-lab-plan.md`
- `docs/lumberjacks-native-runtime-era-save-plan.md`
- `network/observability-and-experiments.md`
- `network/telemetry-and-scores.md`
