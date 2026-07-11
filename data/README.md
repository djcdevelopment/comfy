# Data

This directory preserves source artifacts and the reproducible projections made from them. It is the
repo's largest area by bytes, but most of that volume arrived in the formation session rather than
through ongoing code churn.

## Layout

- [`raw/`](raw/) contains source artifacts as received. Read [`raw/SOURCES.md`](raw/SOURCES.md) for
  provenance. Do not silently clean or overwrite these files.
- [`reference/`](reference/) contains small, curated reference structures used across recipes.
- [`processed/`](processed/) contains derived catalogs, anomaly reports, joined datasets, and the
  generated quest picker.

## Main flow

```text
raw guild sheets + recipe configuration
  -> recipes/quest-catalogs/harvest.py
  -> processed quest catalogs + anomaly reports
  -> recipes/quest-catalogs/render_quest_picker.py
  -> processed/quest-picker.html
```

Weapon source files similarly flow into the joined JSON documented under
[`../docs/datasets/`](../docs/datasets/).

Raw artifacts are evidence. Processed artifacts should be reproducible from a named source and tool;
when that is not possible, document the exception beside the output.
