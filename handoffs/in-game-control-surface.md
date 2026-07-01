# In-game control surface vertical slice

**Goal:** Build a Comfy-approved Valheim mod integration slice that proves an in-game player action can
be surfaced natively, captured with context, emitted as a structured payload, and traced/debugged across
the boundary into existing community workflows.

This is not "make a mod with a button." The button is the demo. The asset is the integration workbench:
contracts, fixtures, proof files, logs, and a repeatable way for the next builder to see exactly where a
player action went.

## Why this exists

Players should not have to leave the world, remember a Discord bot command, format proof manually, and
wonder whether they submitted the right thing. If a player is standing in the place where care is
happening, the action should be available there.

The slice must preserve Comfy's current operating model:

- assume Comfy already has an approved mod deployment lifecycle
- integrate with existing Discord/bot/admin workflows
- do not become a new privileged basement bot
- reduce player and rep friction without replacing human review
- make the path observable enough that failures are cheap to diagnose

## The vertical slice

Build one narrow workflow end to end:

```text
in-game player intent
-> native control surface action
-> captured local context
-> structured submission payload
-> local trace/proof artifact
-> bridge/export file for an existing workflow
-> visible status back to the player
```

Recommended first demo: **Submit proof**.

The exact domain can be rank proof, quest completion, build nomination, or gallery highlight. Pick the
smallest workflow where a player action in-game can create a useful structured payload for a human or
existing bot to process.

## Assumptions

- The builder knows C#, Unity, and BepInEx Valheim modding.
- The mod will run in an environment where Comfy's normal mod approval/deployment process exists.
- Comfy already publishes and supports client-side/tool/UI mods through Thunderstore under
  `ComfyMods`; treat that ecosystem as the first approved integration pattern to inspect.
- The slice can be developed locally in single-player or a disposable test world.
- Network calls are optional and not required for v1. The required output is a local bridge file.
- Human review remains downstream. This slice pre-fills, captures, validates, and emits; it does not
  auto-approve.

## Approved ecosystem signal

Before writing new architecture, inspect Comfy's own published mods:

- Thunderstore publisher: `https://thunderstore.io/c/valheim/p/ComfyMods/`
- Source repo: `https://github.com/redseiko/ComfyMods`

Relevant pattern candidates:

- `Chatter`: in-game chat UI behavior and text input patterns.
- `AlaCarte`: menu enhancement/customization patterns.
- `SearsCatalog`: in-game panel resize/reposition and config persistence patterns.
- `ZoneScouter`: client-side tool/debug overlay patterns.
- `BetterZeeLog`: logging conventions.
- `Intermission` / `ComfyLoadingScreens`: Comfy-specific content/config packaging patterns.

Use these as the local standard for:

- project structure
- BepInEx config style
- Harmony patch style
- Thunderstore packaging
- UI look and behavior
- how Comfy names plugins, config keys, commands, and assets

If those patterns conflict with generic Valheim/Jotunn examples, prefer the ComfyMods pattern unless it
blocks the vertical-slice contract.

## Implementation baseline from ComfyMods inspection

Use the ComfyMods pattern for v1:

- BepInEx + Harmony style plugin, modeled on `ZoneScouter` and `Pinnacle`.
- Target framework `net48`, C# 12, and BepInExPack Valheim `5.4.2202`.
- References come from the local Valheim install and BepInEx core.
- Do not introduce Jotunn for v1 unless a later UI feature explicitly requires it.
- Keep the first surface to a hotkey plus console commands. Add a `ZoneScouter`-style panel only after
  the file/trace contract is reliable.
- If code is copied from ComfyMods, account for its GPL-3.0 license. Prefer small local
  reimplementations of patterns when possible.

All control files must be anchored under:

```text
Path.GetDirectoryName(Config.ConfigFilePath)/comfy-control
```

Do not write relative to the process working directory.

## Non-goals

- Do not design Comfy's full mod deployment lifecycle.
- Do not replace Discord, existing bots, staff review, or guild-specific process.
- Do not require a central service.
- Do not require players to adopt a new external tool.
- Do not solve every submission type. Prove one.

## Input contract: action definition

The mod reads a local JSON action definition from:

