# Handoff - Lumberjacks Priority Path - 2026-07-08

## Decision

Do not make shadow movement the next gating build. It has done its job as a
diagnostic:

- the live Valheim BepInEx process can speak to Lumberjacks Gateway;
- route-backed shadow runs write durable JSONL;
- stationary route drift is effectively zero across the six Era16 stops;
- 20 Hz and axis movement runs are directionally useful, but movement precision is
  noisy on the shared dev box and is not the product value path.

Movement work is parked unless it blocks the priority/load-order probe.

## North Star

Valheim's native networking remains the compatibility floor. Lumberjacks is the
progressive enhancement layer:

- dual-channel broadcast under high traffic;
- explicit priority metadata and load-order hints;
- filtering and routing that can stay stable when vanilla replication is noisy;
- operator-visible expectations about which state should arrive first.

The builder-facing payoff is predictable high-density loading. Player-critical
state, portals, structural anchors, and nearby interactive pieces should be
discoverable ahead of distant cosmetic/support noise, so large bases can be
designed around known load behavior instead of best effort replication.

## Next Experiment

Build a local priority/load-order probe. The first version should observe and
classify nearby Valheim objects; it should not write ZDOs or replace vanilla
replication.

Proposed command shape:

```text
network_sense_lumberjacks_priority_probe [start|stop|status] [radius] [ws-url] [region-id]
```

Route-integrated form is also acceptable if it fits the existing shadow-route
runner better:

```text
network_sense_lumberjacks_priority_route teleport-route.tsv [radius] [scan-interval] [max-objects]
```

## 2026-07-08 Build Update

ComfyNetworkSense `0.5.0` now implements the first local priority/load-order
probe:

```text
network_sense_lumberjacks_priority_probe [start|stop|status] [radius] [scan-interval] [max-objects]
network_sense_lumberjacks_priority_route [teleport-route.tsv] [radius] [scan-interval] [max-objects]
```

Rows are written to:

```text
BepInEx/config/comfy-network-sense/priority-load.jsonl
```

The route command reuses the six-stop Era16 `teleport-route.tsv`, scans each
stop during the benchmark window, emits sample and per-object rows, and exports
the NetworkSense session at the end. The first FieldLab packet is staged at:

```text
fieldlab/runs/20260708-032910-valheim-lumberjacks-priority-load-order
```

Current in-game command:

```text
network_sense_lumberjacks_priority_route teleport-route.tsv 96 5 96
```

