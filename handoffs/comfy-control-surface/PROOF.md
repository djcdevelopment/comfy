# ComfyControlSurface proof checklist

This file separates what can be proven from the repo from what must be proven inside Valheim.

## Offline proof already available

From the repo root:

```powershell
dotnet build .\handoffs\comfy-control-surface\ComfyControlSurface.csproj -c Release
```

Expected result:

- build succeeds with zero errors
- `bin/Release/ComfyControlSurface.dll` exists
- `bin/Release/ComfyControlSurface_v0.1.0.0.zip` exists

Current package contents should be:

```text
CHANGELOG.md
ComfyControlSurface.dll
manifest.json
README.md
fixtures/actions.multi.json
fixtures/actions.single.json
fixtures/submission.example.json
fixtures/trace.example.jsonl
config/comfy-control/actions.json
```

The package must not contain generated `outbox/`, `evidence/`, `traces/`, `status/`, `bin/`, or `obj/`
workbench output.

## Install proof

From the repo root:

```powershell
.\handoffs\comfy-control-surface\build-and-install.ps1
```

Expected result:

- `ComfyControlSurface.dll` is copied into `Valheim\BepInEx\plugins`
- no source files, fixtures, traces, or generated payloads are copied into `plugins`

## Plugin load proof

Launch Valheim with BepInEx installed, then enter any disposable local world.

Expected result:

- BepInEx log contains `Comfy control surface loaded.`
- `BepInEx/config/comfy-control/` exists
- `BepInEx/config/comfy-control/actions.json` exists
- `BepInEx/config/comfy-control/status/plugin-status.json` exists
- `BepInEx/config/comfy-control/traces/plugin-*.trace.jsonl` exists
- startup trace contains `plugin_loaded`
- startup trace contains `actions_loaded`

## Happy path proof

In-game console:

```text
devcommands
god
fly
comfy_control_status
comfy_submit
```

Expected result:

- player sees a status message for `comfy_control_status`
- player sees `Submission saved: <submission_id>`
- `outbox/<submission_id>.json` exists
- `evidence/<submission_id>.png` exists
- `traces/<submission_id>.trace.jsonl` exists
- `status/last-submission.json` exists

The submission payload should include:

- `schema_version: 1`
- non-empty `submission_id`
- non-empty `run_id`
- `action_id: "submit_proof"`
- `submission_type: "rank_proof"`
- `status: "ready_for_review"`
- player name, or `"unknown"` if unavailable
- finite `position.x`, `position.y`, and `position.z`
- `evidence.screenshot` pointing at the screenshot file
- `trace.trace_file` pointing at the trace file

The trace should include:

- `action_selected`
- `context_captured`
- `screenshot_captured`
- `payload_validated`
- `payload_written`
- `player_status_shown`

## Hotkey proof

Press `F7` in-world with exactly one action configured.

Expected result:

- same output as `comfy_submit`
- pressing `F7` repeatedly while a submission is running shows `Submission already running.`

## Multi-action proof

Replace `BepInEx/config/comfy-control/actions.json` with `fixtures/actions.multi.json`, then run:

```text
comfy_control_reload
comfy_submit
comfy_submit submit_proof
```

Expected result:

- `comfy_control_reload` succeeds
- bare `comfy_submit` asks for an explicit `action_id`
- `comfy_submit submit_proof` writes a normal submission

## Failure proof

Break one thing at a time.

Invalid action config:

```text
edit actions.json so schema_version is 2
comfy_control_reload
```

Expected result:

- player sees a reload failure
- `status/last-error.json` exists
- startup or reload trace contains `actions_loaded` with `ok: false`

Screenshot/output failure:

```text
set Debug.controlRootOverride in the BepInEx cfg to an unwritable path
restart Valheim
comfy_submit
```

Expected result:

- player sees `Submission failed. Trace: <trace_id>`
- `status/last-error.json` exists if the status directory can be written
- trace contains an event with `ok: false`
- no silent failure

## Packaging gap before public Thunderstore release

The current zip is enough for a local proof. A public Thunderstore package should also include
`icon.png`, matching normal ComfyMods package shape.