```text
BepInEx/config/comfy-control/actions.json
```

Example:

```json
{
  "schema_version": 1,
  "actions": [
    {
      "action_id": "submit_proof",
      "label": "Submit Proof",
      "description": "Create a local proof submission from the current player context.",
      "submission_type": "rank_proof",
      "requires_screenshot": true,
      "requires_target": false,
      "bridge": {
        "kind": "file",
        "out_dir": "BepInEx/config/comfy-control/outbox"
      }
    }
  ]
}
```

Required fields:

- `schema_version`: integer, currently `1`
- `actions`: array of action objects
- `action_id`: stable identifier, lowercase snake case
- `label`: text displayed in-game
- `submission_type`: stable workflow identifier
- `requires_screenshot`: boolean
- `bridge.kind`: for v1, `file`
- `bridge.out_dir`: local directory where bridge payloads are written

Optional fields:

- `description`: visible in logs or debug UI
- `requires_target`: whether the action needs a looked-at object/player/build target
- `allowed_context`: future filter for biome, location, guild, build area, etc.

## Output contract: submission payload

Each action writes one JSON payload into the bridge outbox:

```text
BepInEx/config/comfy-control/outbox/<submission_id>.json
```

Example:

```json
{
  "schema_version": 1,
  "submission_id": "20260701-153012-submit-proof-7f3a",
  "run_id": "20260701-153012",
  "action_id": "submit_proof",
  "submission_type": "rank_proof",
  "created_at_utc": "2026-07-01T22:30:12Z",
  "status": "ready_for_review",
  "player": {
    "name": "PlayerName",
    "player_id": "local-or-platform-id-if-available"
  },
  "world": {
    "name": "ComfyEra16",
    "seed": null
  },
  "position": {
    "x": 1234.5,
    "y": 67.8,
    "z": -901.2,
    "biome": "Meadows"
  },
  "target": null,
  "evidence": {
    "screenshot": "evidence/20260701-153012-submit-proof-7f3a.png"
  },
  "notes": "",
  "trace": {
    "trace_id": "20260701-153012-submit-proof-7f3a",
    "trace_file": "traces/20260701-153012-submit-proof-7f3a.trace.jsonl"
  }
}
```

Required behavior:

- Generate a unique `submission_id`.
- Include `run_id`, `action_id`, `submission_type`, timestamp, player identity when available, world
  name when available, and current position.
- If `requires_screenshot` is true, capture a screenshot, wait for the file to exist, and reference it
  by relative path before setting payload status to `ready_for_review`.
- Always include a trace reference.
- Write JSON atomically if possible: write to `*.tmp`, then rename to `*.json`.

## Output contract: trace file

Each submission writes a JSON Lines trace file:

```text
BepInEx/config/comfy-control/traces/<trace_id>.trace.jsonl
```

Each line is one event:

```json
{"ts_utc":"2026-07-01T22:30:12Z","trace_id":"...","step":"action_selected","ok":true,"detail":"submit_proof"}
{"ts_utc":"2026-07-01T22:30:12Z","trace_id":"...","step":"context_captured","ok":true,"position":{"x":1234.5,"y":67.8,"z":-901.2}}
{"ts_utc":"2026-07-01T22:30:13Z","trace_id":"...","step":"screenshot_captured","ok":true,"path":"evidence/...png"}
{"ts_utc":"2026-07-01T22:30:13Z","trace_id":"...","step":"payload_written","ok":true,"path":"outbox/...json"}
```

Minimum trace steps:

- `plugin_loaded`
- `actions_loaded`
- `action_selected`
- `context_captured`
- `screenshot_captured` or `screenshot_skipped`
- `payload_validated`
- `payload_written`
- `player_status_shown`

On failure, write an event with `ok: false`, `step`, and a concise `error`. A failed action should still
leave a trace file.

## In-game behavior

Implement the smallest usable control surface:

- A configurable hotkey opens or triggers the action. Default: `F7`.
- If there is exactly one action, `F7` can run it directly.
- If there are multiple actions, show a simple selection UI or cycle actions with console commands.
- After success, show a short in-game message: `Submission saved: <submission_id>`.
- After failure, show a short in-game message: `Submission failed. Trace: <trace_id>`.
- Status message fallback order: `MessageHud` center message, then available `Chat` message API
  (`Chat.instance` or reflection fallback if needed), then plugin log only.