After it completes, rerun:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-lumberjacks-priority-load-order.yaml
```

The packet exposes an MCP phase marker in `raw/valheim-console-commands.txt` so
the next agent can use the event channel to pick up the next phase after each
run instead of manually reconstructing state.

## 2026-07-08 Run Result

The first 96m route passed the scanner mechanics but left visibility gaps. A
second 256m route completed and produced the current decision packet:

```text
fieldlab/runs/20260708-042303-valheim-lumberjacks-priority-load-order
```

Status:

```text
pass_priority_route_observed_with_sparse_gap
```

Key result:

- all six route stops produced priority sample rows;
- `72` sample rows and `11,544` object rows were collected;
- `5/6` stops had non-player priority objects; the sparse stop still had no
  non-player priority objects at 256m, so carry it as a fixture note rather than
  a scanner failure;
- max scan duration was `66ms`;
- dense/extreme saturated the collider buffer at 256m, so future probes should
  avoid unbounded wider scans and should move toward staged/priority-targeted
  collection;
- no Valheim ZDO writes, ZNetView ownership changes, transform corrections, or
  vanilla replication replacement were applied.

Next phase:

```text
network_sense_mcp_mark lumberjacks_priority_manifest_ready
```

Build the Lumberjacks mirror phase next: send the observed priority manifest as
ordered side-channel metadata and compare delivery/order under load. Do not keep
increasing scan radius; the 256m pass already found the practical limit shape.

## 2026-07-08 Mirror Update

The FieldLab mirror packet now passes against Lumberjacks EventLog:

```text
fieldlab/runs/20260708-075942-valheim-lumberjacks-priority-mirror
```

Status:

```text
pass_priority_mirror_with_sparse_fixture_note
```

Key result:

- `72` priority sample events posted;
- `962` object records mirrored as `6` per-stop object-batch events;
- `79/79` EventLog posts accepted;
- `72` sample events, `6` object-batch events, and `1` completion event queried
  back;
- object sequence set preserved end to end;
- the sparse fixture note still carries forward from the route manifest.

Operational note: the local Lumberjacks Postgres container must be running and
the `events` table must exist. The mirror command plan now preflights the
Postgres port and uses UUID `event_id` values because the EventLog persistence
model maps `event_id` to PostgreSQL `uuid`.

Next phase:

```text
network_sense_mcp_mark lumberjacks_priority_mirror_ready
```

Build the live mirror/dual-channel phase next. The practical target is to move
from FieldLab replay into runtime delivery: either BepInEx emits the same
per-stop priority batches as it scans, or Gateway learns a first-class priority
manifest message that can be promoted into the reliable/datagram split.

## 2026-07-08 Live Mirror Build

ComfyNetworkSense `0.5.1` adds the live BepInEx-to-Lumberjacks EventLog mirror:

```text
network_sense_lumberjacks_priority_mirror [start|stop|status] [eventlog-url]
network_sense_lumberjacks_priority_route_mirror [teleport-route.tsv] [radius] [scan-interval] [max-objects] [eventlog-url]
```

Recommended in-game command for the next run:

```text
network_sense_lumberjacks_priority_route_mirror teleport-route.tsv 256 5 192 http://127.0.0.1:4002
```

The route-integrated command starts the mirror before the priority route, emits
sample events plus per-sample object-batch events to EventLog as scans happen,
then posts a completion event before the NetworkSense session export. Local
`priority-load.jsonl` remains the source-of-truth telemetry, and mirror status
is written to `priority-mirror.jsonl`.

The Steam Valheim plugin and autonomous lab plugin copies have been updated to
assembly version `0.5.1.0`. Valheim must be restarted to load this DLL.

## What To Capture

Emit `priority-load.jsonl` from the Valheim plugin. Each row should include:

- run/session id, route stop id, density band, timestamp, and player position;
- object/prefab name, distance, owner/creator fields where safely available;
- priority tier and the heuristic that assigned it;
- discovery/order counters from the local Valheim scan;
- optional Lumberjacks stream/sequence fields when mirrored to Gateway/EventLog.

Initial priority tiers:

- `player_critical`
- `portal`
- `structural_anchor`
- `near_interactive`
- `storage_crafting`
- `support_piece`
- `decorative_far`

Keep the first classifier simple: use prefab names, known Valheim components, and
distance. Refine the heuristics only after one route packet shows which fields are
actually reliable in live BepInEx.

## Success Bar

The next useful proof is one local Era16 route packet where:

- all six density stops produce priority rows;
- dense/extreme stops identify high-priority classes without unbounded scan cost;
- the FieldLab packet summarizes counts/order by density band and priority tier;
- vanilla replication remains untouched.

This proves the practical value path: Lumberjacks can provide a stable ordered
side channel that builders and operators can reason about under load.

## Do Not Chase Next

- Do not tune shadow movement drift unless it blocks this probe.
- Do not attempt ZDO transport replacement yet.
- Do not revisit GPU-less container rendering or headless-client swarms.
- Do not invite volunteer testing until the local priority packet exists.

## Current Evidence

- Feasibility framing: `fieldlab/VALHEIM-LUMBERJACKS-FEASIBILITY.md`
- Clean stationary route packet:
  `fieldlab/runs/20260708-001549-valheim-lumberjacks-shadow-route`
- 20 Hz movement comparison:
  `fieldlab/runs/20260708-022138-valheim-lumberjacks-shadow-route/telemetry/movement-20hz-vs-baselines.md`
- Axis north diagnostic:
  `fieldlab/runs/20260708-022138-valheim-lumberjacks-shadow-route/telemetry/axis-north-vs-baselines.md`
