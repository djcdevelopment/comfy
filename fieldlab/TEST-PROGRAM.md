# TEST PROGRAM — Netcode Replacement, Staged & Gated

**Status date:** 2026-07-09. **This is the only next-step authority.** State of the world:
[GROUND-TRUTH.md](GROUND-TRUTH.md). Invariant definitions: the
[worklog ladder](VALHEIM-NETCODE-REPLACEMENT-WORKLOG.md) (I0–I7). Topology + traps:
[MULTIPLAYER-NETWORK-SETUP.md](MULTIPLAYER-NETWORK-SETUP.md).

**Machine-readable status:** `fieldlab/status/program-status.json` → rendered to the live
dashboard by `fieldlab/scripts/render-dashboard.py`. Every gate that passes or fails updates the
JSON in the same slice; the dashboard is regenerated and republished so Derek can glance instead
of ask.

## The operating contract

- **Derek's entire job:** launch Valheim / log into Steam when a phase needs a rendered player,
  and restart the game when a mod update requires it. Target: minutes per phase, zero console
  commands, zero screen-watching, zero facts he has to fetch for the system.
- **Claude drives everything else** headlessly: builds, deploys (OMEN plugins + am4 scp),
  config flips (always the bepinex-ROOT cfg on am4, never the decoy), probe windows,
  telemetry pulls (via MCP gateway tools), gates, evidence archiving, dashboard updates.
- **Guardrail (persistent memory):** every new in-game measurement ships with (1) config-driven
  auto-start, (2) auto-movement coupling when client motion is needed, (3) an MCP toolsurface
  read (incl. am4-ssh variant), (4) a one-command deploy→run→pull→gate wrapper. Console-only
  workflows are a regression, never a shortcut.
- **Evidence discipline (post-incident):** a step is DONE only when its gate artifact is archived
  under `fieldlab/evidence/` or a signed run packet, and the claim would survive the 2-source
  rule. A PASS with `has_lifecycle_summary=false` or fallback-default counters is not a PASS.
- **Offload split:** parsing/extraction/boilerplate → HEARTH `local_generate` (cost discipline,
  per Derek 12:48Z); Harmony/protocol/integration judgment → frontier; in-game presence → Derek,
  minimized as above.

## Phase map

| Phase | Ladder | One-line goal | Human minutes |
|---|---|---|---|
| P0 Trust reset & canon | — | ground truth re-established, docs converge, dashboard live | 0 |
| P1 Hands-free rig restoration | pre-I* | probe fully drivable via MCP, zero-keystroke cycle | 0 |
| P2 Airtight I1 + connected baseline | I1 | authoritative counters on record topology; baseline packets | ~10 |
| P3 Cheap win + ownership | I6, I2 | Steam-only asserted; ZDO ownership pinned across a transfer trigger | ~10 |
| P4 Outbound redirect | I3 | tagged ZDO traffic suppressed natively & received by Lumberjacks | ~10 |
| P5 Inbound injection | I4 | Lumberjacks-pushed ZDO renders in-world, save intact | ~10 |
| P6 Handshake satisfaction | I5 | client completes connection against a Lumberjacks-fronted peer | ~10 |
| P7 Loopback integrity | I7 | one client fully on Lumberjacks; quit/reload clean | ~15 |

Sequencing per the worklog: P3's I2, P4, P5 are parallelizable after P2; P6 needs P4+P5's shim;
P7 composes everything. Save-integrity is a hard gate on every phase that writes ZDO state
(P3/P5/P7). Legal/ToS check remains a hard gate before anything ships publicly.

---

## P0 — Trust reset & canon  ✅ COMPLETE (this session, 2026-07-09)

