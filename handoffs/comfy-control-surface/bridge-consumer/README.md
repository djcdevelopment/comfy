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
bridge-review/index.json
bridge-review/state/<submission_id>.json
```

The review keeps the original `submission_id`, evidence path, trace path, player, world, biome, and
coordinates. It does not move or modify the source payload. Existing review state is not overwritten
when the bridge consumer is rerun.

## Review Inbox

After importing payloads, use the review inbox CLI:

```powershell
python .\handoffs\comfy-control-surface\bridge-consumer\review_inbox.py `
  "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-control" list

python .\handoffs\comfy-control-surface\bridge-consumer\review_inbox.py `
  "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-control" show <submission_id>

python .\handoffs\comfy-control-surface\bridge-consumer\review_inbox.py `
  "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-control" accept <submission_id>

python .\handoffs\comfy-control-surface\bridge-consumer\review_inbox.py `
  "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-control" reject <submission_id> --reason "..."

python .\handoffs\comfy-control-surface\bridge-consumer\review_inbox.py `
  "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-control" needs-info <submission_id> --reason "..."

python .\handoffs\comfy-control-surface\bridge-consumer\review_inbox.py `
  "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-control" export <submission_id>
```

State values:

- `pending`
- `accepted`
- `rejected`
- `needs_info`
- `exported`

Every state transition appends to:

```text
bridge-review/events.jsonl
```

## Contract

Input:

- `outbox/*.json`, or a directory containing `*.json` fixture files
- schema version `1`
- status `ready_for_review`

Output:

- `bridge-review/<submission_id>.md`
- `bridge-review/index.json`
- `bridge-review/state/<submission_id>.json`
- clear validation errors on stderr with exit code `1`
