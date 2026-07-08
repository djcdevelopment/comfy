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

## 2026-07-08 Live Mirror Verification

The live BepInEx-to-EventLog path has now passed twice on the real Era16 route.
The latest completed run is:

```text
fieldlab/runs/20260708-091406-valheim-lumberjacks-priority-live-mirror
```

Status:

```text
pass_priority_live_mirror
```

Latest manifest:

```text
manifest_id: valheim-live-priority-20260708-160502-635debf9
session_id:  20260708-160328-2c2146d7
phase:       ready_for_gateway_priority_delivery
```

Key result:

- `72` local sample rows matched `72` EventLog sample events;
- `72` local object-batch posts matched `72` EventLog object-batch events;
- `11,544` local object rows matched `11,544` EventLog object records;
- `1` completion event was observed in EventLog;
- `posted_failed` was `0`;
- all four live verifier gates passed: mirror status, EventLog round trip,
  local/remote count match, and route completion.

Operational nuance: the mirror stop row can show `queued_posts_at_stop: 1`
because the completion event is queued immediately before the stop status row is
written. The EventLog verifier is the correct completion gate; it observed the
completion event.

The current in-game command remains:

```text
network_sense_lumberjacks_priority_route_mirror teleport-route.tsv 256 5 192 http://127.0.0.1:4002
```

The verifier command is:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-lumberjacks-priority-live-mirror.yaml
```

## 2026-07-08 Gateway Plan State

The next build target has moved from "can Valheim stream a priority side
channel?" to "can Gateway consume and shape that priority side channel?"

Lumberjacks commit:

```text
03619f3 Add Valheim priority manifest gateway plan
```

That commit adds:

- a contract-level `ValheimPriorityDeliveryPlanner`;
- `priority_manifest` as a reliable protocol message type;
- a Gateway service that queries Lumberjacks EventLog for
  `valheim.priority_manifest.objects`;
- a Gateway endpoint shape:

```text
GET /valheim/priority-manifests/{manifestId}/delivery-plan?reliableBudget=256&datagramBudget=768&eventLimit=500
```

The delivery plan separates objects into reliable, datagram, and deferred
buckets. Current reliable tiers are:

- `player_critical`
- `portal`
- `structural_anchor`
- `storage_crafting`

Verification caveat: the Gateway project compiled successfully with the local
.NET 9 SDK using an alternate output directory. Runtime smoke tests and VSTest
execution were blocked by Windows Smart App Control loading freshly built
unsigned DLLs (`0x800711C7`). This is an environment/code-signing issue, not a
compile failure. Avoid broad Defender exclusions; Smart App Control is separate
from Defender AV exclusions.

Next concrete build step:

1. Start or update Gateway from normal trusted repo output once Smart App
   Control is no longer blocking local build artifacts.
2. Query the latest live manifest through the new delivery-plan endpoint.
3. Add a FieldLab verifier that compares the Gateway plan counts against the
   live mirror EventLog counts.
4. Then wire actual socket emission: reliable `priority_manifest` metadata over
   WebSocket, transient/detail updates over the datagram lane, with deferred
   objects explicitly visible to operators/builders.

## 2026-07-08 Gateway Activation/Broadcast Build

Lumberjacks now has the next Gateway slice built locally on top of the delivery
plan endpoint. New commit:

```text
030eac8 Add priority manifest activation broadcast
```

This extends the Gateway priority manifest path with:

- `POST /valheim/priority-manifests/{manifestId}/activate`
- `GET /valheim/priority-manifests/active`
- `POST /valheim/priority-manifests/{manifestId}/broadcast`

The activate endpoint loads the live EventLog manifest, shapes it with the
reliable/datagram/deferred planner, and caches the active plan in Gateway. The
broadcast endpoint activates the plan and emits a reliable
`priority_manifest` WebSocket envelope to currently connected sessions. The
broadcast payload carries the reliable item set, a datagram manifest index, and
deferred counts by tier. It still does not replace vanilla Valheim replication.

Build verification:

```powershell
C:\work\dotnet9\dotnet.exe build .\src\Game.Gateway\Game.Gateway.csproj --no-restore -p:UseSharedCompilation=false -p:OutDir=C:\work\lj-build-check\
```

Result: build succeeded with `0` warnings and `0` errors. The temporary build
folder was removed after verification.

FieldLab now has a Gateway-plan verifier:

```text
fieldlab/scenarios/valheim-lumberjacks-priority-gateway-plan.yaml
fieldlab/command-plans/valheim-lumberjacks-priority-gateway-plan.ps1
```

Verifier command:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-lumberjacks-priority-gateway-plan.yaml
```

