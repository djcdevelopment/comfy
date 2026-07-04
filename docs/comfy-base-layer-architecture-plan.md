# Comfy Base Layer Architecture Plan

## Purpose

This plan turns the current Comfy slices into a deliberate base layer.

The goal is not to replace Valheim first. The goal is to build the durable community,
progression, proof, telemetry, and steward infrastructure that can run beside Valheim now and
inside a cleaner engine later.

Short version:

```text
AbsorptionHub
-> canonical contracts
-> event and proof ledger
-> runtime adapters
-> review and governance
-> player, steward, Discord, and creator projections
-> metrics and feedback
```

Valheim is the first runtime adapter. Lumberjacks is the clean-room runtime target.

## North star

Make it cheaper to care.

The base layer should remove manual bookkeeping, preserve creator authorship, make community
work visible, and give players clear in-game paths without flattening guild identity into one
generic system.

## Strategic split

### Track A: Valheim adapter first

Use the existing BepInEx modpack path to ship value where the community already plays.

This track owns:

- in-game quest, rank, event, and proof surfaces
- automatic evidence capture where Unity/Valheim hooks expose enough signal
- local review/export flows
- network telemetry and enhanced-play suggestions
- optional side-channel service calls for dashboards and Discord export
- save-file/world analytics from ComfyStewardView

This track should not try to fully replace Valheim replication first. It can observe, advise,
capture proof, expose intent, and experiment with side-channel priority signals. Native Valheim
state ownership, ZDO replication, and physics authority remain hard boundaries until proven
otherwise.

### Track B: native base runtime later

Use Lumberjacks as the clean place to make the base layer native.

This track owns:

- server-authoritative event-first progression
- ranked packet lanes and binary hot-path protocols
- interest management as a first-class gameplay primitive
- authoritative quest, rank, event, and reward evaluation
- creator/guild systems as built-in platform contracts
- operator dashboards over durable server truth

The same contracts should work in both tracks. The adapter changes; the base layer semantics do
not.

## Architecture layers

### 1. AbsorptionHub

Absorbs messy community truth as it exists today.

Inputs:

- guild sheets and trackers
- rank ladders
- quest catalogs
- Creator Event rules
- Discord command grammar
- world-save analytics
- GM rulings and anomaly resolutions

Rules:

- preserve content verbatim when possible
- standardize plumbing, not guild identity
- emit anomalies instead of silently repairing source data
- keep provenance and era scope attached to every derived artifact

Near-term repo shape:

```text
recipes/
  rank-ladders/
  quest-catalogs/
  creator-events/
  guild-rosters/
data/
  raw/
  processed/
  rulings/
```

### 2. Canonical contracts

Defines stable shapes that every adapter can consume.

Initial contracts:

- `guild`
- `rank_ladder`
- `quest_catalog`
- `quest_view`
- `event_policy`
- `event_run`
- `proof_submission`
- `review_state`
- `reward_grant`
- `world_anchor`
- `player_profile`
- `network_session`
- `telemetry_sample`
- `creator_metric`

Contract rules:

- JSON first for portability and inspectability
- schema version on every file
- source/provenance fields on absorbed content
- era fields on all community systems
- small validators beside every recipe
- no hidden central service required for local proof

### 3. Event and proof ledger

Turns player and steward activity into durable evidence.

The first ledger can remain file-shaped:

```text
events.jsonl
submissions/
reviews/
exports/
receipts/
metrics/
```

Event categories:

- player intent: quest selected, event joined, mode changed
- gameplay proof: hit, kill, location, screenshot, sequence completed
- review: accepted, rejected, needs info, exported
- policy: event run logged, anti-farming flag raised, ruling applied
- network: session started, mode set, benchmark completed, pressure observed
- steward: catalog harvested, anomaly ruled, dashboard exported

Longer term, the same event stream can back a database or service. Do not start there unless the
file ledger becomes a real bottleneck.

### 4. Runtime adapters

Adapters project the base layer into a game or tool.

Initial adapters:

- `ValheimControlSurface`: quest/rank/event UI, proof capture, local status files
- `ValheimNetworkSense`: telemetry HUD, session export, enhanced-play modes
- `ComfyStewardView`: world-save analytics, anchors, creator/world forensics
- `BridgeConsumer`: local review, state transitions, Discord command export
- `DiscordExporter`: command drafts first, bot credentials later
- `LumberjacksRuntime`: future native engine/platform adapter

Adapter rule:

```text
Adapters translate. They do not invent community truth.
```

### 5. Review and governance

Human review remains sacred.

The base layer should automate evidence capture and routing, not pretend that every community
decision is objective.

Build first:

- review inbox over proof submissions
- accept/reject/needs-info state
- review status round-trip back to the player
- export exact guild command strings
- anomaly ruling files for absorbed catalogs
- policy run logs for Creator Events

Build later:

- reviewer assignment
- multi-review workflows
- appeal notes
- Discord bot integration
- guild-specific review dashboards

