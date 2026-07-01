# Comfy control bridge consumer

Local bridge proof for `ComfyControlSurface` outbox payloads.

This consumes JSON files written by the in-game mod and renders review-ready markdown without network
access, bot tokens, webhooks, or privileged services.

## Use

From the repo root, against the live Valheim workbench:

```powershell
python .\handoffs\comfy-control-surface\bridge-consumer\bridge_consumer.py `
  "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-control"
```

Against the included fixture:

```powershell
python .\handoffs\comfy-control-surface\bridge-consumer\bridge_consumer.py `
  .\handoffs\comfy-control-surface\bridge-consumer\fixtures
```

## Output

The script writes one markdown review file per payload:

```text
bridge-review/<submission_id>.md
```

The review keeps the original `submission_id`, evidence path, trace path, player, world, biome, and
coordinates. It does not move or modify the source payload.

## Contract

Input:

- `outbox/*.json`, or a directory containing `*.json` fixture files
- schema version `1`
- status `ready_for_review`

Output:

- `bridge-review/<submission_id>.md`
- clear validation errors on stderr with exit code `1`

