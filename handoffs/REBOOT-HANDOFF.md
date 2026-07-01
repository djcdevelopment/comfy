# Reboot handoff - 2026-07-01

## Current state

Branch is clean and pushed to `origin/main`.

Latest commit:

```text
a379bc1 Add Mikers Slayer rank proof demo
```

Recent relevant commits:

```text
a379bc1 Add Mikers Slayer rank proof demo
132cc8d Add local review inbox
a8dba21 Add control surface bridge consumer
e018d1e Add control surface proof inspector
713ede1 Add control surface proof checklist
cc322ee Add Valheim handoff and control surface workbench
```

## What is built

### In-game control surface

Location:

```text
handoffs/comfy-control-surface/
```

This is a BepInEx Valheim plugin proof slice. It supports:

- configurable local `actions.json`
- `F7` default action hotkey
- `comfy_submit`
- `comfy_control_status`
- `comfy_control_reload`
- local screenshot evidence
- structured outbox payloads
- JSONL traces
- status files
- no network, no bot token, no central service

### Bridge consumer

Location:

```text
handoffs/comfy-control-surface/bridge-consumer/
```

This consumes `outbox/*.json`, validates the payload contract, and writes:

```text
bridge-review/<submission_id>.md
bridge-review/index.json
bridge-review/state/<submission_id>.json
bridge-review/events.jsonl
bridge-review/export/<submission_id>.txt
```

It includes `review_inbox.py` commands:

```text
list
show <submission_id>
accept <submission_id>
reject <submission_id> --reason "..."
needs-info <submission_id> --reason "..."
export <submission_id>
```

### Mikers demo

Location:

```text
handoffs/comfy-control-surface/bridge-consumer/mikers-demo/
```

This is the first persona-specific demo. It proves:

```text
Slayer rank proof action
-> outbox payload
-> review inbox
-> accept/export
-> Slayer command draft
```

Expected export:

```text
/slayer submit rank:Thrall proof:evidence/20260701-210000-slayer-rank-thrall-demo.png
```

## Proof already completed

The plugin was installed and Valheim was launched with `-console`.

BepInEx loaded:

```text
Comfy Camera Proof 0.1.0
ComfyControlSurface 0.1.0
```

The live in-game happy path was proven by running `comfy_submit` after entering a world.

Generated real submission:

```text
submission_id: 20260701-201954-submit-proof-b8ad
player: Tugcow
world: test1
biome: Meadows
payload: outbox/20260701-201954-submit-proof-b8ad.json
screenshot: evidence/20260701-201954-submit-proof-b8ad.png
trace: traces/20260701-201954-submit-proof-b8ad.trace.jsonl
```

Trace included:

```text
action_selected
context_captured
screenshot_captured
payload_validated
payload_written
player_status_shown
```

The bridge consumer processed both fixture data and the real live Valheim workbench.

## Validation commands used

```powershell
dotnet build .\handoffs\comfy-control-surface\ComfyControlSurface.csproj -c Release
python .\handoffs\comfy-control-surface\bridge-consumer\bridge_consumer.py .\handoffs\comfy-control-surface\bridge-consumer\fixtures
python .\handoffs\comfy-control-surface\bridge-consumer\review_inbox.py .\handoffs\comfy-control-surface\bridge-consumer\fixtures list
python .\handoffs\comfy-control-surface\bridge-consumer\bridge_consumer.py .\handoffs\comfy-control-surface\bridge-consumer\mikers-demo
python .\handoffs\comfy-control-surface\bridge-consumer\review_inbox.py .\handoffs\comfy-control-surface\bridge-consumer\mikers-demo export 20260701-210000-slayer-rank-thrall-demo
python .\handoffs\comfy-control-surface\bridge-consumer\bridge_consumer.py "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-control"
python .\handoffs\comfy-control-surface\bridge-consumer\review_inbox.py "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-control" list
python .\recipes\rank-ladders\validate.py .\recipes\rank-ladders\example-output.json
python .\handoffs\video_to_gallery.py sample.mp4 .\handoffs\timeline.sample.json --dry-run --duration 60
```

## Current design assessment

The functional boundary is proven. The next risk is user/support experience.

The current CLI/file workflow works, but it still feels like a developer workbench. That is acceptable
for proof, but not enough for adoption.

Next build should prioritize making support and operation easy before adding richer in-game UI.

## Recommended next build

Build the support diagnostics workbench:

```text
handoffs/comfy-control-surface/support/diagnose.ps1
```

Purpose:

One command should answer whether the local install is healthy.

It should check:

- Valheim install exists
- BepInEx exists
- plugin DLL installed
- plugin version if detectable
- `comfy-control` config exists
- `actions.json` exists
- actions load status from `plugin-status.json`
- latest startup trace
- latest submission
- latest error
- outbox count
- evidence count
- bridge-review count
- latest BepInEx log lines for `ComfyControlSurface`
- generated package zip contents

It should write:

```text
support-report.md
support-report.json
```

This helps future Derek, Mikers, or any rep/supporter answer "what is broken?" without spelunking.

## After diagnostics

Build a small player-facing in-game panel:

```text
F7 opens panel
-> Slayers
-> Rank Proof
-> Thrall / Thegn / Jarl
-> Capture proof
-> Saved receipt
```

Keep the console commands for testers, but do not require players to use them.

## Important principles to keep

- Make it cheaper to care.
- No bot, no basement.
- Local files first.
- Human review remains sacred.
- Export into existing workflows before integrating with credentials.
- Persona-specific proof beats generic infrastructure.
- Mikers demo is the beachhead.

