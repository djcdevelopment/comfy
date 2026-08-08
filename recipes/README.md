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

Ladders can also be **harvested**: quest-catalogs sources with `"kind": "rank-ladder"`
(first: the Hobbits, from Luna's workbook) run through the same absorption engine and
get the same anomalies report + provenance receipt as quest catalogs:

```powershell
python .\recipes\quest-catalogs\harvest.py hobbits-ladder
python .\recipes\rank-ladders\validate.py .\data\processed\rank-ladder-hobbits.json
python .\recipes\rank-ladders\render.py .\data\processed\rank-ladder-hobbits.json
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
python .\recipes\quest-catalogs\render_provenance.py
```

Each harvest also writes a provenance sidecar (`*-provenance.json`), and
`render_provenance.py` turns those into the leader-facing provenance view
(`data/processed/provenance-<source-id>.html` + `provenance.html` index): which
columns became which fields, the fate of every row with verbatim cells, and the
anomalies joined to the rows they concern.

The committed outputs live under [`../data/processed/`](../data/processed/).