| # | Step | Gate | Status |
|---|---|---|---|
| 1 | Session-transcript extract (10 sessions, tool calls + operator turns) | jsonl + summary on disk | ✅ (prior session) |
| 2 | 6-lane cross-verified audit (code, git, I1 evidence, docs, live infra, transcripts) | all lanes returned | ✅ |
| 3 | Adversarial verification of load-bearing single-source claims | verdicts merged | ✅ |
| 4 | I1 PASS re-adjudicated | verdict + caveats in GROUND-TRUTH | ✅ real, 3 overreach caveats |
| 5 | "Tooling cut" theory adjudicated | verdict in GROUND-TRUTH | ✅ refuted — bypass, not deletion |
| 6 | GROUND-TRUTH.md written (claim ledger, graveyard, doc map) | file committed | ✅ |
| 7 | Doc convergence: worklog I1 status, dead OMEN-lab next-steps, i5→OMEN retarget, account/persona table, superseded banners, README pointers | no doc disagrees on state or next step | ✅ |
| 8 | Mod hygiene: manifest 0.5.6, CHANGELOG 0.5.3/0.5.4 backfill, COMMANDS.md +3 | drift zeroed | ✅ |
| 9 | I1 evidence archived to tracked `fieldlab/evidence/i1/` (summary, excerpts, hashes) | in git | ✅ |
| 10 | Wrong-cwd artifact (`fieldlab/fieldlab/`) removed; scratch source-tree question closed | clean tree | ✅ |
| 11 | Trust rule + KVM guardrail banked to persistent memory | memory files exist | ✅ |
| 12 | Dashboard v1 rendered + published; status JSON committed | Derek can glance | ✅ |

**Phase gate:** one canonical entrypoint; zero conflicting next-steps; dashboard reachable. ✅

---

## P1 — Hands-free rig restoration (closes the three wiring gaps; blocks all measurement)

No game session needed. Everything here is headless. Derek: nothing.

| # | Step | Gate |
|---|---|---|
| 1 | Launch gateway natively via `start-comfy-gateway.ps1` (matrix provider restored) | `/healthz` ok on :8720 |
| 2 | Fresh-session MCP round-trip through repo `.mcp.json` | a comfy-gateway tool call returns live data |
| 3 | Toolsurface: `valheim_tail_netcode_probe` (local + am4-ssh) | tool returns real jsonl rows |
| 4 | Toolsurface: `valheim_netcode_probe_summary` (parses verifier summary; flags fallback-mode counters explicitly) | fallback defaults are labeled, never reported as measurements |
| 5 | Toolsurface: `valheim_server_log_tail` am4 variant (join/peer/probe-start lines) | peer-connect visible via MCP within seconds |
| 6 | `valheim_mcp_health` extended to cover new tools | health green |
| 7 | Mod: config-coupled auto-movement — probe arm triggers `TryStartAutoRehearsal` route walk (client-side, off by default) | unit: flag on → rehearsal starts at probe arm |
| 8 | Verifier hardening: max-age check + source host/hash recorded in summary | stale/copied data cannot silently PASS |
| 9 | Build 0.5.7; auto-install to OMEN plugins | boot log shows 0.5.7 locally |
| 10 | Deploy 0.5.7 to am4 + flip ROOT cfg (never the decoy); restart container; confirm version in boot log | `Loading [ComfyNetworkSense 0.5.7]` on am4 |
| 11 | One-command orchestrator: deploy→flags→(walk)→pull→gate→update status JSON→render dashboard | single invocation, zero manual steps |
| 12 | Headless dry-run against the idle am4 server (no client): pipeline flows end-to-end, structural zero expected and labeled as such | dry-run summary archived; dashboard auto-updated |
| 13 | Cleanup owed: am4 `comfy-valheim-am4` llvmpipe project down; decoy cfg deleted; (OMEN compose teardown queued for next Docker Desktop start) | cruft gone or explicitly queued |
| 14 | Commit + dashboard update | phase row green |

**Phase gate:** a full probe cycle runs with **zero human keystrokes** and results arrive through
MCP only. (The dry-run zero is structural — funnels are peer-gated; P2 provides the peer.)

---

## P2 — Airtight I1 + two-player connected baseline (the first game session of the new era)

Derek's ~10 minutes: log OMEN's Steam into **`floooooobcakes`** (persona **wary.fool**), launch
Valheim, Join IP `100.116.82.60:2456`, play/idle for a few minutes when asked, quit when asked.

