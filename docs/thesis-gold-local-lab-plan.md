# Thesis Gold Local Lab Plan

## Purpose

Use the local hardware and LAN as a repeatable experiment lab for Comfy NetworkSense and
Lumberjacks native runtime work.

The standard is Thesis Gold: prove claims with reproducible experiments, real artifacts, and
publishable result packets.

The first proof target is:

```text
Thesis Gold networking integration with Lumberjacks
-> no-mod fallback path
-> progressive enhancement path
-> visible traffic classification and prioritization
-> consistent player experience under pressure
```

The first audience is the blended group of Comfy insiders, technical peers, and potential
collaborators. The output should teach the system rather than just claim a benchmark.

Every meaningful experiment should produce:

```text
goal
approach
method
results
signature
reproducible steps
publishable summary
```

The lab should offload cognitive load. The machine should remember the setup, run the scenario,
collect telemetry, package evidence, and draft the result summary.

## Local hardware profile

Observed from the workstation screenshot:

- GPU: NVIDIA GeForce RTX 5070
- dedicated GPU memory: 12 GB
- system memory: 127 GB, with about 31 GB in use at capture time
- shared GPU memory available: about 72 GB
- CPU idle/low load at capture time, roughly 4.39 GHz shown
- storage: NVMe system disk
- NPU: Intel AI Boost available

Practical meaning:

- enough RAM to run backend services, PostgreSQL/DuckDB, bot swarms, WSL/VMs, local dashboards, and
  capture tooling at the same time
- enough GPU to run multiple rendered clients, capture/video encoding, and a local model sidecar
- enough local headroom to brute-force scenarios before using LAN machines
- enough disk throughput for large Era save parsing, telemetry logs, and rendered benchmark outputs

Do not depend on the NPU for core workflows. Treat it as an opportunistic acceleration target later.

## Lab principles

### 1. Thesis Gold is the bar

For Lumberjacks-native networking, an experiment should map to at least one Thesis Gold criterion:

- server-authoritative input-driven simulation
- formal reliable/datagram lane separation
- compact binary hot path
- interest management before brute-force broadcast
- graceful transport fallback
- delta compression or equivalent bandwidth thinning
- client prediction/reconciliation
- adaptive AoI or packet priority under pressure
- explainable telemetry and replayable evidence

Throughput matters, but it is not the whole point. The main proof is that traffic has a visible
shape:

- which packets are game-critical
- which packets are fidelity or cosmetic
- which packets can degrade safely
- what gets prioritized under pressure
- what a no-mod/no-enhancement client still receives
- what an enhanced client gains
- why this gives creators more freedom without making player experience inconsistent

### 2. Local first, LAN second, cloud third

Use the workstation first because iteration speed matters.

Escalation ladder:

```text
single process simulation
-> local multi-process bots
-> Docker/WSL service stack
-> local rendered Godot clients
-> Hyper-V/WSL/Windows Sandbox client isolation
-> other LAN machines
-> cloud/Azure only after local evidence is stable
```

### 3. Real Comfy data should drive stress

Use `erasave/ComfyEra12.db`, `erasave/ComfyEra16.db`, `waypoints.json`, and StewardView exports to
seed test cases.

Synthetic tests are useful, but the important stress shapes should come from:

- real build-density cells
- real portal clusters
- real settlement signatures
- real container/economy distributions
- real creator/guild hotspots

For the first networking proof, treat Era 12 and Era 16 as density maps and baseline corpora, not
as named Hall of Fame showcases. Hall of Fame data can come later after the technical proof earns
support.

### 4. Experiment packets beat memory

No experiment should depend on remembering what was done last time.

Each run should emit a folder that contains enough context for a future reader or agent to rerun or
audit it.

### 5. Privacy by default

Keep a local manifest that maps real player/build names to public aliases.

Public reports should use:

```text
Viking1
Viking2
...
Viking32
VikingXX
```

Real names can be restored only after asking permission.

## Proposed lab folder layout

```text
fieldlab/
  README.md
  hardware/
    workstation-profile.json
    lan-machines.json
  scenarios/
    thesis-gold-progressive-enhancement.yaml
    delta-compression-idle-crowd.yaml
    client-prediction-latency.yaml
    era16-density-aoi.yaml
    packet-priority-pressure.yaml
  runs/
    20260704-153000-era16-density-aoi/
      experiment.yaml
      environment.json
      commands.ps1
      services.json
      raw/
      telemetry/
      captures/
      results.json
      report.md
      publish.md
      signature.json
  scripts/
    run-experiment.ps1
    collect-environment.ps1
    summarize-run.ps1
    publish-packet.ps1
```

This does not need to exist all at once. Start with the run packet shape and one runner.

## Experiment packet contract

Every run folder should contain these files.

### `experiment.yaml`

The input definition.

Fields:

- `id`
- `title`
- `goal`
- `hypothesis`
- `thesis_gold_criteria`
- `approach`
- `scenario`
- `services`
- `clients`
- `bots`
- `network_conditions`
- `datasets`
- `metrics`
- `pass_fail_gates`
- `publish_scope`

