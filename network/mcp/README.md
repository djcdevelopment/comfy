# Comfy MCP Gateway

Local MCP gateway for Comfy Valheim mod development.

This is intentionally separate from Hearth. It keeps its own auth header, port,
ledger, caller registry, and Valheim-specific tools.

## Endpoint

```text
http://127.0.0.1:8720/mcp
```

Dev HTTP helpers for the in-game panel:

```text
GET  http://127.0.0.1:8720/healthz
GET  http://127.0.0.1:8720/valheim/report
GET  http://127.0.0.1:8720/valheim/next-test
GET  http://127.0.0.1:8720/valheim/config-suggestion
POST http://127.0.0.1:8720/valheim/apply-profile
```

Auth header:

```text
X-Comfy-Key: comfy-dev-local
```

The future Valheim mod client should use:

```text
X-Comfy-Key: valheim-mod-local
```

## Run

Use the same Python environment that has `mcp==1.28.1`, such as Hearth's OMEN venv:

```powershell
$env:PYTHONPATH = "C:\work\comfy\network\mcp"
C:\work\commandcenter\fleet-worker-node\.venv-omen\Scripts\python.exe `
  -m comfy_gateway.kernel.gateway
```

Or run:

```powershell
.\network\mcp\etc\start-comfy-gateway.cmd
```

## Tools

- `comfy_gateway_status`: gateway identity, providers, ledger, caller.
- `local_generate`: direct local Ollama generation.
- `valheim_networksense_files`: list NetworkSense telemetry files.
- `valheim_tail_networksense`: tail a NetworkSense JSONL file.
- `valheim_tail_bepinex_log`: tail/filter BepInEx log output.
- `valheim_networksense_report`: compact recent telemetry report.
- `valheim_explain_networksense`: report plus local Ollama explanation.
- `valheim_mcp_health`: path/service health for the dev gateway.
- `valheim_list_sessions`: summarize known NetworkSense sessions.
- `valheim_session_bundle`: gather one session's client/server/events/benchmarks.
- `valheim_compare_clients`: compare host/client bundles for multiplayer tests.
- `valheim_suggest_next_test`: deterministic next-test suggestions.
- `valheim_suggest_config`: deterministic config suggestions; does not apply.
- `valheim_apply_config_profile`: apply a whitelisted dev config profile.
- `valheim_record_note`: append a dev note for this test session.

## Design Rules

- Localhost only.
- Dev-only; not production mod functionality.
- JSONL remains source of truth.
- Keep MCP calls command-triggered or event-triggered, never per-frame.
- Treat model output as text or suggestions; do not execute arbitrary returned actions.