### 6. Projections

A projection is any useful surface generated from the contracts and ledger.

Player projections:

- in-game quest log
- rank progress
- active event checklist
- proof receipt history
- review status
- network mode badge and recommendation

Steward projections:

- review inbox
- anomaly queue
- guild catalog diff
- event run log
- anti-farming detector
- reward export queue

Creator projections:

- event turnout
- quest completions
- review latency
- player participation
- world hotspot maps
- contribution receipts

Operator projections:

- network session comparisons
- world density overlays
- build/wealth/portal analytics
- support diagnostics
- install health

### 7. Metrics and feedback

The system should give better feedback to guilds and creators without becoming surveillance.

Metric principles:

- aggregate before individualizing
- show why a metric exists
- tie metrics to relief, fairness, and creator support
- avoid top-down audit framing
- keep opt-in boundaries clear

Initial metrics:

- quest starts and completions
- proof auto-capture success rate
- review queue size and latency
- event runs per player/group/time window
- creator event participation
- anti-farming countable-rule flags
- network pressure by mode/session
- support/install failure patterns

## Build phases

### Phase 0: Base-layer framing and repo seams

Goal:
make the architecture explicit enough that every next slice has a home.

Deliverables:

- this architecture plan
- a top-level contract index
- folder conventions for recipes, contracts, ledgers, adapters, and projections
- a short "what not to build yet" note

Definition of done:

- a new contributor can explain the difference between AbsorptionHub, contracts, adapters,
  ledger, and projections without reading the whole repo

### Phase 1: Submission ledger unification

Goal:
turn the current proof outbox/review flow into the canonical event and proof ledger.

Deliverables:

- `proof_submission` contract extracted from the control surface payloads
- `review_state` contract extracted from bridge-consumer state
- `events.jsonl` event names normalized across control surface and bridge
- validator for submission and review-state files
- compact ledger README and examples

Definition of done:

- rank proof, quest proof, and manual action proof all validate against one submission contract
- bridge review events can be replayed into the same final state

### Phase 2: Review status round-trip

Goal:
close the player loop.

Deliverables:

- bridge writes a `review-status.json` projection
- control surface reads review status as read-only input
- in-game panel shows pending, accepted, rejected, and needs-info states
- receipts link local submission IDs to review outcomes

Definition of done:

- a player can submit proof, a reviewer can accept/reject it, and the player can see the result
  in-game without Discord or a hosted service

### Phase 3: Creator Event policy slice

Goal:
prove that policy absorption plus telemetry can simplify rules instead of adding burden.

Deliverables:

- `creator-events` recipe
- `event_policy` contract for countable rules
- `event_run` contract
- local run-log editor/importer
- anti-farming detector for countable limits
- exportable steward report

Definition of done:

- a Creator Event steward can log runs and get a simple "needs attention" report without reading
  a spreadsheet manually

### Phase 4: Player cockpit v1

Goal:
make quests, ranks, events, receipts, and review status feel like one in-game surface.

Deliverables:

- unified F7 panel navigation
- Quest Log tab
- Rank tab
- Event tab
- Receipts/Review tab
- readable install/support status
- config/profile loader for per-guild packs

Definition of done:

- a normal player can answer "what can I do, what proof is needed, what have I submitted, and
  what happened to it?" from inside the game

### Phase 5: Steward dashboard v1

Goal:
combine absorbed community data, proof review, and world analytics into one local operator surface.

Deliverables:

- local web dashboard over the ledger and processed catalogs
- review queue summary
- anomaly queue summary
- event run-log summary
- world anchor links from ComfyStewardView exports
- creator/guild metric cards

Definition of done:

- a steward can open one local dashboard and see the work that needs human judgment today

### Phase 6: Enhanced-play modpack

Goal:
ship the best practical Valheim experience without pretending the mod owns all netcode.

Deliverables:

- packaged `ComfyControlSurface`
- packaged `ComfyNetworkSense`
- optional MCP/dev gateway only for testers
- host/client telemetry comparison workflow
- `Solo`, `Group`, `Combat`, and `Town` modes
- session export and compare tooling
- first "enhanced play" recommendations based on telemetry

Definition of done:

- a host and one client can run a session, export both views, compare them, and get actionable
  recommendations without hand-building spreadsheets

### Phase 7: Side-channel service

Goal:
add a small service only where local files become too limiting.

Possible responsibilities:

- receive ledger events from multiple players
- publish review-status projections
- hold shared guild catalogs
- generate Discord bot command drafts
- aggregate telemetry sessions
- expose steward dashboard APIs

Constraints:

- local-first still works
- credentials are optional
- all service APIs mirror file contracts
- no gameplay-critical truth moves here while Valheim remains the runtime

Definition of done:

- hosted mode improves collaboration but is not required for a single-guild local workflow

### Phase 8: Lumberjacks native integration

Goal:
make the base layer native in the clean runtime.

Deliverables:

- contracts imported into Lumberjacks `Game.Contracts`
- progression service consumes `event_policy`, `quest_catalog`, and `rank_ladder`
- EventLog stores quest/rank/event/proof events as first-class records
- OperatorApi exposes steward dashboard routes
- Gateway exposes ranked traffic lanes and enhanced-play modes natively
- Godot client renders player cockpit surfaces without Valheim mod constraints

Definition of done:

- a community progression loop that was first proven in Valheim runs natively in Lumberjacks with
  server authority, ranked packets, interest management, and operator visibility

### Phase 8A: Era-save native bridge

Goal:
use preserved Comfy world saves as the first native Lumberjacks content corpus.

Inputs:

- `erasave/ComfyEra12.db`
- `erasave/ComfyEra16.db`
- `erasave/classification.json`
- ComfyStewardView DuckDB/cache exports
- `waypoints.json`

Deliverables:

- era import bundle contract
- world anchors
- settlement signatures
- portal graph
- creator attribution with confidence
- build-density benchmark cells
- native Godot Era viewer
- first native appreciation/progression loop

Definition of done:

- Lumberjacks can load an Era 16 import bundle, render the top historical build anchors as native
  settlement signatures, record player appreciation events, and explain the resulting progression
  through EventLog/Progression/OperatorApi

Detailed plan:

- `docs/lumberjacks-native-runtime-era-save-plan.md`

### Phase 8B: Thesis Gold local lab

Goal:
keep the native-runtime work honest by turning local hardware, LAN machines, and Era-save scenarios
into a reproducible experiment lab.

Deliverables:

- `fieldlab/` working directory
- local lab folder convention
- scenario definitions
- one-command experiment runner
- environment capture
- raw telemetry and log collection
- results/report/publish packet generation
- reproducibility signatures

Definition of done:

- a Thesis Gold experiment can be launched from a scenario file, emit a signed run folder, and
  produce enough evidence for another developer or future agent to rerun it

Detailed plan:

- `docs/thesis-gold-local-lab-plan.md`

## Flagship vertical slice

Build this slice before broadening.

```text
Air Drop quest
-> player selects it from absorbed catalog
-> quest appears in-game
-> thrown-spear Deathsquito first-hit and death sequence auto-captures evidence
-> submission enters proof ledger
-> reviewer accepts/rejects locally
-> status returns to player panel
-> export emits exact guild command
-> creator/guild metric increments
```

Why this slice:

- it uses real guild content
- it is dramatic enough to demo
- it exercises two-shot auto-capture
- it proves review status round-trip
- it creates meaningful creator/guild metrics
- it requires no new engine work

## Near-term task order

1. Extract and document `proof_submission` and `review_state` contracts from the current
   control-surface and bridge payloads.
2. Normalize bridge events into a replayable `events.jsonl` ledger.
3. Add review-status projection output to the bridge.
4. Add read-only review-status display to the control surface.
5. Add the Air Drop trigger authoring and validation path.
6. Run the full local Air Drop proof loop.
7. Add first metric projection: submissions by quest, status, guild, and review latency.
8. Add Creator Event `event_run` contract and countable-rule detector.
9. Package the enhanced-play modpack with ControlSurface and NetworkSense together.
10. Decide whether the side-channel service is needed or whether files remain enough for the next
    two slices.

## What not to build yet

Do not build these first:

- full Valheim netcode replacement
- production Discord bot credentials
- global hosted platform
- multi-guild permissions system
- automatic hard enforcement of creator rules
- automatic authority selection in Valheim
- generic dashboard before one persona-specific dashboard works
- new-engine port before the contracts are stable

These are not bad ideas. They are later ideas.

## Key risks

### Scope risk

The base layer can become "everything the community does."

Mitigation:

- one flagship slice at a time
- one contract per seam
- no projection without a named user

### Political risk

Legibility can feel like an audit.

Mitigation:

- opt-in per steward/guild
- exports preserve author voice
- metrics framed as relief and feedback, not judgment
- human review remains visible

### Technical risk

Valheim internals may block clean automation for some proof types.

Mitigation:

- manual capture always remains valid
- trigger specs degrade to player-initiated proof
- native Lumberjacks path remains separate

### Data drift risk

Guild source artifacts will keep changing.

Mitigation:

- provenance on every absorbed artifact
- anomaly reports
- rulings files
- validators in every recipe

### Trust risk

Players may reject hidden scoring or downgrades.

Mitigation:

- scores advise before they control
- mode changes are visible
- recommendations explain tradeoffs
- low-impact/enhanced-play behavior is opt-in first

## Success criteria

The architecture is working when:

- players stop hunting through Google Docs for current quests
- stewards review exceptions instead of manually transcribing routine proofs
- guild creators see participation and impact without maintaining separate sheets
- reviewers can explain every accept/reject/export from durable evidence
- telemetry helps players coordinate instead of just diagnosing lag after the fact
- Valheim gets immediate value while Lumberjacks receives cleaner long-term platform contracts
