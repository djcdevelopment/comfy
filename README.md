# Comfy

*Shared openly as homework. If you're here to learn how to leverage AI, read the restraint, then read the few places where restraint finally paid off.*

## What this is

This repo started as the record of one long build session for a volunteer game community
("Comfy," a heavily-modded Valheim server). The artifact that mattered first was the
**method**: understand the world from multiple human seats, delay the data flood until a
lens exists, and resist building until a concrete projection earns its keep.

That first session did not stay abstract forever. A small number of deliberate projections
were built afterward, and they now live alongside the method that produced them.

## Start here

- `docs/kernel.md` - the locked understanding everything else resolves to.
- `docs/perspectives/` - the human lenses that built that understanding.
- `docs/method/` - the reusable operating discipline, ledger, and full conversation extract.

## What got built

### Recipes and data contracts

- `recipes/rank-ladders/` - canonical guild rank requirements rendered into machine-usable
  action definitions.
- `recipes/quest-catalogs/` - live guild tracker harvest -> validated quest catalogs ->
  anomalies reports -> picker input.
- `data/raw/` - landed source material with provenance.
- `data/processed/` - derived catalogs, anomaly reports, and the generated quest picker.

### Handoffs and proofs

- `handoffs/valheim-camera-proof/` - the first proof kit that established the local Valheim
  modding path.
- `handoffs/` - the decomposed camera/gallery pipeline and the later control-surface slices.
- `handoffs/comfymods-inspection.md` - implementation guidance based on the existing
  ComfyMods ecosystem.

### The built vertical slice

- `handoffs/comfy-control-surface/` - a local-first BepInEx plugin plus bridge consumer:
  in-game capture -> local outbox -> GM review inbox -> exported guild-bot command.
- `handoffs/quest-log-retrospective.md` - how that slice expanded from rank proof to the
  player quest log, auto-capture, kill sequences, and the Ledger panel.
- `handoffs/REBOOT-HANDOFF.md` - the current "pick this up cold" brief.

## How the pieces connect

The work now forms one chain:

`docs/kernel.md` -> `recipes/quest-catalogs/` and `recipes/rank-ladders/` ->
`data/processed/quest-picker.html` -> `quest-view.json` ->
`handoffs/comfy-control-surface/` -> local review/export.

The older camera/gallery handoff is still relevant because it proved the same local modding
surface the control-surface work now uses.

## How to read the repo

- Read `docs/kernel.md` first if you want the thesis.
- Read `docs/quest-vertical-slice-architecture.md` if you want the end-to-end quest slice and dataflow.
- Read `docs/method/the-lens-first-playbook.md` if you want the operating discipline.
- Read `handoffs/REBOOT-HANDOFF.md` if you want the current built state and likely next moves.
- Read `handoffs/comfy-control-surface/QUEST.md` if you want the packaged, end-to-end player/GM slice.

## The principle that still holds

Execution got cheaper; intention did not. The point of this repo is still that understanding
should lead and automation should follow. The difference is that there are now a few built
artifacts showing what happens when that discipline finally cashes out.
