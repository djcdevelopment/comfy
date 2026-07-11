# Repository tools

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
