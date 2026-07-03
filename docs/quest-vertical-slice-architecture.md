# Quest vertical slice architecture

This is the first serious end-to-end build in this repo where the understanding, the
absorption layer, the local UI, the in-game mod, and the review/export plumbing all
locked together in one loop.

It is also the first serious integration of what this repo had been circling toward as
the **absorptionHub**: take messy live community data, preserve its truth, normalize only
the plumbing, and project it into a surface that a real player and a real guild master
can use immediately.

The code currently names part of that seam the **absorption engine** in
`recipes/quest-catalogs/harvest.py`. This doc uses **absorptionHub** as the name for the
whole intake-and-projection path.

## What the slice does

A player chooses quests from real guild data on a local page, saves a personal
`quest-view.json`, drops it into the Valheim mod workbench, sees those quests in the
`F7` panel, and then proves them one of three ways:

- manual capture from the quest log
- automatic capture on the matching in-game event, such as a punch or shot
- automatic two-shot sequence, such as first hit -> killing blow

The resulting evidence becomes a local submission package: screenshots, context, trace,
and workflow metadata. That package then flows into a local review inbox, where a human
accepts or rejects it and exports the exact guild command or a downstream payload.

No hosted service is required anywhere in the loop.

## The full dataflow

```text
live guild trackers / handbook
-> recipes/quest-catalogs/harvest.py
-> canonical quest catalogs + anomalies reports
-> recipes/quest-catalogs/render_quest_picker.py
-> data/processed/quest-picker.html
-> player chooses quests
-> quest-view.json
-> handoffs/comfy-control-surface/Core/QuestViewLoader.cs
-> F7 Quest Log + trigger-aware tracked quests
-> handoffs/comfy-control-surface/Core/QuestTriggerService.cs
-> handoffs/comfy-control-surface/Core/SubmissionService.cs
-> outbox/*.json + evidence/*.png + traces/*.jsonl + receipts/*.json
-> handoffs/comfy-control-surface/bridge-consumer/bridge_consumer.py
-> bridge-review/*.md + state + export
-> Discord bot command draft or any other endpoint that can consume the contract
```

## Architecture, by layer

### 1. Source absorption

Files:

- `data/raw/`
- `recipes/quest-catalogs/harvest.py`
- `recipes/quest-catalogs/schema.md`
- `recipes/quest-catalogs/sources.json`

This is where `absorptionHub` earns its keep.

The intake layer reads the live guild sources as they actually exist, not as we wish they
existed. The important rule is that **content passes through verbatim** while the plumbing
gets standardized around it.

That means:

- quest names, requirements, notes, and typos are preserved
- evidence structure is derived from the command slots and emoji grammar
- source oddities become anomalies for humans to rule on
- the harvester never silently repairs guild content

This is why the pipeline could absorb both Slayer and Ranger data even though the sheets
were structurally different.

### 2. Canonical catalog contract

Files:

- `recipes/quest-catalogs/schema.md`
- `data/processed/quest-catalog-slayers.json`
- `data/processed/quest-catalog-rangers.json`

The catalog is the stable, machine-usable truth for one guild and one era.

Important properties:

- one quest list shape, regardless of source shape
- machine-readable evidence spec
- verbatim guild turn-in command
- optional trigger spec for in-game auto-capture
- room for IRL or auto-checked quests without branching the downstream system

This contract is the seam that let the rest of the system stay unchanged while new guild
data came in.

### 3. Player selection UI

Files:

- `recipes/quest-catalogs/render_quest_picker.py`
- `recipes/quest-catalogs/quest-view-schema.md`
- `data/processed/quest-picker.html`

The picker is a local, self-contained projection of the absorbed catalogs.

Its job is not to own data. Its job is to let one player compose a smaller, personal
working set from the larger absorbed truth.

Important properties:

- works from `file://`
- embeds the catalogs directly
- saves only what one player chose to track
- persists selection locally in the browser
- emits a self-contained `quest-view.json` that the mod can ingest offline

This is the first player-facing proof that the absorptionHub path did not stop at
"ingestion succeeded"; it reached "a human can use the result immediately."

### 4. Inbound mod ingestion

Files:

- `handoffs/comfy-control-surface/Core/QuestViewLoader.cs`
- `handoffs/comfy-control-surface/Core/TrackedQuest.cs`
- `handoffs/comfy-control-surface/Core/ControlSurfacePanel.cs`