### `environment.json`

Captured automatically before the run.

Fields:

- git commit and dirty status for each repo
- OS version
- CPU model and core/thread count
- RAM total/free
- GPU model, driver, VRAM
- storage free space
- Docker/WSL/Hyper-V state
- local IP addresses
- LAN machine inventory when used
- tool versions: `.NET`, Node, Python, Java, Godot, Docker

### `commands.ps1`

The exact commands used to run the experiment.

This must be generated or copied into the run folder before execution.

### `raw/`

Unmodified logs and outputs.

Examples:

- service stdout/stderr
- BepInEx logs
- Lumberjacks service logs
- bot logs
- Godot logs
- `netstat`/port snapshots
- process lists

### `telemetry/`

Structured telemetry.

Examples:

- `client_samples.jsonl`
- `server_samples.jsonl`
- `event_timeline.jsonl`
- `network_bytes.csv`
- `latency_summary.json`
- `aoi_summary.json`
- `packet_lane_summary.json`

### `captures/`

Human-inspectable proof.

Examples:

- screenshots
- short videos
- dashboard exports
- rendered charts
- flamegraphs when available

### `results.json`

Machine-readable outcome.

Fields:

- `status`: `pass`, `fail`, or `inconclusive`
- metric summaries
- pass/fail gate results
- links to raw artifacts
- known caveats

### `report.md`

Internal full report.

Sections:

- Goal
- Approach
- Method
- Results
- Interpretation
- Risks
- Next experiment

### `publish.md`

External-safe writeup.

This is the artifact to share publicly or in a repo discussion.

Rules:

- concise
- no secrets
- no private player data unless explicitly approved
- enough reproduction detail to be useful
- charts/screenshots included by relative path

### `signature.json`

The reproducibility signature.

Fields:

- run ID
- timestamp UTC
- git commit SHAs
- experiment file hash
- main artifacts hash list
- dataset identifiers
- machine ID
- operator
- result status

This is the "we can stand behind this result" record.

## Hardware use plan

### Workstation host

Primary responsibilities:

- run Lumberjacks backend services
- run PostgreSQL and DuckDB
- run ComfyStewardView parse/cache jobs
- run local bot swarms
- run rendered Godot clients for visual tests
- run local dashboards
- collect and package experiment artifacts
- run local model summaries if useful
- coordinate any existing self-learning VM swarm, MCP, or mechnet capacity that can be reused

Recommended local process groups:

- `backend`: Gateway, EventLog, Progression, OperatorApi
- `data`: PostgreSQL, DuckDB/StewardView
- `clients`: Godot clients and bot clients
- `observe`: telemetry collector, dashboard, log tailer
- `summarize`: report generator/local LLM helper

### GPU

Primary use:

- rendered Godot client stress
- visual capture
- video encode through NVENC
- local model assistant for summarizing logs and drafting `report.md`

Avoid using GPU as a hidden dependency for authoritative simulation. The server should remain
CPU/network deterministic unless a specific experiment says otherwise.

### System RAM

Use the large RAM budget for:

- large Era save parsing
- DuckDB caches
- multiple service stacks
- bot swarms
- replay buffers
- local model context
- several isolated clients or VMs

RAM pressure should be logged per experiment. If an experiment only passes because the workstation
has 127 GB RAM, that is still useful, but the report must say so.

### WSL, Docker, and VMs

Use Docker/WSL for service isolation and Linux tooling.

Use Hyper-V/Windows Sandbox/VMs when client isolation matters:

- separate IPs
- separate process environments
- independent resource caps
- network shaping
- multi-client behavior without extra physical machines

Network impairment options:

- Windows firewall/QoS rules for coarse constraints
- Linux `tc/netem` inside WSL or Linux VMs for latency/jitter/loss tests
- router/LAN-level shaping if available
- real LAN machines for non-synthetic Wi-Fi/Ethernet behavior

### LAN machines

Use other local machines as reality checks after local simulation works.

Known machines:

- `AM4`: Linux, 32 GB DDR4, two Intel Arc Pro B70 GPUs, connected through local tailnet
- `i5-laptop`: 12th gen Intel i5 laptop, 32 GB RAM, integrated graphics, connected through local
  tailnet

Roles:

- host-only machine
- client-only machine
- weak-client machine
- Wi-Fi client
- wired client
- capture/observer machine

Each LAN machine should have a small profile in:

```text
fieldlab/hardware/lan-machines.json
```

Include:

- machine nickname
- CPU/RAM/GPU
- OS
- connection type
- local IP
- installed tools
- known limitations

## First experiment set

### Experiment 1: Thesis Gold progressive enhancement baseline

Goal:
prove the Lumberjacks networking flow with no-mod fallback and enhanced-client progressive
enhancement.

Method:

- start local backend services
- run existing unit tests
- run existing E2E scripts
- run 50-bot and 100-bot load tests
- capture service logs, byte counts, and lane classifications
- run at least one fallback path where the client receives the conservative reliable/core stream
- run at least one enhanced path where datagram/binary/priority behavior is visible
- render a traffic-flow summary showing reliable core, datagram fidelity, fallback, and dropped or
  deferred low-priority traffic

