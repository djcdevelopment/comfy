# Repository tools

## Era release train

[`era_release_train.py`](era_release_train.py) encodes the Comfy reset schedule as data. Every
milestone sits at a fixed offset from the era start date, so the whole staff calendar, comms
cascade, and staging window derive from a single input. Offsets were reverse-engineered from the
community "Comfy Reset Schedule (Template)" (E15/E16/E17) and reproduce all eight E17 dates exactly.

```powershell
# Observed cadence and candidate next-era start dates.
python .\tools\era_release_train.py --suggest

# Full release train for an era, plus draft reset-channel posts.
python .\tools\era_release_train.py --era 18 --start 2026-11-14 --posts
```

Background and the vocabulary it deliberately uses:
[`../docs/practice-to-profession.md`](../docs/practice-to-profession.md).

## Activity mapper

[`repo_activity.py`](repo_activity.py) turns the committed Git history into the repository map under
[`../docs/repo-map/`](../docs/repo-map/).

```powershell
# Regenerate JSON, Markdown, SVG, HTML, and the marked root README section.
python .\tools\repo_activity.py --write

# Verify the recorded snapshot and ensure only managed publication files changed after it.
python .\tools\repo_activity.py --check

# Optional machine-local evidence; never enters public scoring.
python .\tools\repo_activity.py --local-timestamps .\local-repo-times.json
```

Configuration, categories, era labels, exclusions, and score weights live in
[`../repo-activity.json`](../repo-activity.json). Public output uses Git author timestamps and current
blob sizes from `HEAD`, making it stable across clones. The optional local timestamp export exists for
forensics only and should not be committed.

The generated report records the source commit it analyzed. Its publication commit naturally comes
after that source, so `--check` rebuilds the recorded snapshot and permits only this mapper's managed
README/report files after it. Any later change elsewhere in the repository marks the snapshot stale.