| # | Step | Gate |
|---|---|---|
| 1 | Settle live Steam mapping (which account is logged in where) via one AskUserQuestion at session start | mapping recorded in status JSON; no dual-login risk |
| 2 | Pre-flight via MCP: server up, mod 0.5.7, probe flags server-side: finite `autostop` (150s), `maxDetailRows` 20000, auto-start on | flags confirmed from ROOT cfg readback |
| 3 | OMEN client cfg: probe auto-start + auto-rehearsal route enabled | cfg readback |
| 4 | **Derek launches + joins** | peer-connect seen via MCP log tail |
| 5 | Connect-burst settles; auto-rehearsal walks the dense-build route (no hands) | route-start row in client telemetry |
| 6 | Probe auto-stops; **authoritative counters row captured both sides** | `has_lifecycle_summary=true`, real uncapped totals, real `parse_errors` |
| 7 | **Inlining question actually settled** (real `send_zdos_calls` vs `create_sync_list_calls`) | worklog + NETCODE-MAP updated with the measured answer |
| 8 | Verifier gate PASS on the new artifacts | summary archived to `evidence/i1-airtight/` with hashes + log excerpt |
| 9 | Server baseline window: N-minute telemetry capture (tick rate, ZDO rates, hitches) as a signed fieldlab packet | packet gates green |
| 10 | Client baseline mirror captured (OMEN jsonl) | packet gates green |
| 11 | Repeatability: second run, same gates | two consecutive green runs |
| 12 | Reconnect/stability: quit, rejoin, world + character intact | no corruption on the 9.15M-ZDO world |
| 13 | (Optional two-seat check) second account (`waryfool`/Zephar410) joins from the i5 → 2-peer capture | 2-peer baseline packet (unblocks Era16 density work later) |
| 14 | A/B perf-era methodology reconciled against new baseline (revive H1–H5 matrix where still relevant) | perf docs' era-banner updated with pointer to new packets |
| 15 | Commit + dashboard | phase row green |

**Phase gate:** I1 upgraded from "reachability proven" to "authoritative counters on the record
topology," inlining measured, and a repeatable connected baseline exists. **This is the
measurement floor every later rung stands on.**

---

## P3 — I6 Steam-only (cheap win) + I2 ownership seizure

Derek: one game launch when asked (~10 min). Save-integrity is a hard gate from here on.

| # | Step | Gate |
|---|---|---|
| 1 | Assert server `CROSSPLAY=false` already satisfies I6 server-side; capture proof | boot log/env evidence archived |
| 2 | Client-side backend assertion probe (PlayFab path never taken; `ZSteamSocket` only) | I6 packet green — ladder I6 ✅ |
| 3 | HEARTH offload: extract valheim-serverside's ownership-pin mechanism into a step list | extract reviewed (frontier) |
| 4 | I2 design decision: pin mechanism + re-assert trigger choice, written to worklog I2 rung | design recorded before code |
| 5 | Implement `OwnershipPinRunner` (config auto-start, windowed, observe+act, off by default) | builds clean; wired per guardrail (MCP tool + auto-start + orchestrator) |
| 6 | MCP tool: `valheim_ownership_pin_status` | readable via gateway |
| 7 | Deploy 0.5.8 both sides (root cfg, version-confirmed) | boot logs |
| 8 | Scenario: pin a test ZDO to authority id; wary.fool enters the zone (auto-route) triggering natural ownership transfer | owner before/during/after logged |
| 9 | **Gate: owner stays pinned across the trigger** | probe rows show pin held |
| 10 | Negative control: unpinned ZDO transfers normally in the same window | control rows archived |
| 11 | **Save-integrity hard gate:** quit → reload → world + pinned/unpinned ZDOs intact | clean reload evidence |
| 12 | Repeatability run | two green runs |
| 13 | Evidence + packets archived; worklog I2 ✅; commit + dashboard | phase row green |

---

## P4 — I3 outbound redirect (suppress native send for tagged ZDOs → Lumberjacks)

Parallelizable with P5 after P2; shares the serialization shim.