Pass gates:

- unit tests pass
- E2E scripts pass
- 50-bot test has zero errors
- critical events are not lost
- report includes bytes/sec, packet lane split, CPU, RAM, latency summary, and traffic category
  diagram
- report explains what creators gain from the policy, not just what engineers optimized

### Experiment 2: Era 16 density AoI replay

Goal:
test interest management against real Comfy density distributions.

Method:

- export top `build_density_cells` from Era 16
- convert selected cells into proxy entity clouds or settlement signatures
- spawn clients near, mid, and far from those cells
- measure entity updates per client, bytes/sec, and frame cost

Pass gates:

- far clients do not receive irrelevant high-density updates
- near clients receive bounded update volume
- report identifies the density threshold where adaptive AoI is needed

### Experiment 3: Delta compression idle crowd

Goal:
prove idle or low-motion crowds do not waste hot-path bandwidth.

Method:

- spawn 10, 25, 50, and 100 entities/clients in a region
- hold most entities idle
- compare full update versus delta/thinned update path

Pass gates:

- idle unchanged entities produce near-zero repeated payloads after initial sync
- full-sync safety interval is visible and bounded
- bandwidth savings are reported by scenario

### Experiment 4: Client prediction latency

Goal:
prove local input response remains good under realistic RTT.

Method:

- run local clients under 0 ms, 50 ms, 100 ms, and 200 ms artificial latency
- compare interpolation-only versus prediction/reconciliation
- record correction frequency and magnitude

Pass gates:

- predicted client feels immediate locally
- reconciliation corrections stay below a visible threshold in normal movement
- high-latency caveats are documented

### Experiment 5: Packet priority under pressure

Goal:
prove the engine preserves core gameplay before fidelity.

Method:

- create a crowded region with movement, settlement proxies, and low-priority cosmetic updates
- induce packet pressure or bandwidth cap
- compare behavior with and without priority-ranked replication

Pass gates:

- reliable/game-critical events complete
- low-priority traffic is deferred or dropped first
- telemetry explains the decision

### Experiment 6: LAN host/client comparison

Goal:
validate that local single-machine results survive real network clients.

Method:

- workstation hosts backend
- one or more LAN machines connect as clients
- run a scripted movement/settlement route
- compare host/server view against each client view

Pass gates:

- session IDs align
- client/server telemetry bundles compare cleanly
- report separates network effects from local client performance

## Cognitive-load offload workflow

The desired operator workflow:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\era16-density-aoi.yaml
```

The runner should:

1. create a timestamped run folder
2. copy the scenario file into it
3. collect environment information
4. verify required datasets exist
5. start services
6. wait for health checks
7. start bots/clients
8. apply network shaping if requested
9. collect telemetry and logs
10. run pass/fail checks
11. render charts or summaries
12. write `results.json`
13. draft `report.md`
14. draft `publish.md`
15. write `signature.json`
16. stop services unless `--keep-running` is set

The runner does not need to be perfect at first. Even a partial runner is useful if every run folder
has the same shape.

Resource-heavy runs are allowed when scheduled. Overnight runs, high RAM use, GPU saturation,
multi-VM tests, large telemetry folders, and frontier-model summaries are acceptable if the run
packet records what was consumed.

## Publish standard

A result is publishable only if it includes:

- the exact experiment goal
- the exact commit or build identifiers
- hardware/environment summary
- input dataset summary
- commands or runner reference
- raw metrics
- pass/fail gates
- caveats
- next-step recommendation

Publish outputs should be generated from the same run packet:

- field notes: step-by-step narrative of how the result was produced
- technical overview: architecture, traffic lanes, metrics, and gates
- quick start: shortest reproduction path for a collaborator

Avoid claims like "works great" or "scales well" without a number and a reproduction path.

Good claim:

```text
In the Era16 density AoI replay, a far observer received 0 high-density settlement entity updates
after initial anchor metadata, while a near observer received 20 Hz updates for the active local
proxy set and 5 Hz mid-band updates. Run packet: fieldlab/runs/<id>.
```

Bad claim:

```text
The new networking is much better.
```

## First build task

Create the minimal local lab skeleton:

```text
fieldlab/
  README.md
  scenarios/thesis-gold-progressive-enhancement.yaml
  scripts/collect-environment.ps1
  scripts/run-experiment.ps1
```

The first runner can be simple:

- create run folder
- collect `git status`, OS, RAM, GPU, .NET, Node, Python, Java versions
- run a command list from the scenario
- capture stdout/stderr
- write `results.json`
- write `signature.json`

After that, add scenario-specific collectors.

## Success criteria

This lab is working when:

- experiments can be rerun without relying on memory
- every result has a signed artifact folder
- local brute-force results can be compared against LAN-machine results
- Thesis Gold gaps are measured directly instead of debated
- Comfy save-derived scenarios become regular benchmark inputs
- a publishable report can be generated with minimal manual writing
- incremental steps produce tangible artifacts that stay aligned with the initial goal and scoring
- missing artifacts or failing gates trigger reassessment before scope expands
