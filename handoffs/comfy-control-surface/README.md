# ComfyControlSurface

Local Valheim/BepInEx proof slice for an in-game Comfy workflow handoff.

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

- `F7`: submit the default action when exactly one action is configured.
- `comfy_submit`: submit the default action.
- `comfy_submit <action_id>`: submit a specific action.
- `comfy_control_status`: reload actions and show status.
- `comfy_control_reload`: reload `actions.json`.

Outputs:

- `outbox/<submission_id>.json`
- `evidence/<submission_id>.png`
- `traces/<trace_id>.trace.jsonl`
- `status/plugin-status.json`
- `status/last-submission.json`
- `status/last-error.json`

No network, bot token, webhook, or privileged service is required.