First packet against the currently running Gateway:

```text
fieldlab/runs/20260708-092311-valheim-lumberjacks-priority-gateway-plan
```

Status:

```text
blocked_gateway_priority_endpoint
```

This is expected because the live Gateway process on `localhost:4000` is still
the older build and returned `404` for the priority endpoint. The packet is
useful: it proves the verifier reads the latest live Valheim manifest
(`valheim-live-priority-20260708-160502-635debf9`) and is ready to compare
Gateway counts once the updated Gateway is deployed/running.

Next concrete step:

1. Restart or deploy Gateway with the new priority activation/broadcast commit.
2. Rerun the Gateway-plan FieldLab verifier.
3. Expected pass shape:
   - matched Gateway EventLog object-batch events: `72`;
   - Gateway total input objects: `11,544`;
   - reliable + datagram + deferred equals Gateway unique object count;
   - activation returns the same manifest id and total input object count.
4. Then attach an observation client and validate that the reliable
   `priority_manifest` WebSocket envelope is received before moving transient
   detail to the datagram lane.

## 2026-07-08 Gateway Deploy + Verifier Pass + Observation Client

All three next steps above are now done:

1. Killed the stale Gateway process and rebuilt `Game.Gateway` at `030eac8`
   into its normal `bin/Debug/net9.0` output (not a temp `OutDir`, so Smart
   App Control did not block it). Relaunched with
   `dotnet exec Game.Gateway.dll` via the `.NET 9` SDK at `C:\work\dotnet9`
   (the apphost's default global `dotnet` only has 8.0.28 registered).
2. `run-experiment.ps1` hung indefinitely (near-zero CPU, no output) on this
   scenario before it got to spawning the command-plan child process — cause
   not yet found. Worked around by invoking
   `fieldlab/command-plans/valheim-lumberjacks-priority-gateway-plan.ps1`
   directly against a run dir. This is a known gap for the next session to
   chase if it recurs.
3. The plan verifier now passes:

   ```text
   status: pass_priority_gateway_plan
   phase:  ready_for_socket_delivery
   ```

   All four gates green: `gateway_delivery_plan`, `manifest_counts_match`
   (11,544 = 11,544), `bucket_accounting` (256 reliable + 700 datagram + 0
   deferred = 956 unique), `activation`.

4. Added `fieldlab/scripts/observe_priority_manifest.py`, a minimal asyncio
   WebSocket observation client (connects, logs `session_started`, waits for
   a `priority_manifest` envelope, pretty-prints it, exits). Ran it against
   `ws://localhost:4000/`, then `POST /valheim/priority-manifests/{id}/broadcast`
   for `valheim-live-priority-20260708-160502-635debf9`
   (`target_sessions: 1, sent_sessions: 1`). The client received the reliable
   `priority_manifest` envelope with the exact activated-plan counts.

This closes the loop end to end: EventLog manifest → Gateway delivery plan →
activation → broadcast → WebSocket client. Vanilla Valheim replication was
never touched.

Next phase (not started — needs a call on priorities first): move transient
and detail objects onto the datagram lane instead of only ever filling the
reliable lane, and decide what a real in-game client should do with a
received `priority_manifest` (currently only the standalone Python observer
consumes it).

## 2026-07-08 Datagram Lane Wired + UDP Crash Fix

Re-validated the whole pipeline first against a brand-new live route (not
just the cached manifest): Derek ran
`network_sense_lumberjacks_priority_route_mirror teleport-route.tsv 256 5 192
http://127.0.0.1:4002` in-game, producing manifest
`valheim-live-priority-20260708-173949-6f82f51d` (72/72 sample/object-batch
events, 11,544 objects, 0 posted failures). The gateway-plan verifier and the
observation client both passed again against it with the identical bucket
shape (256 reliable / 700 datagram / 0 deferred = 956 unique).

Then built the datagram lane itself:

- `Game.Contracts`: `MessageType.PriorityManifestObject` /
  `MessageTypeId.PriorityManifestObject = 17`, classified `Datagram` in
  `MessageClassification`.
- `ValheimPriorityManifestEndpoints.SendDatagramObjects()`: sends each
  `Plan.Datagram` item as its own UDP frame — a JSON payload wrapped in a
  `BinaryEnvelope`, same fallback pattern `GameWebSocketMiddleware` already
  uses for non-hot-path types, so no new fixed-field byte format was needed.
  `/broadcast` now also reports `datagram_objects_sent` and
  `datagram_sessions_without_udp`.

While verifying this, found and fixed a real bug, not just a test artifact:
`UdpTransport.ExecuteAsync`'s receive loop only caught
`OperationCanceledException`. A Windows ICMP port-unreachable response to a
send poisons the socket, and the next `ReceiveAsync` throws
`SocketException 10054` — unhandled, this crashed the *entire* Gateway host
(`BackgroundServiceExceptionBehavior=StopHost`). This is a pre-existing
latent fragility in the UDP transport (would affect `EntityUpdate` too, not
just this new feature). Fixed with the `SIO_UDP_CONNRESET` ioctl on the
`UdpClient` at startup plus a defensive `SocketException` catch in the
receive loop. Also added exception logging to `UdpTransport.TrySend`, which
previously swallowed all send failures silently.

Verification: rewrote `fieldlab/scripts/observe_priority_manifest.py` to add
a real UDP client — does the `session_started` → `udp_token`/`udp_port`
handshake (8-byte token + 6-byte dummy `BinaryEnvelope` header; a bare
8-byte packet is below the server's 14-byte `MinPacketSize` and gets
dropped), listens via a plain blocking socket in a background thread
(asyncio's `create_datagram_endpoint` alongside the `websockets` client
caused the WS session to detach almost immediately — root cause not fully
diagnosed, the thread+blocking-socket rewrite sidesteps it and is more
robust regardless), and decodes the 6-byte bit-packed header per
`BitWriter`'s MSB-first layout. Final run:
`datagram_objects_received=700 expected=700`, sample object matched the
plan exactly.

Both threads from the last handoff are done: the datagram lane ships and is
proven end to end. The only open item now is a real in-game/mod-side
consumer of `priority_manifest` — currently only this standalone Python
script observes it; nothing in ComfyNetworkSense reacts to it yet.

## 2026-07-08 Real In-Game Consumer

ComfyNetworkSense `0.5.2` adds the first in-game consumer of the reliable
`priority_manifest` broadcast:

```text
network_sense_lumberjacks_priority_manifest_listen [start|stop|status] [ws-url] [region-id]
```

New `LumberjacksPriorityManifestListener` (`Core/Services`), modeled directly
on `LumberjacksProjectionRunner`'s WS receive-loop pattern (regex-based JSON
field extraction — the mod is net48/Unity and does not reference
Lumberjacks' .NET 9 `Game.Contracts` assemblies, so message parsing stays
hand-rolled like the rest of the Lumberjacks bridge code). It connects,
joins the given region, and on each `priority_manifest` envelope records
manifest_id and all five counts to a new
`priority-manifest-listen.jsonl` (same convention as
`lumberjacks-projection.jsonl`, `priority-mirror.jsonl`, etc). Built clean,
0 warnings/errors, and auto-installed to the live Steam BepInEx/plugins
folder via the existing `CopyAssembly` post-build target.

