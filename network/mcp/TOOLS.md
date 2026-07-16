# Comfy MCP Tools

Source of truth: `contracts/commands.json`.

Primary tools for agents:

- `valheim_mcp_health`: verify gateway paths and local services.
- `valheim_networksense_files`: list telemetry files.
- `valheim_networksense_report`: compact deterministic report from recent samples.
- `valheim_authoritative_status`: inspect the rendered mod's direct Gateway poll/apply/ack state.
- `valheim_explain_networksense`: report plus local Ollama explanation.
- `valheim_list_sessions`: find session IDs.
- `valheim_session_bundle`: collect one session for handoff or comparison.
- `valheim_compare_clients`: compare host/client bundles for multiplayer tests.
- `valheim_suggest_next_test`: recommend the next practical in-game test.
- `valheim_suggest_config`: recommend config changes without applying them.
- `valheim_apply_config_profile`: apply whitelisted config profiles only.
- `valheim_record_note`: append a dev note.

Rules:

- Prefer deterministic report tools before calling Ollama.
- Treat suggestions as suggestions. Do not apply config or code changes without an explicit user request.
- After `valheim_apply_config_profile`, tell the user to run `network_sense_reload_config` in-game.
- Keep this gateway localhost-only.
- Do not ask collaborators to run MCP unless they are explicitly debugging.
