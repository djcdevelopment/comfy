# Valheim on Lumberjacks Feasibility

## Purpose

The question is not whether Lumberjacks works by itself; the native smoke packet already proved
that path. The question is how far a live Valheim client/server can be attached to Lumberjacks
before Valheim's own authority model gets in the way.

This file treats "Valheim on Lumberjacks" as a set of increasingly invasive layers. The early goal
is to find the first hard boundary with runnable probes, not to assume a full transport rewrite.

## Strategic Value Target

Shadow movement is a diagnostic, not the main payoff. The first real benefit of attaching Valheim
to Lumberjacks is ordered, dual-channel broadcast under high traffic. If Lumberjacks can provide a
stable side channel for priority metadata and update ordering, builders can design large bases with
clear expectations about what arrives first when traffic is saturated: structural anchors, nearby
interactive pieces, portals, and player-critical state should win over cosmetic or distant changes.

The larger gain is progressive enhancement. Valheim's default networking remains the compatibility
floor, while Lumberjacks adds packet filtering, routing, prioritization, and load-order hints that
Iron Gate's default Unity-derived stack was never designed to express. The next useful experiments
should not chase full physics replacement first; they should prove that Lumberjacks can make
high-density build loading more predictable and more operator-controllable without breaking vanilla
replication.

## Current Evidence

- Lumberjacks can run its own Gateway/EventLog/Progression/OperatorApi stack and move entity
  updates over UDP under load.
- Valheim still owns its native runtime: `ZNet`, `ZDOMan`, `ZNetView`, `ZRoutedRpc`, Steam/PlayFab
  sockets, save/load, object ownership, physics, and RPC dispatch.
- Local assembly inspection confirms those Valheim networking types and private ownership fields
  exist, but method-level reflection against Unity/Mono metadata can crash. Keep probes narrow and
  in-game.
- ComfyNetworkSense `0.4.4` adds the first live bridge probe:

```text
network_sense_lumberjacks_probe [ws-url] [region-id] [input-count]
```

The probe connects from the Valheim plugin process to Lumberjacks Gateway, joins a region, sends
JSON `player_input`, and records whether `entity_update` rows come back.

ComfyNetworkSense `0.4.5` adds the first local-only projection command:

```text
network_sense_lumberjacks_projection [start|stop|status] [ws-url] [region-id]
```

Projection keeps a Lumberjacks WebSocket open, parses `world_snapshot` and `entity_update`, and
renders plain Unity primitive markers anchored in front of the local Valheim player. It deliberately
does not add `ZNetView`, does not write ZDOs, and does not claim Valheim authority.

## Feasibility Matrix

| Layer | Status | What It Would Prove | Limitation |
| --- | --- | --- | --- |
| Side-channel protocol client | Ready now | Valheim's BepInEx process can speak Lumberjacks Gateway protocol. | Does not affect Valheim gameplay state. |
| Local visual projection | Implemented, needs visual run | Lumberjacks `entity_update` rows can render as local-only Valheim debug/proxy objects. | Still no ZDO ownership or multiplayer replication. |
| Progression/proof/event authority | Likely feasible | Lumberjacks can own quests, events, proof, and operator truth while Valheim remains the renderer/runtime. | Gameplay-critical Valheim combat/building still lives in Valheim. |
| Shadow movement authority | High risk | Lumberjacks can compute authoritative movement in parallel and measure drift. | Applying corrections may fight Valheim prediction, animation, physics, and ZDO ownership. |
| ZDO transport replacement | **THE DESTINATION — hard, unproven-in-full, no hard blocker found (2026-07-08 deep research).** Every primitive it needs is independently demonstrated by shipping mods on a Harmony-reachable Mono runtime (ZDOMan interception, ZNet send-queue control, Steamworks-socket-layer reach — all confirmed via BetterNetworking); no one has been shown to compose them into a complete swap. See `VALHEIM-NETCODE-REPLACEMENT-FEASIBILITY-RESEARCH.md`. | A 100% swap of Valheim's native network layer for Lumberjacks, with Valheim staying the renderer/client. | The genuine disadvantage: Valheim's netcode is Iron Gate's **bespoke** `ZNet`/`ZDOMan`/`ZRoutedRpc` — NOT Mirror/Netcode/Photon — so there is no designed-in transport seam to swap; the interception layer must be hand-built with Harmony against private internals. Also unresolved: legal/anti-cheat posture for redistribution. |
| Valheim dedicated server on Lumberjacks | Depends on how it's scoped | If read as "reimplement Valheim's full simulation on Lumberjacks," that's a different, much larger ask than the row above. If read as "Lumberjacks becomes the authoritative network/replication layer while Valheim's own client simulation still runs," that's the same destination as the row above. | Keep these two framings distinct going forward — conflating them is what produced the earlier premature "not viable" verdict. |

