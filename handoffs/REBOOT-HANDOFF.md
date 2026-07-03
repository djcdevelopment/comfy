# Reboot handoff - 2026-07-02

## Current state

Branch is clean and pushed to `origin/main`.

Latest commit:

```text
f606ee5 Add the quest-log slice retrospective
```

Recent relevant commits:

```text
f606ee5 Add the quest-log slice retrospective
1bd5f00 Quest log mod v0.3.0 -> v0.6.0: quest view, auto-capture, kill sequences, Ledger panel
30eda37 Add the quest picker (Faceted Codex) and the player quest-view contract
a8b5f5a Add quest-catalog recipe: configurator harvest over two live guilds
a0e9416 Land live guild sources: Slayer + Ranger trackers, guild handbook
```

## What is built

### In-game control surface

Location:

```text
handoffs/comfy-control-surface/
```

This is the live BepInEx Valheim vertical slice. It now supports:

- configurable local `actions.json`
- `F7` panel with Actions and Quest Log views
- `comfy_submit`
- `comfy_control_status`
- `comfy_control_reload`
- `comfy_quest_reload`
- local screenshot evidence, including multi-shot sequences
- structured outbox payloads, receipts, JSONL traces, and status files
- quest-view ingestion from the picker output
- automatic trigger capture for implemented `hit` and `kill` quest specs
- no network, no bot token, no central service

Primary references:

- `handoffs/comfy-control-surface/README.md`
- `handoffs/comfy-control-surface/CHANGELOG.md`
- `handoffs/quest-log-retrospective.md`

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

It remains backward compatible with the original rank-proof payloads while also handling
quest-proof exports and multi-image attachment lists.

Primary reference:

- `handoffs/comfy-control-surface/bridge-consumer/README.md`

### Quest catalog + picker pipeline

Locations:

```text
recipes/quest-catalogs/
data/processed/
```

This is the inbound data path for the quest log:

- harvest live guild sheets through `sources.json`
- validate to a canonical catalog contract
- emit anomalies reports rather than silently fixing source issues
- generate the local picker page
- save a per-player `quest-view.json` for the mod to ingest

Current harvested catalogs:

- Slayers: 103 quests
- Rangers: 85 quests

Primary references:

- `recipes/quest-catalogs/schema.md`
- `recipes/quest-catalogs/quest-view-schema.md`
- `data/processed/quest-picker.html`
- `handoffs/quest-log-retrospective.md`

### Rank ladder recipe

Location:

```text
recipes/rank-ladders/
```

This remains the source of truth for rank-proof actions. The control-surface starter
`actions.json` is generated from the ladder output, not maintained by hand.

Primary references:

- `recipes/rank-ladders/schema.md`
- `handoffs/comfy-control-surface/generate-actions-from-rank-ladder.py`

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

### Earlier proof and parallel handoff work

Locations:

```text
handoffs/valheim-camera-proof/
handoffs/
```

The camera proof and gallery pipeline handoffs still matter because they established the
same local Valheim modding/tooling path before the control-surface slice existed.

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
python .\recipes\quest-catalogs\validate.py .\data\processed\quest-catalog-slayers.json
python .\recipes\quest-catalogs\validate.py .\data\processed\quest-catalog-rangers.json
python .\handoffs\video_to_gallery.py sample.mp4 .\handoffs\timeline.sample.json --dry-run --duration 60
```

## Current design assessment

The functional boundary is proven across both directions:

- curated guild data can flow into the game as a player quest log
- player evidence can flow back out as reviewable local submissions

The next risks are not "can this work?" risks. They are product-shaping risks:

- which trigger specs are worth encoding next
- whether the anomaly reports get ruled on by guild staff
- how review state returns to the player
- whether the IMGUI panel gets the intended reskin
- how much support burden remains when a non-builder installs it

## Recommended next build

Build the flagship real quest trigger:

```text
Air Drop: thrown-spear Deathsquito kill, first-hit -> death sequence
```

Reason:

It uses machinery that already exists:

- quest catalogs
- quest-view ingestion
- `kill` triggers
- two-shot capture
- bridge export
- local review

It is the cleanest "real quest, real drama, no new architecture" demo.

## After that, likely order

1. Get guild rulings on the existing anomalies and land updated source truth.
2. Add the contracts/bounties tabs from Mikers and a Ranger follow-up pass.
3. Add review-status round-trip as a file-shaped sync back to the player.
4. Count prior captures from local receipts inside the panel.
5. Port the Ledger panel chrome from IMGUI semantics to a cleaner Jotunn/uGUI skin.

## Important principles to keep

- Make it cheaper to care.
- No bot, no basement.
- Local files first.
- Human review remains sacred.
- Export into existing workflows before integrating with credentials.
- Persona-specific proof beats generic infrastructure.
- Mikers demo is the beachhead.
- Standardize the plumbing, never the guild content.