Scope note: this listener only consumes the **reliable** envelope — it does
not yet consume the datagram-lane `priority_manifest_object` UDP frames
in-game. That path is proven only via the standalone Python observer so
far. Left as an explicit follow-up rather than scope-creeping this slice.

Next concrete step: launch Valheim, load Era16, run
`network_sense_lumberjacks_priority_manifest_listen start`, then POST
`/valheim/priority-manifests/{manifestId}/broadcast` against the Gateway
and confirm a `priority-manifest-listen.jsonl` row plus an in-game HUD
message appear.

## 2026-07-08 Confirmed Live In-Game

Ran for real: `network_sense_lumberjacks_priority_manifest_listen start` in
the live Valheim console (session `8f375b0f`, joined `region-spawn`). The
Gateway broadcast for `valheim-live-priority-20260708-173949-6f82f51d`
produced a `priority_manifest` row in `priority-manifest-listen.jsonl` with
`total_input_objects=11544, unique_objects=956, reliable_count=256,
datagram_count=700, deferred_count=0` — an exact match to the broadcast
response. This is the full real proof, not just the standalone Python
observer: live Valheim client → `ComfyNetworkSense 0.5.2` →
Lumberjacks Gateway → real in-game consumer, end to end.

All three original handoff threads are closed: Gateway rebuild/deploy,
datagram lane, real in-game consumer. Open follow-up, not yet started:
consume the datagram-lane `priority_manifest_object` frames in-game too
(currently reliable-lane only).

