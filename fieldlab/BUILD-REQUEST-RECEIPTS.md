# Build Request Receipts

Use this lane when real build work should count as evidence instead of running another
synthetic P7 repeat. Each request gets a stable receipt id, request body, repo context,
and close-out status under ignored local runtime state:

`fieldlab/runs/build-requests/`

## Environment

For Hearth/Vertex-backed work, start the shell with the project context already proven
by ADC:

```powershell
$env:GOOGLE_CLOUD_PROJECT = "lumberjacks-exp-20260711-djc"
$env:GOOGLE_CLOUD_LOCATION = "global"
```

## Create A Request

Pipe the real request into the receipt tool:

```powershell
@'
Build the next small thing.

Acceptance:
- keep the change scoped
- run the relevant validation
- report the commit or blocker
'@ | C:\work\comfy\fieldlab\scripts\new-build-request-receipt.ps1 `
  -Title "example build request" `
  -Lane "hearth" `
  -Repo "C:\work\comfy" `
  -PrintPrompt
```

The script prints:

- `BUILD_REQUEST_RECEIPT=<id>`
- `REQUEST=<path>`
- `RECEIPT=<path>`

Use the request file as the prompt/context for Hearth, Codex, or a manual build pass.

## Close A Request

After the work lands or blocks, close the receipt:

```powershell
C:\work\comfy\fieldlab\scripts\close-build-request-receipt.ps1 `
  -Id "br-YYYYMMDD-HHMMSS-xxxxxxxx" `
  -Status done `
  -Repo "C:\work\comfy" `
  -Summary "Implemented and validated the requested change." `
  -Commits "abc1234"
```

Use `-Status failed`, `blocked`, or `cancelled` when appropriate. The close-out appends
the updated record to `ledger.jsonl`, so the request stream is auditable even when
individual receipt files are overwritten with their latest status.

## Why This Counts

The P7 deployment already proved the GCP Valheim/Lumberjacks runtime. For ongoing work,
the useful receipts are now build receipts: request id, input, repo revision before/after,
validation result, and commit or blocker. This is production-shaped evidence rather than a
repeat of the same synthetic loopback window.
