# Dataset: Weapon Choices (+ join to the balance dataset)

- **Raw:** `data/raw/weapon-choices.csv` (transcribed from an image; 61 rows, 7 weapon classes)
- **Joined:** `data/processed/weapon-choices-joined.json` (each choice + its cost/base/biome from
  the balance dataset)
- **Join script (prototype):** `scratchpad/join_choices.py`
- **Owner / axis:** balance & round-fairness telemetry → **Balance Strategist** / Economy.

## What it is

A per-weapon tally (`L` number) across 7 classes (Axe, Knife, Sword, Atgeir/Sledge, Club, Spear,
Bow). This is the **first dataset that only means something when joined** to another —
`weapons-economy-balance.json` supplies the cost/damage/biome each `L` refers to.

## The join — 61/61, full reconciliation

Two independently hand-made sheets with no shared naming convention matched completely via a
class-aware normalizer:

- accent/punctuation-insensitive key (`Nidhögg` → `nidhogg`)
- `BM` → "Black metal"; other spacing quirks fall out of normalization (`Himmin Afl` → `himminafl`,
  `Spine Snap` → `spinesnap`)
- short name + class noun (`Bronze` under *Sword* → "Bronze sword"; under *Spear* → "Bronze spear")
- singular→plural prefix fallback (`Berserkir` → "Berserkir axes")

This reconciliation is the integration-hub thesis in miniature: same entities, different
conventions, joined automatically. Naming drift like this will recur across every source, so the
normalizer is a reusable asset, not a one-off.

## What is `L`? (OPEN — needs Derek)

`L` is **not** "favorite combat weapon": low-damage wooden gear tops the list (Wooden Sledge 190,
Wooden Greatsword 180) while rare endgame gear bottoms it (Spine Snap 1, Flametal Mace 10,
Berserkir 6). So `L` is a **prevalence/usage tally**. Two live hypotheses:

- **(a) Game-world instance counts** from the server DB (how many exist). Fits the wooden/iron
  dominance + endgame scarcity, and matches the confirmed game-DB access.
- **(b) Event loadout pick-counts** from a points-buy system (cheap weapons over-picked to save
  budget). Fits the "round fairness / balance" framing.

Both make this **fairness telemetry**: joined with cost/power it answers "what's over-represented
relative to what it costs?" — which neither sheet can answer alone.

Also open: **is this a live/re-runnable extract or a one-time snapshot?** (Decides connector vs.
snapshot.)
