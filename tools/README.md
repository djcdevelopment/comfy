# Repository tools

## Activity mapper

[`repo_activity.py`](repo_activity.py) turns the committed Git history into the repository map under
[`../docs/repo-map/`](../docs/repo-map/).

```powershell
# Regenerate JSON, Markdown, SVG, HTML, and the marked root README section.
python .\tools\repo_activity.py --write

# Verify that committed reports match HEAD.
python .\tools\repo_activity.py --check

# Optional machine-local evidence; never enters public scoring.
python .\tools\repo_activity.py --local-timestamps .\local-repo-times.json
```

Configuration, categories, era labels, exclusions, and score weights live in
[`../repo-activity.json`](../repo-activity.json). Public output uses Git author timestamps and current
blob sizes from `HEAD`, making it stable across clones. The optional local timestamp export exists for
forensics only and should not be committed.
