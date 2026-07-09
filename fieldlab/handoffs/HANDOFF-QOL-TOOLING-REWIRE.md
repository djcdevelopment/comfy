# Handoff — Rewire hands-free tooling into the netcode probe (QoL regression fix)

> **STATUS 2026-07-09:** I1 is PASS (the "impossible" thing is de-risked). But the I1
> netcode probe was built as a **standalone console workflow** that bypassed the existing
> hands-free rig (auto-movement + MCP gateway). Result: Derek was forced back into being a
> human KVM — typing console commands and hand-walking the i5 character while watching the
> screen. ~5 hours lost to this regression, not to the actual problem. This handoff is the
> plan to wire the probe back into the tooling that already exists. **Nothing needs to be
> rebuilt — it's a wiring job.**

---

## The win (don't lose this)

Rung **I1 PASSED** against a live i5 ↔ am4 session. ZDO send/recv funnels are reachable and
legible at runtime. Inlining question settled: `SendZDOs` **is** JIT-inlined (fired 0×), but
the `CreateSyncList` seam one frame up caught all 3,846 sends → later rungs attach there, not
to `SendZDOs`. recv 1,154 / send 3,846 ZDOs, 50/50 legible, ~1,190 ZDO/s. Evidence in
`fieldlab/runs/i1/`. See [HANDOFF-I1-INTERCEPTION-REACHABILITY](HANDOFF-I1-INTERCEPTION-REACHABILITY.md).

## The regression (what this handoff fixes)

An agent building the I1 probe said, in effect, "I didn't build all that communication into
the mod because I just needed this one thing." That dropped Derek's ~5-day investment in
hands-free tooling. **Root cause: altitude error** — the agent solved the *task* and regressed
the *system Derek works in*. The de-risking was never in doubt once the probe fired; the cost
was entirely self-inflicted on the doorstep.

## What already exists (confirmed on disk — do NOT rebuild)

1. **In-mod auto-movement** — so no one holds WASD:
   - `ComfyNetworkSense.cs`: `TryStartAutoRehearsal()` (called every `Update()`),
     `network_sense_rehearsal` command, teleport-route runner `RunTeleportRoute(...)` with
     simulated directional input (modes `movement_only|axis_north|axis_east|...`, `input-hz`).
   - Config (`Config/PluginConfig.cs`): `autoRehearsalEnabled`, `autoRehearsalRouteFile`
     (`teleport-route.tsv`), `autoRehearsalProfile`, `autoRehearsalDelaySeconds`,
     `autoRehearsalRunOncePerSession`.
   - A `teleport-route.tsv` already exists in OMEN's local Valheim
     `BepInEx/config/comfy-network-sense/`.
2. **MCP gateway** — `network/mcp/comfy_gateway/` with `toolsurface/valheim.py` (tails
   telemetry JSONL, reads BepInEx log, applies whitelisted config profiles, records dev notes,
   offloads explanations to local Ollama). Built in commit `1fce440`.

## The three wiring gaps (the actual work)

- **Gap 1 — movement not coupled to the probe.** `TryDriveNetcodeProbeAuto()` and
  `TryStartAutoRehearsal()` both run in `Update()` but never talk. The probe auto-*starts* on
  peer-connect (headless-safe — good), but nothing auto-*moves* the player, so the captured
  ZDO traffic only exists while Derek hand-walks i5.
  **Fix:** i5 client runs `autoRehearsalEnabled=true` walking `teleport-route.tsv` through the
  dense-build area during the probe window. (Server on am4 is headless — motion must come from
  a client.)
- **Gap 2 — probe invisible to MCP.** `valheim.py` has **zero** netcode-probe tools
  (`grep -c netcode` = 0). No tail of `netcode-probe.jsonl`, no summary reader, no am4
  server-side read. Only way to get results today = read counts off-screen and paste to agent.
  **Fix:** add `valheim_tail_netcode_probe` / `valheim_netcode_probe_summary` (+ an am4 ssh
  variant) to the toolsurface, register them in `get_tools()` and `valheim_mcp_health`.
- **Gap 3 — gateway not connected to the Claude session.** `comfy_gateway` is **not**
  registered as an MCP server in `~/.claude.json` (grep = none). Even existing tools can't be
  called by the agent.
  **Fix:** register it so the agent reads probe output live instead of Derek copy-pasting.
  (Note: the HEARTH `:8710` door via the `checkmcp` skill is a *different* thing — that's
  `local_generate` offload, not this gateway.)

Then fold all three into one command (extend `scripts/run-autonomous-valheim-lab.ps1` or
`scripts/verify-netcode-probe.ps1`): deploy mod both sides → set flags → kick i5 auto-walk →
wait → pull results → gate. One invocation, operator watches nothing.

## Three open decisions (Derek to answer — asked but not yet resolved)

1. **i5 client state / reachability.** Is the *current* mod on i5, and can it be reached via
   SSH/scp over tailnet (`100.125.141.110`) so deploy + config flips are remote? Or is i5
   manual-only? (Setup doc notes i5 has previously run an unmodded/old client fine.)
   — If unknown, next agent should probe i5 and report before deciding.
2. **Movement source.** Auto-walk the **real i5 player** (keeps the 2-player i5↔am4 session
   Derek just got working) vs. spin a **synthetic lab client** via
   `run-autonomous-valheim-lab.ps1`. Leaning real i5 player.
3. **MCP connection scope.** Register `comfy_gateway` into the Claude session now (agent reads
   results live) vs. add the netcode tools but connect later.

## The durable guardrail (root-cause fix — not yet written)

Proposed feedback memory + banner on the I1 handoff and worklog:
**"Any new in-game measurement runs through the auto-rehearsal + MCP surface. Console-only /
hand-driven workflows are a regression, not a shortcut. Do not strip the KVM-elimination
tooling to ship 'just one datapoint.'"**
(Not yet saved — Derek was mid-reboot. Write this before the next in-game measurement task.)

## Key paths

- Mod: `C:\work\comfy\network\mod\ComfyNetworkSense\` (`ComfyNetworkSense.cs`,
  `Config/PluginConfig.cs`, `Core/Services/NetcodeProbeRunner.cs`)
- MCP: `C:\work\comfy\network\mcp\comfy_gateway\toolsurface\valheim.py`
- Lab scripts: `C:\work\comfy\fieldlab\scripts\run-autonomous-valheim-lab.ps1`,
  `verify-netcode-probe.ps1`
- Topology / traps: `fieldlab/MULTIPLAYER-NETWORK-SETUP.md`
- I1 evidence: `fieldlab/runs/i1/`
