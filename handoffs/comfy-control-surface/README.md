# ComfyControlSurface

Local Valheim/BepInEx proof slice for an in-game Comfy workflow handoff.

**Handing this to someone?** [`QUEST.md`](QUEST.md) is the delivery brief — the full loop from
install to a real, paste-able guild bot command, written to be run from the package zip alone.

## Install

Build the project and place `ComfyControlSurface.dll` in:

```text
Valheim/BepInEx/plugins/
```

The plugin creates its workbench under:

```text
Valheim/BepInEx/config/comfy-control/
```

## Use

- `F7`: open the local in-game panel.
- `comfy_submit`: submit the default action.
- `comfy_submit <action_id>`: submit a specific action.
- `comfy_control_status`: reload actions and show status.
- `comfy_control_reload`: reload `actions.json`.

Outputs:

- `outbox/<submission_id>.json`
- `evidence/<submission_id>.png`
- `receipts/<submission_id>.json`
- `traces/<trace_id>.trace.jsonl`
- `status/plugin-status.json`
- `status/last-submission.json`
- `status/last-receipt.json`
- `status/last-error.json`

No network, bot token, webhook, or privileged service is required.

The packaged starter action file is the Slayer rank proof pilot:

```text
Slayers -> Rank Proof -> Thrall / Thegn / Jarl
```

It is generated from the rank-ladder recipe output:

```powershell
python .\handoffs\comfy-control-surface\generate-actions-from-rank-ladder.py `
  .\recipes\rank-ladders\example-output.json `
  .\handoffs\comfy-control-surface\Config\comfy-control\actions.json
```

## Proof

Use [`PROOF.md`](PROOF.md) for the offline, install, in-game, hotkey, multi-action, failure, and package
checks.

## Support Diagnostics

Run:

```powershell
.\handoffs\comfy-control-surface\support\diagnose.ps1
```

This writes `support-report.md` and `support-report.json` with install health, action-load status,
latest traces/submissions/receipts/errors, BepInEx log excerpts, bridge-review counts, and package contents.

## Bridge Consumer

Use [`bridge-consumer/`](bridge-consumer/) to validate `outbox/*.json` payloads and render local
review markdown without network access or bot credentials.
