# Lumberjacks Native Runtime From Era Saves

## Why the saves change the plan

The native Lumberjacks path should not start from an empty procedural demo world.

The repo already has two heavy end-of-era Valheim saves:

```text
erasave/ComfyEra12.db   945,596,062 bytes
erasave/ComfyEra12.fwl  72 bytes
erasave/ComfyEra16.db   1,337,245,906 bytes
erasave/ComfyEra16.fwl  72 bytes
erasave/classification.json
```

Those saves are a real community corpus:

- dense player settlements
- portals and named locations
- containers and economy state
- beds, signs, wards, tombstones, and ownership hints
- guild and creator event artifacts
- high-density network stress targets
- preserved art from actual players

That means the first native runtime slice can be more than "connect two capsules in Godot." It can
make Lumberjacks load and honor the shape of a real Comfy era.

## Core idea

Use Valheim saves as a historical import layer, not as the permanent runtime format.

```text
Valheim .db/.fwl
-> ComfyStewardView parse and DuckDB cache
-> Comfy era import bundle
-> Lumberjacks content and world contracts
-> native Godot exploration, progression, and operator surfaces
```

The import does not need to reproduce Valheim perfectly. It needs to preserve what matters:

- where the community built
- who likely built it
- what type of place it is
- what objects and resources matter there
- what stories, quests, or creator events should attach to it
- how expensive it is as a simulation and network scenario

## Import bundle contract

Create a portable JSON/JSONL export from ComfyStewardView or its DuckDB cache.

Suggested folder:

```text
data/processed/era-imports/
  ComfyEra16/
    manifest.json
    world_anchors.json
    settlement_signatures.json
    portal_graph.json
    creator_attribution.json
    economy_summary.json
    build_density_cells.jsonl
    object_samples.jsonl
    import_anomalies.md
```

### `manifest.json`

High-level metadata:

- `schema_version`
- `era`
- `world_name`
- `source_db`
- `source_fwl`
- `source_size_bytes`
- `generated_at_utc`
- `stewardview_version`
- `counts`

### `world_anchors.json`

Named or ranked places that native Lumberjacks can spawn, display, or route to.

Sources:

- `waypoints.json`
- portal labels
- top build-density cells
- known event sites
- guild bases
- manually curated Hall of Fame targets

Fields:

- `anchor_id`
- `era`
- `name`
- `kind`
- `x`
- `y`
- `z`
- `owner`
- `guild`
- `confidence`
- `source`
- `tags`

### `settlement_signatures.json`

A compressed representation of dense builds.

The native runtime does not need every Valheim piece on day one. It needs a cheap signature that
lets players see that a community place existed.

Fields:

- `settlement_id`
- `anchor_id`
- `center`
- `bounds`
- `piece_count`
- `dominant_categories`
- `likely_owner`
- `owner_confidence`
- `portal_names`
- `density_score`
- `network_cost_score`
- `visual_lod`

Possible `visual_lod` forms:

- bounding silhouette
- point cloud
- heatmap mesh
- simplified prefab cluster
- screenshot/gallery link

### `portal_graph.json`

A native navigation and memory layer.

Fields:

- `portal_id`
- `name`
- `position`
- `owner`
- `destination_name`
- `matched_destination_id`
- `confidence`

Native use:

- route map
- location search
- gallery traversal
- "walk the old network" experience

### `creator_attribution.json`

Attribution should be confidence-based, not falsely exact.

Signals:

- owned portals
- beds
- wards
- signs
- containers
- tombstones
- local build clusters
- external roster/ruling data when available

Fields:

- `subject_id`
- `display_name`
- `anchor_ids`
- `evidence`
- `confidence`
- `notes`

### `economy_summary.json`

Summaries that preserve the material culture of an era.

Fields:

- high-value container clusters
- item category totals
- server-issued/event item sightings
- guild gear sightings
- coin caches
- suspicious or special-case artifacts

Native use:

- steward analytics
- museum displays
- creator event planning
- economy balancing examples

### `build_density_cells.jsonl`

Network and rendering benchmark input.

Fields:

- `cell_id`
- `cell_size`
- `center`
- `piece_count`
- `category_counts`
- `owner_hint`
- `network_cost_score`

Native use:

- stress-test AoI
- settlement LOD tuning
- scene streaming test cases
- packet ranking benchmarks

### `object_samples.jsonl`

Bounded object samples from selected anchors.

Fields:

- `object_id`
- `prefab`
- `category`
- `position`
- `rotation`
- `creator_id`
- `owner_id`
- `anchor_id`
- `source_zdo_index`

Native use:

- small local 3D reconstruction windows
- prefab taxonomy mapping
- creator gallery details

## Native runtime targets

### Target 1: Era map viewer in Godot

