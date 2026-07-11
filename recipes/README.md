# Recipes

Recipes turn existing community artifacts into validated, reusable outputs without asking volunteers
to change how they work. Each recipe should be understandable enough to use, create, and repair.

Start with [`../framework/AGENTS.md`](../framework/AGENTS.md) for the operating rules and
[`../framework/PHILOSOPHY.md`](../framework/PHILOSOPHY.md) for the rationale.

## Available recipes

### Rank ladders

[`rank-ladders/`](rank-ladders/) converts a guild's rank progression into validated JSON and
copy-pasteable output. Read [`rank-ladders/PROMPT.md`](rank-ladders/PROMPT.md) first.

```powershell
python .\recipes\rank-ladders\validate.py .\recipes\rank-ladders\example-output.json
python .\recipes\rank-ladders\render.py .\recipes\rank-ladders\example-output.json
```

### Quest catalogs

[`quest-catalogs/`](quest-catalogs/) harvests guild trackers into canonical catalogs and anomaly
reports, then renders the local quest picker. Its contracts are
[`schema.md`](quest-catalogs/schema.md) and
[`quest-view-schema.md`](quest-catalogs/quest-view-schema.md).

```powershell
python .\recipes\quest-catalogs\harvest.py
python .\recipes\quest-catalogs\validate.py .\data\processed\quest-catalog-slayers.json
python .\recipes\quest-catalogs\validate.py .\data\processed\quest-catalog-rangers.json
python .\recipes\quest-catalogs\render_quest_picker.py
```

The committed outputs live under [`../data/processed/`](../data/processed/).
