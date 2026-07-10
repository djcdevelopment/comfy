# Program status & live dashboard

- **Live dashboard (stable URL):** https://claude.ai/code/artifact/1c10f4f8-d747-4411-a400-26d5fb155117
- **Source of truth:** `program-status.json` — machine-readable phase/step/gate state.
- **Renderer:** `../scripts/render-dashboard.py` → `dashboard.html` (deterministic, no network).

## Update protocol (any session, any agent)

1. Edit `program-status.json` (flip step statuses, update `updated`, `needs_derek`, infra states).
2. `python fieldlab/scripts/render-dashboard.py` (full Python312 path on OMEN — PATH `python` is a Store stub).
3. Redeploy `dashboard.html` to the **same** artifact URL above (Artifact tool with `url` param).
4. Commit both files in the same slice as the gate evidence that changed them.

A gate is not "green" on the dashboard until its evidence is archived (see
`../TEST-PROGRAM.md` → evidence discipline).