1. Lumberjacks gateway up on :4000/:4005 (rebuild if needed; it last ran 7/8) — health checked headlessly.
2. HEARTH offload: ZPackage↔JSON serialization-shim boilerplate drafted; frontier review.
3. Lumberjacks receive endpoint + receipt counter (gateway side).
4. Tag scheme: choose the redirect class (start with a single test-object type).
5. Implement suppression patch at the **proven** send seam (`CreateSyncList`; use P2's measured answer on `SendZDOs`) — off by default, tag-scoped, instant-rollback flag.
6. MCP tools: redirect status + Lumberjacks receipt counts.
7. Deploy both sides; version-confirmed.
8. Window: wary.fool session generates tagged traffic via auto-route.
9. **Gate: Lumberjacks receipt count == suppressed-send count** (no loss).
10. **Gate: client stability** — zero `INVALID_MESSAGE`/socket errors in the window.
11. Rollback rehearsal: flag off mid-session → native path resumes cleanly.
12. Save-integrity gate; repeatability run; packets archived; worklog I3 ✅; commit + dashboard.

## P5 — I4 inbound injection (Lumberjacks-authoritative state renders in-world)

1. HEARTH offload: JSON→ZPackage rebuild boilerplate; frontier hardening review (malformed-input paths — highest-judgment code so far).
2. Injection applier at the mapped receive/apply funnel, off by default, synthetic-tag-scoped.
3. Lumberjacks push endpoint: one known synthetic ZDO (dropped item at a coordinate).
4. MCP tools: injection status + applied-object readback.
5. Deploy; version-confirmed.
6. Window: push synthetic ZDO while wary.fool is in-zone (auto-route to the coordinate).
7. **Gate: object appears in-world, persists ≥ a few seconds, owner reads as Lumberjacks authority id** (auto-verified via probe rows; screenshot only as garnish).
8. Malformed-input battery: truncated/corrupt/duplicate pushes → client survives all.
9. **Save-integrity hard gate:** quit → reload clean with and without the synthetic object present.
10. Repeatability; packets archived; worklog I4 ✅; commit + dashboard.

## P6 — I5 handshake satisfaction (client connects to a Lumberjacks-fronted peer)

1. HEARTH offload: field-by-field handshake checklist (`RPC_PeerInfo` etc.) from the I0 map + decompile.
2. Frontier: Lumberjacks handshake responder (version gate 36, password, error-code order per NETCODE-MAP).
3. Loopback shim harness (no game): responder answers a scripted client hello correctly.
4. MCP tools: handshake trace tail.
5. Stage the client connect path (Steam-only per I6).
6. **Derek launches; client initiates connection to the Lumberjacks-fronted peer.**
7. **Gate: client reaches in-world (past character/spawn) and stays connected ≥30s.**
8. Failure-mode battery: wrong password / wrong version → correct error codes surface.
9. Save-integrity + clean disconnect gates; packets; worklog I5 ✅; commit + dashboard.

## P7 — I7 loopback integrity (the composition gate — proof-of-concept swap)

1. Compose flags: I2 pin + I3 redirect + I4 inject + I5 handshake + I6 Steam-only all active.
2. Pre-flight full-stack health via MCP (gateway, Lumberjacks, am4, client cfg).
3. **Derek launches; connects to Lumberjacks.**
4. Auto-route: move, interact with one Lumberjacks-authoritative object.
5. Gate: no desync errors, no crash across the full window.
6. Gate: quit → world file intact on reload.
7. Full fieldlab packet (the "one client fully on Lumberjacks" milestone artifact).
8. Repeatability run.
9. Retro: what each rung's isolation caught; update NETCODE-MAP + worklog; graveyard additions.
10. Beyond-I7 backlog formally opened (multi-client, Era16 density perf, two-backend question, legal/ToS gate) — explicitly out of this program's scope.

---

*P4–P7 step lists are firm in shape and will be re-detailed at unlock with what the preceding
phase measured (per the ladder's one-invariant-per-slice discipline). The dashboard always shows
the live decomposition.*