`QuestViewLoader` is the boundary between web-selected quest data and the live game.

Its rules are intentionally strict:

- `quest-view.json` must parse cleanly
- schema must match exactly
- failures are written to status files, never swallowed
- the mod treats the file as read-only input

`TrackedQuest` then turns each selected quest into something the in-game layer can render,
watch, and submit through the existing control-surface contract.

### 5. Trigger listening and auto-capture

Files:

- `handoffs/comfy-control-surface/Core/QuestTriggerService.cs`
- `handoffs/comfy-control-surface/Patches/QuestTriggerPatches.cs`

This is the "magic" part of the slice: the game listens for the act itself rather than
asking the player to prove it afterward.

Current implemented trigger buckets:

- `hit` against world targets such as trees or bushes
- `kill` against creatures, with optional skill and projectile filters
- two-shot sequences such as `on_first_hit` -> `on_death`

Key design choices:

- only local-player actions count
- triggers are per-quest and cooldown-gated
- a two-shot sequence binds to one creature instance
- auto-capture and manual capture share the same downstream submission machinery

That last point matters: the trigger system did not create a second pipeline. It only
changed how a submission starts.

### 6. Submission packaging

Files:

- `handoffs/comfy-control-surface/Core/SubmissionService.cs`
- `handoffs/comfy-control-surface/Core/GameContext.cs`
- `handoffs/comfy-control-surface/Core/TraceWriter.cs`
- `handoffs/comfy-control-surface/Core/StatusFiles.cs`

`SubmissionService` is the center of the runtime pipeline.

Given a quest or action, it captures:

- screenshot evidence
- one or many shots, depending on the trigger
- player/world/biome/position context
- workflow metadata such as guild, category, command template, and source
- a trace of every major step

Then it writes a local package:

- `outbox/<submission_id>.json`
- `evidence/*.png`
- `traces/*.trace.jsonl`
- `receipts/*.json`
- `status/*.json`

This package is the real contract of the vertical slice. Once it exists, any downstream
tool can consume it.

### 7. Review/export bridge

Files:

- `handoffs/comfy-control-surface/bridge-consumer/bridge_consumer.py`
- `handoffs/comfy-control-surface/bridge-consumer/review_inbox.py`

The bridge consumer translates raw submission packages into a human review surface.

Important properties:

- validates the payload contract before import
- preserves the original evidence and payload files
- tracks state transitions separately
- exports the guild's verbatim quest command for quest proofs
- stays backward compatible with older rank-proof submissions

This is why the system can honestly claim "local files first" without becoming a dead end.
The bridge is where a Discord bot flow, a copy-paste workflow, or a future endpoint can
all meet the same contract.

## Why this slice worked so well

### One contract per seam

Each boundary had a specific file or schema:

- source -> catalog
- catalog -> picker
- picker -> `quest-view.json`
- quest view -> tracked quest
- tracked quest -> submission package
- submission package -> review/export

That let each layer change internally without breaking the others.

### The absorbed data stayed real

The system did not depend on us rewriting guild operations into an invented clean model.
It found the structure that already existed and gave it consequences.

That is the strongest evidence yet that the absorptionHub approach is not just a framing
device. It is an engineering advantage.

### The pipeline stayed local

Every artifact is inspectable on disk. That made debugging, proving, and extending the
slice much faster than if transport or auth had been mixed in too early.

### Auto-capture reused existing plumbing

The impressive part is not just that the game can listen for a punch or killing blow.
The impressive part is that once it hears one, the rest of the system does not care
whether the proof started from a button or a trigger.

## What this proves about absorptionHub

This was the first serious proof that absorptionHub can be more than intake:

- it can absorb live, messy community truth
- it can preserve that truth while standardizing the mechanics
- it can project the result into a player-facing interface
- it can drive an in-game runtime system
- it can feed a human review loop and a real guild workflow

That is why this integration was a ridiculous success. It did not stop at "the parser
worked." It reached "the community's existing ritual now has a better machine around it."

## Related docs

- `handoffs/quest-log-retrospective.md` - what got built and why it mattered
- `handoffs/comfy-control-surface/CHANGELOG.md` - the runtime increments from v0.3.0 to v0.6.0
- `handoffs/REBOOT-HANDOFF.md` - current state and next steps
- `recipes/quest-catalogs/schema.md` - canonical quest catalog contract
- `recipes/quest-catalogs/quest-view-schema.md` - per-player quest selection contract