Load `world_anchors`, `settlement_signatures`, and `portal_graph` into Lumberjacks/Godot.

Player experience:

- connect to native Lumberjacks backend
- open an Era 16 map
- see ranked settlement signatures
- click or travel to a signature
- read owner/attribution notes
- follow portal graph links

Why it matters:

- proves save-derived content can become native runtime content
- closes the appreciation loop without needing full gameplay first
- uses real community data immediately

### Target 2: Native Hall of Fame walk

Turn top build clusters into a curated exploration route.

Inputs:

- `waypoints.json`
- manually curated Hall of Fame metadata if available
- screenshots from the camera proof workflow

Player experience:

- spawn at an Era Hall
- walk through portals or gallery gates
- visit simplified settlement signatures
- vote or leave appreciation
- generate creator-facing feedback

Why it matters:

- this is a native community loop, not just an analytics dashboard
- it proves Lumberjacks can host Comfy's social structure directly

### Target 3: Network stress museum

Use high-density build cells as deterministic network test scenes.

Inputs:

- `build_density_cells.jsonl`
- settlement signature bounds
- object samples

Runtime behavior:

- spawn proxy entities based on density
- apply interest management tiers
- measure bytes/sec, update freshness, and client frame cost
- compare packet ranking strategies

Why it matters:

- the saves give real density distributions
- the benchmark is grounded in Comfy reality, not synthetic guesses
- the same scenarios can feed the Thesis Gold local lab in
  `docs/thesis-gold-local-lab-plan.md`

### Target 4: Native creator quest

Attach a quest or event policy to a historical anchor.

Example:

```text
Visit three Era 16 Hall of Fame builds
-> interact with each settlement plaque
-> server emits canonical visit/appreciation events
-> progression completes a creator-tour objective
-> creator metrics update
```

Why it matters:

- first native Comfy progression loop
- uses server events as proof
- turns saved art into new player action

## Implementation phases

### Phase 1: Export from StewardView

Goal:
produce a stable import bundle from `ComfyEra16`.

Tasks:

- run ComfyStewardView batch analytics for `ComfyEra16`
- export top build-density cells
- export portal/bed/container/sign ownership hints
- export settlement signatures
- export import anomalies
- validate the bundle locally

Definition of done:

- `data/processed/era-imports/ComfyEra16/manifest.json` exists
- top anchors match or improve `waypoints.json`
- export can be regenerated without hand edits

### Phase 2: Add Lumberjacks import contracts

Goal:
make the bundle a first-class content input.

Tasks:

- add contract records for `WorldAnchor`, `SettlementSignature`, `PortalLink`, and
  `CreatorAttribution`
- add JSON schema/docs
- add import validator tests
- add a loader that can seed a Lumberjacks dev database or in-memory world

Definition of done:

- Lumberjacks can load the import bundle without ComfyStewardView running

### Phase 3: Native Godot era viewer

Goal:
render the imported era as navigable native content.

Tasks:

- expose anchors through OperatorApi or Gateway snapshot
- add Godot UI list/map for anchors
- render settlement signatures as proxy geometry
- show attribution and confidence
- support teleport/travel between anchors in a dev build

Definition of done:

- a player can launch the Godot client and visit at least 10 imported Era 16 anchors

### Phase 4: Appreciation loop

Goal:
turn the historical viewer into a community system.

Tasks:

- add `creator_appreciation_recorded` event
- add lightweight voting or reaction UI
- store appreciation events in EventLog
- project creator feedback summaries

Definition of done:

- interacting with a settlement produces a durable event trail and creator-facing summary

### Phase 5: Native progression loop

Goal:
prove Comfy contracts running natively.

Tasks:

- import one quest/event policy over the era anchors
- emit canonical events from Godot interactions
- Progression evaluates completion
- OperatorApi explains why it counted
- player cockpit shows completion and receipt

Definition of done:

- a Comfy-native objective completes without screenshots or manual proof because Lumberjacks owns
  the authoritative event

## Why this is the right first native slice

It avoids the hardest content problems while proving the most important platform idea.

Avoided early:

- full combat
- full Valheim object fidelity
- full crafting tree
- enemy AI
- exact piece-by-piece reconstruction
- production MMO-scale auth

Proven early:

- real world import
- real creator attribution
- native event proof
- native player cockpit
- native operator explanation
- native appreciation loop
- network stress scenes from real data

## Open questions

- Can StewardView currently export exact portal graph pairs, or do we need a small endpoint?
- Which owner signal is strongest for Era 12 versus Era 16?
- Do Hall of Fame voting records exist in a form we can absorb?
- Should native viewer use actual object samples, generated proxy geometry, or screenshot-backed
  galleries first?
- How much Valheim coordinate space maps cleanly into the current Lumberjacks/Godot region model?
