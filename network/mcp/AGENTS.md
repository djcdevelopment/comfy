# Agent Operating Rules

Use the Comfy MCP gateway as a dev observability surface, not as gameplay logic.

Recommended workflow:

1. Call `valheim_mcp_health`.
2. Call `valheim_networksense_files`.
3. Call `valheim_networksense_report`.
4. If the report is ambiguous, call `valheim_explain_networksense`.
5. Record notable human observations with `valheim_record_note`.
6. For multiplayer, collect `valheim_session_bundle` from host and client logs, then call `valheim_compare_clients`.

Safety boundaries:

- Do not run production gameplay through MCP.
- Do not require non-dev players to run the gateway.
- Do not execute arbitrary model output.
- Do not flood the gateway from the game loop.
- Assume JSONL telemetry is the durable source of truth.

