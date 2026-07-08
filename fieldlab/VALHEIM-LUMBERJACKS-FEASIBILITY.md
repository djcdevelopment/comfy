# Valheim on Lumberjacks Feasibility

## Purpose

The question is not whether Lumberjacks works by itself; the native smoke packet already proved
that path. The question is how far a live Valheim client/server can be attached to Lumberjacks
before Valheim's own authority model gets in the way.

This file treats "Valheim on Lumberjacks" as a set of increasingly invasive layers. The early goal
is to find the first hard boundary with runnable probes, not to assume a full transport rewrite.

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
| ZDO transport replacement | Likely not viable without invasive patching | Lumberjacks replaces part of Valheim object replication. | Requires taking over private ZDO send queues, ownership, peer routing, and save interactions. |
| Valheim dedicated server on Lumberjacks | Not viable as worded | Full Valheim simulation runs on Lumberjacks. | That is a reimplementation of Valheim runtime semantics, not an adapter. |

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

## Next Spike

After projection is visually confirmed, the next spike is shadow movement authority:

1. Keep Valheim local player movement owned by Valheim.
2. Send equivalent intent to Lumberjacks.
3. Compare Lumberjacks authoritative position against the Valheim local player.
4. Record drift and correction pressure without applying corrections.

That answers whether Lumberjacks can be useful as a shadow authority before touching the dangerous
ZDO/authority layer.

ComfyNetworkSense `0.4.6` adds the first command for that spike:

```text
network_sense_lumberjacks_shadow [start|stop|status] [ws-url] [region-id]
```

Run it after restarting Valheim with `0.4.6`:

```text
network_sense_lumberjacks_shadow start ws://127.0.0.1:4000 region-spawn
network_sense_lumberjacks_shadow status
network_sense_lumberjacks_shadow stop
```

Rows are written to:

```text
BepInEx\config\comfy-network-sense\lumberjacks-shadow.jsonl
```

`pass_shadow_movement_observed` means drift was measured; it still does not prove correction safety
or ZDO transport replacement.