## Run The First Probe

Start or keep running Lumberjacks:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\lumberjacks-native-runtime-smoke.yaml -KeepRunning
```

Restart Valheim so it loads `ComfyNetworkSense 0.4.5`, open the console, then run:

```text
network_sense_lumberjacks_probe ws://127.0.0.1:4000 region-spawn 12
```

The result is written to:

```text
BepInEx\config\comfy-network-sense\lumberjacks-bridge-probes.jsonl
```

## Run The Projection Spike

Restart Valheim so it loads `ComfyNetworkSense 0.4.5`, then run:

```text
network_sense_lumberjacks_projection start ws://127.0.0.1:4000 region-spawn
```

Expected result:

- local proxy markers appear about 8m in front of the Valheim player;
- markers pulse and vertical debug lines are drawn while updates flow;
- status rows are written to:

```text
BepInEx\config\comfy-network-sense\lumberjacks-projection.jsonl
```

Use:

```text
network_sense_lumberjacks_projection status
network_sense_lumberjacks_projection stop
```

Capture the packet:

```powershell
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-lumberjacks-bridge-feasibility.yaml
```

## Pass Interpretation

`pass_sidecar_protocol` means:

- the live Valheim plugin process can connect to Lumberjacks Gateway;
- Lumberjacks accepted the session and region join;
- Valheim sent Lumberjacks `player_input`;
- Lumberjacks returned at least one authoritative `entity_update`.

It does not mean:

- Valheim ZDO replication was replaced;
- Valheim physics authority moved to Lumberjacks;
- Steam/PlayFab sockets were bypassed;
- a Valheim dedicated server is running on Lumberjacks.

## Completed Shadow Spike

Shadow movement authority was built as a diagnostic:

1. Keep Valheim local player movement owned by Valheim.
2. Send equivalent intent to Lumberjacks.
3. Compare Lumberjacks authoritative position against the Valheim local player.
4. Record drift and correction pressure without applying corrections.

That answered whether Lumberjacks can be useful as a shadow side channel before touching the
dangerous ZDO/authority layer. The result is good enough to move on: Gateway connectivity, route
capture, stationary stability, and movement telemetry all work. Exact movement precision is no
longer the gating question.

ComfyNetworkSense `0.4.6` adds the first command for that spike:

```text
network_sense_lumberjacks_shadow [start|stop|status] [ws-url] [region-id] [input-hz]
```

Run it after restarting Valheim with `0.4.6`:

```text
network_sense_lumberjacks_shadow start ws://127.0.0.1:4000 region-spawn 20
network_sense_lumberjacks_shadow status
network_sense_lumberjacks_shadow stop
```

Rows are written to:

```text
BepInEx\config\comfy-network-sense\lumberjacks-shadow.jsonl
```

`pass_shadow_movement_observed` means drift was measured; it still does not prove correction safety
or ZDO transport replacement.

## Current Next Spike

DONE as of 2026-07-08: priority/load-order probing closed the full loop — EventLog manifest,
Gateway delivery plan (reliable/datagram/deferred buckets), a real socket broadcast over both the
reliable WebSocket and the UDP datagram lane, and a real in-game consumer of both lanes (proven
700/700 objects live, after finding and fixing a UDP receive-loop/buffer bug). Full history:

```text
handoffs/HANDOFF-LUMBERJACKS-PRIORITY-PATH.md
```

The real destination is full netcode replacement (the ZDO transport replacement row above), NOT a
side quest. A 2026-07-08 deep-research pass established it as hard-but-open with no discovered hard
blocker — see `VALHEIM-NETCODE-REPLACEMENT-FEASIBILITY-RESEARCH.md`. The next concrete move toward
it is **source-level study of the two most on-point prior-art mods** (`ddormer/valheim-serverside`
and `CW_Jesse/BetterNetworking`), reading their actual patching approach rather than search
snippets — the research flagged valheim-serverside's mechanism as the highest-value unknown.

Smaller still-open threads (not the destination, but genuinely unfinished):

- The older Era16 baseline: `network_sense_rehearsal teleport-route.tsv host_full` has never been
  run in-game (fresh 2026-07-08 check: 6/7 gates pass, `route_completion` pending, `0/6` stops).
  See `NETWORKSENSE-ERA16-MATRIX.md` and `NETWORKSENSE-PERF-DEBUG-PLAN.md`.
- `lumberjacks-native-runtime-smoke` is currently **failing** (2026-07-05 run): the vertical-slice
  and multiplayer probes reject a `place_structure` message with `INVALID_MESSAGE` then time out —
  a real regression in the basic smoke gate, unrelated to the priority-manifest work.
