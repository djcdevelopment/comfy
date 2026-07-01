# Dataset: Weapons Economy & Balance

- **Raw:** `data/raw/weapons-economy-balance.csv` (as received, untouched)
- **Normalized:** `data/processed/weapons-economy-balance.json` (119 items, 19 categories)
- **Decoder (prototype):** `scratchpad/parse_weapons.py`
- **Owner / axis:** the community's balance & reward-fairness model → maps to the
  **Balance Strategist** role and the **Economy** subsystem in `../personas.md`.

## What this sheet is

A custom, hand-maintained model that fuses **economy** (cost/gain) with **combat**
(damage profile + attack timing) for every weapon & ammo type, tiered by biome. It's
how the team keeps rewards *fair* against power as players progress Meadows → Ashlands.

## Structure (why it's a real parsing job, not a `read_csv`)

The file is **many sub-tables stacked in one sheet**, which naive CSV tools mangle:

- Two leading **"Selector" sub-tables** (Arrows, Bolts) with a *different, implicit*
  column layout (name + base + damage split only — no cost/gain/timing).
- A **weapon-table header row** (`Name,Cost,Gain,…`) partway down.
- **Category header rows** interleaved throughout (`Axes`, `Swords`, `Elemental Magic`…),
  detectable because col 21 reads `Biome` and Cost is blank.
- **Trailing empty columns** and ragged row lengths.

The decoder walks the rows statefully (tracking current category + section) rather than
assuming a rectangular table. **This same shape is likely across the other sheets** — so
the reusable lesson is "hub adapters must handle section-stacked human sheets," which I've
built toward.

## Column map (0-indexed)

| Col | Field | Confidence |
|----|-------|-----------|
| 0 | `name` | ✓ |
| 1 | `cost` | **[need]** meaning — stamina/eitr per use? upgrade price? |
| 2 | `gain` | **[need]** meaning — damage gained per weapon level? (split in 3–10 matches this) |
| 3–10 | `gain_split` (Blunt,Pierce,Slash,Frost,Lightning,Fire,Poison,Spirit) | ✓ structurally; tied to `gain` |
| 11 | `base` (total base damage) | ✓ |
| 12–19 | `damage` split (same 8 elements) | ✓ (verified: sum == base for 116/119) |
| 20 | `biome` (1=Meadows … 7=Ashlands, progression tier) | ✓ |
| 21 | `regen` | **[need]** — a computed balance metric; scales with tier |
| 22 | `hits` (attacks in a combo) | ✓ |
| 23 | `combo_time` (seconds) | ✓ |
| 24+ | `hit_timings` (per-hit timing within the combo) | ✓ structurally |

## Data-quality findings (from the base == Σ split check)

- `Primal Slayer` — base 170, split sums 180 (+10 Fire not reflected in base).
- `Scourging Slayer` — base 170, split sums 180 (+10 Lightning not reflected in base).
- `Stone pickaxe` — base 14 vs. Pierce 45 (stray value).

## Open semantic questions

1. **`cost`** — what is it? (per-swing stamina/eitr? a shop price? something else?)
2. **`gain`** — per-upgrade-level damage gain, or an economy "reward" value?
3. **`regen`** — what does this computed column represent / how is it derived?
4. **Variants** — items like *Primal / Bleeding / Thundering / Scourging* are clearly
   enchant/upgrade variants of a base weapon. Should the model treat them as variants of a
   parent, or as standalone items? (Affects how we de-duplicate across datasets.)