## 2026-07-08 Datagram Lane In-Game Consumption (built, not yet tested)

Closed the last open gap: `LumberjacksPriorityManifestListener` now also
consumes the datagram lane. On `session_started` it extracts
`udp_token`/`udp_port`, opens a `UdpClient`, sends the 14-byte handshake
(8-byte token + 6-byte zero header — matching the Python observer's fix),
and runs a background receive loop decoding the same MSB-first 6-byte
`BinaryEnvelope` header to filter for `type=17`
(`PriorityManifestObject`), counting frames into
`_datagramObjectsReceived`. Three seconds after each reliable
`priority_manifest` envelope, it emits a follow-up `datagram_summary` row
to `priority-manifest-listen.jsonl` comparing received vs. expected
`datagram_count`.

`ComfyNetworkSense 0.5.3` built clean and the DLL was overwritten
successfully in the live BepInEx/plugins folder — Windows did **not** lock
it while Valheim was running (unlike the Gateway `.exe`, which does hold
its own output locked). But the already-running Valheim session still has
`0.5.2` loaded in memory; **a Valheim restart is required** before this can
be exercised and verified live. Not yet tested.

## 2026-07-08 Datagram Loss Found + Fixed (0.5.4)

First live test of the datagram-lane consumer (0.5.3, after restart) showed
a real problem: the Gateway confirmed `datagram_objects_sent: 700`, but the
mod's `datagram_summary` row only ever showed `datagram_objects_received: 28`
— and it stayed at 28 for several minutes, ruling out "still trickling in."

Two contributing bugs in `LumberjacksPriorityManifestListener`:

- The receive loop issued a fresh `ReceiveAsync()` every iteration and
  abandoned the previous one whenever a 500ms poll timeout fired, silently
  dropping whichever packet the orphaned call ended up completing with.
- The default OS UDP receive buffer is far smaller than a 700-packet burst
  arriving almost instantly over loopback, so the OS itself silently drops
  the overflow before the loop ever gets a chance to drain it.

Fixed both: a single directly-awaited receive per iteration (shutdown now
delivered by closing the socket via `token.Register`, not by polling a
timeout), plus `ReceiveBufferSize` bumped to 4 MiB. `ComfyNetworkSense
0.5.4` built and installed (again while Valheim was running — the DLL is
never locked, only the in-memory session lags behind).

Re-tested live after another restart: `datagram_objects_received=700
expected=700` — full recovery, confirmed.

This closes the priority-manifest thread completely. Both lanes (reliable
and datagram) are now proven live in-game end to end, not just via the
standalone Python observer, including a real UDP reliability bug found and
fixed along the way.

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