Acceptable first implementation:

- Console command: `comfy_submit`
- Hotkey: `F7`
- Optional debug command: `comfy_control_status`

Do not block the player with a complex UI in v1. A working hotkey plus console commands is enough.

## Local file layout

Use this layout under BepInEx config:

```text
BepInEx/config/comfy-control/
  actions.json
  outbox/
  evidence/
  traces/
  status/
```

Suggested status files:

```text
status/plugin-status.json
status/last-submission.json
status/last-error.json
```

These files are for operators and builders. They are the workbench.

## Bridge contract

For v1, the bridge is only a file outbox. Another process, bot, human, or future connector can consume
the JSON later.

The mod must not require Discord tokens, bot credentials, webhooks, or privileged server access.

This keeps the boundary clean:

```text
Valheim mod = capture and emit
bridge/outbox consumer = route into existing workflow
human/staff/bot = review and decide
```

Future bridge types can be added after the file contract is stable:

- copy-paste command renderer
- local HTTP handoff to a user-owned helper
- Discord bot import
- steward tool import

Do not build those in the first slice unless the file contract is already working.

## Validation rules

The mod should validate before writing a ready payload:

- `schema_version` is `1`
- `submission_id`, `run_id`, `action_id`, and `submission_type` are non-empty
- timestamp is present
- position has finite `x`, `y`, `z`
- required screenshot exists before payload status becomes `ready_for_review`
- trace file path is present

If validation fails, write:

- a trace event with `ok: false`
- `status/last-error.json`
- no ready outbox payload, or a payload with `status: "failed"` in a separate `failed/` folder

## Test fixtures

Include these with the implementation:

```text
fixtures/actions.single.json
fixtures/actions.multi.json
fixtures/submission.example.json
fixtures/trace.example.jsonl
```

The fixtures are how future agents avoid guessing the contract.

## Test plan

### 1. Plugin load proof

Start Valheim with BepInEx. Confirm:

- plugin logs `Comfy control surface loaded`
- `status/plugin-status.json` exists
- trace includes `plugin_loaded`

### 2. Action config proof

Place `actions.single.json` as `BepInEx/config/comfy-control/actions.json`. Run:

```text
comfy_control_status
```

Confirm:

- status says one action loaded
- invalid JSON creates `status/last-error.json`
- missing actions file creates a useful default or a useful error

### 3. Submission proof

Enter a disposable world. Run:

```text
devcommands
god
fly
comfy_submit
```

Or press `F7`.

Confirm:

- one JSON payload appears in `outbox/`
- one screenshot appears in `evidence/`
- one trace appears in `traces/`
- `status/last-submission.json` points to the new submission
- in-game status message appears

### 4. Failure proof

Make `evidence/` unwritable or configure an invalid outbox path. Run the action.

Confirm:

- player gets a failure message with trace id
- trace contains the failing step
- `status/last-error.json` has a concise error
- no silent failure

### 5. Contract proof

Use a separate script or manual review to confirm the payload matches `fixtures/submission.example.json`.
The exact validator can be built later; the fixture must exist in v1.

## Definition of done

- A BepInEx plugin loads in Valheim.
- A local `actions.json` defines at least one in-game action.
- `F7` or `comfy_submit` produces a valid local submission payload.
- A screenshot evidence file is captured and referenced.
- A trace JSONL file records every major boundary.
- Failure paths leave useful local proof files.
- No network, bot token, Discord credential, or central service is required.
- The README explains install path, config path, command/hotkey, output folders, and how to verify.

## Builder notes

Prefer boring, inspectable implementation choices:

- plain JSON files
- stable schema versions
- trace ids visible in UI/logs/files
- atomic writes for payloads
- one action first
- no clever UI until the contract works
- JSON serialization must be explicit and deterministic. ComfyMods does not standardize a JSON writer;
  avoid adding a new package dependency unless the runtime already provides it.

The scar tissue belongs in the tool. A future builder should not have to rediscover where the boundary
is, whether the screenshot was captured, or which step failed. That is the point of this vertical.
