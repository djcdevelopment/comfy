# GROUND TRUTH — Valheim Netcode Replacement

**Status date:** 2026-07-09 (evening). **This is the canonical entrypoint.** Read this first;
every other status doc either feeds it or is superseded by it.

- **Active plan:** [TEST-PROGRAM.md](TEST-PROGRAM.md) (the phased, gated test program)
- **Ladder spine:** [VALHEIM-NETCODE-REPLACEMENT-WORKLOG.md](VALHEIM-NETCODE-REPLACEMENT-WORKLOG.md) (invariants I0–I7)
- **Topology runbook:** [MULTIPLAYER-NETWORK-SETUP.md](MULTIPLAYER-NETWORK-SETUP.md) (the two traps; deploy recipe)
- **Live dashboard:** see `fieldlab/status/` (program-status.json + rendered dashboard)

**Provenance:** produced by a 10-agent cross-verified audit (6 independent auditors — mod code,
git forensics, I1 run evidence, doc conflicts, live am4/OMEN runtime, session-transcript
forensics — plus 4 adversarial verifiers; 222 tool calls). Trust rule enforced throughout:
**nothing timestamped after commit `c196f88` (I0 netcode map, 2026-07-09 04:54 PDT) counts
without ≥2 independent non-documentation sources.** Documentation prose was never accepted as
corroboration for itself.

---

## The verdicts (headlines)

1. **Nothing was deleted. The core work is all still there.** Zero file deletions in
   `e92160e..HEAD`; all 28 console commands (movement/tp/rehearsal, MCP raven/status/note,
   priority, shadow, projection, netcode probe) are registered in
   `ComfyNetworkSense.cs` at HEAD; the full `network/mcp` gateway tree is intact and a strict
   superset of its 1fce440 peak; nothing orphaned in reflog/stashes/branches; main == origin/main.
   The mod builds clean (0 warnings) at **0.5.6**, and the built DLL is byte-size-identical to
   what is installed on both OMEN and am4.

2. **The "agent cut out my tooling" event was a BYPASS, not a deletion.** Session `f09e342f`
   (2026-07-09 ~12:07Z) built the I1 probe as a standalone console workflow that side-stepped the
   existing auto-rehearsal + MCP rig — so Derek was forced back into human-KVM duty (~5h lost).
   The tooling itself never left the tree. The fix is a **wiring job** (three gaps, below), not a
   rebuild.

3. **The I1 PASS is real.** Four independent sources corroborate a genuine connected
   client↔server run on 2026-07-09 14:46–14:47 UTC: the 1.28 MB `netcode-probe.jsonl`
   (1,154 recv + 3,846 send ZDO rows, 0 of 5,000 rows missing uid/owner), the session tool-call
   log (deploy→restart→join→scp chain), the byte-identical source file still on am4 (md5 match),
   and am4 docker logs showing character `Durracktu`'s ZDOID matching the probe's recv owner uid
   to the second. **Both ZDO funnels are reachable and legible in a live session. I1 gate: PASS.**

4. **But three claims stacked on the PASS were overreach** (now corrected in the source docs):
   - **"SendZDOs is JIT-inlined — SETTLED" was never measured.** The probe ran with `autostop=0`,
     so no stop/counters row was ever written; every `*_calls` counter and `parse_errors=0` in the
     summary is a **verifier fallback default, not a measurement**. The inlining hypothesis remains
     plausible-and-likely, and attaching later rungs at `CreateSyncList` is safe regardless (that
     seam IS proven). But treat "SendZDOs inlined" as **unverified** until a finite-autostop run
     emits a real counters row.
   - The capture is a **4.2-second initial-connect world-sync burst** that hit the 5,000-row detail
     cap — not the 60–90s dense-area traversal the handoff narrative implies. Reachability is
     genuinely proven; sustained-play behavior and the zero-drop figure are not.
   - The **"i5 ↔ am4" client identity is uncorroborated** (an am4-local GPU client container was
     also up during the window). Doesn't weaken the gate — any real peer suffices.

5. **The infrastructure is healthy and live** (attested 2026-07-10 00:30 UTC): am4 server container
   Up 10h publishing UDP 2456-2457, Valheim l-0.221.12 / net protocol 36, world `ComfyEra16`
   (1.33 GB, ~9.15M ZDOs), mod 0.5.6 loaded, telemetry actively writing (38.5 MB
   `telemetry-server.jsonl`, rows seconds old at inspection). Probe auto-start is **enabled live**
   on the server — a fresh probe artifact will generate itself on the next player join.
   Tailnet OMEN→am4: 2 ms. HEARTH door :8710 up. The ~30-min server world-reloads are graceful
   `UPDATE_IF_IDLE` cycles, **not** a crash loop.

6. **The doc layer was the real casualty.** Four mutually-exclusive "next step" instructions
   coexisted (worklog → OMEN Docker lab [impossible]; HANDOFF-I1 → finite-autostop re-run;
   HANDOFF-QOL → rewire first; bringup HTML → its own 5-step plan). The worklog said I1 "awaiting
   connected run" while three sibling docs in the *same commit* said PASSED. Corrections are
   applied as of this commit; [TEST-PROGRAM.md](TEST-PROGRAM.md) is now the only next-step
   authority.

---

## The three wiring gaps (the actual QoL regression)

| Gap | State | Fix lives in |
|---|---|---|
| 1. Probe doesn't trigger auto-movement — captured traffic only exists while a human walks | **OPEN** (no commit after b5ec7a5 touches the mod) | TEST-PROGRAM P1 |
| 2. MCP toolsurface has **zero** netcode tools (`grep -c netcode valheim.py` = 0) — results can't be read through MCP | **OPEN** | TEST-PROGRAM P1 |
| 3. Gateway not registered as an MCP server | **PARTIALLY CLOSED** — `8c59afb` added repo `.mcp.json` (:8720) + `start-comfy-gateway.ps1`; chain verified valid on disk. Caveats: loopback-only bind; nothing listens until the ps1 runs; the launch line silently dropped the `matrix` toolsurface (restored this commit) | TEST-PROGRAM P1 |

**The durable guardrail (now in persistent memory):** any new in-game measurement runs through
the auto-rehearsal + MCP surface. Console-only / hand-driven workflows are a regression, not a
shortcut. Do not strip the KVM-elimination tooling to ship "just one datapoint."

---

## Topology of record (per Derek, 2026-07-09 15:26–15:36Z — supersedes all older docs)

| Role | Machine | Identity | Notes |
|---|---|---|---|
| Dedicated server | **am4** (`100.116.82.60`, `ssh derek@am4`) | associated with **Zephar410** | native Linux Docker (the only thing that publishes UDP); container `comfy-valheim-server-am4-valheim-server-1`; state `~/comfy-valheim-lab/server-state/` |
| Player two (the rendered client) | **OMEN** (RTX 5070, this desk) | persona **wary.fool** | native Windows Valheim — **no Docker, nothing fancy** |
| Optional extra seat | i5 laptop (`100.125.141.110`) | — | was the emergency reference client for the I1 run; now optional only |

⚠️ **Account-name/persona collision (active trap, now settled):** Steam account **`waryfool`**
carries persona **Zephar410**; Steam account **`floooooobcakes`** carries persona **wary.fool**
(the dota2 smurf). The near-collision of "waryfool" vs "wary.fool" generated the doc
contradictions. To put **wary.fool on OMEN**, OMEN logs into **`floooooobcakes`**. One license per
account, single-session each.

Standing physical constraints (all confirmed, all in memory): Docker Desktop/Windows publishes no
UDP (server must live on am4) · GPU-less containers = llvmpipe = unusable (players must be native
on real GPUs) · Arc B70 needs Mesa 26 (no am4-rendered client) · the am4 mod cfg lives at the
**bepinex root**, not the `config/` subdir decoy (Trap 2 in the setup runbook).

---

## Claim ledger (condensed — full evidence in the audit transcript)

Status key: ✅ CONFIRMED (≥2 independent sources) · ❌ REFUTED · ◻ UNCORROBORATED (doc/memory only).

**Code & git**
- ✅ Mod working tree = HEAD, builds clean, v0.5.6, zero orphaned services, all capabilities wired.
- ✅ No deletions e92160e..HEAD; no dangling work in git objects; abandoned branch fully cherry-picked.
- ✅ `network/mcp` untouched since e92160e; HEAD is a superset of the 1fce440 peak.
- ❌ "A lighter patch deleted movement/MCP/communication tooling" — refuted three ways (diffs, command surface, deployed-DLL version match).
- ✅ Version bookkeeping drifted: manifest said 0.5.1, CHANGELOG skipped 0.5.3/0.5.4, COMMANDS.md missed 3 commands (**fixed this commit**).

**I1 evidence**
- ✅ Real connected-session PASS (see verdict 3). Artifacts predate the commit by ~19 min; timeline coherent.
- ❌ "Inlining settled" — the deciding counters were provably never emitted (see verdict 4).
- ✅ Capture = connect burst, not traversal. `parse_errors=0` is a fallback default.
- ✅ The verifier cannot pass a zero-client session (funnels are peer-gated) — but it has no
  freshness/origin check, so it *could* pass stale/copied data. (Didn't happen here — md5-verified
  37s-fresh scp. Hardening noted in TEST-PROGRAM P1.)
- ✅ PASS evidence was gitignored (only on OMEN disk + am4) — **archived to `fieldlab/evidence/i1/` this commit**.

**Live runtime (2026-07-10 00:30 UTC)**
- ✅ am4 server Up/UDP-published/mod-0.5.6-loaded/telemetry-writing; world ComfyEra16 9.15M ZDOs.
- ✅ Same 292,352-byte 0.5.6 DLL installed on OMEN (07:26 PDT) and am4 (07:28 PDT).
- ✅ Config trap live: real cfg (bepinex root, rewritten each boot) + 656 B decoy both exist; settings currently agree; probe auto-start **enabled** server-side.
- ✅ Cruft: am4 llvmpipe GPU-client container (`comfy-valheim-am4-valheim-client-gpu-1`) still Up and useless.
- ◻ OMEN's 4–5-container mess: Docker Desktop engine is **stopped**, so it can be neither confirmed nor torn down until the engine next runs. Engine-off ≠ cleaned up.
- ✅ comfy-gateway :8720 not running (expected between sessions; start script must run before Claude Code). HEARTH :8710 **up** (`/mcp` answers; `/healthz` 404 is a route difference, not an outage).
- ✅ Lumberjacks repo exists; its gateway (:4000/:4005) not running (expected between sessions).

**Sessions/incident**
- ✅ All 10 extracted sessions (Jul 4 → Jul 9) ran with cwd `C:\work\comfy\fieldlab` — the
  wrong-directory problem dates to July 4. (Even trusted I0 came from a wrong-cwd session — it
  survived on quality.) Fixed by standing rule: **always start in `C:\work\comfy` root.**
- ✅ "Two identical sessions" were one session double-parsed (transcript fork at an interrupted voice turn).
- ✅ Five containers total chased player-two; resolution chain: llvmpipe (OMEN) → Mesa-26 (am4 GPU
  client) → tcpdump proof of Docker Desktop UDP non-publish → server relocated to am4 → real
  player joined from i5 → player-two re-designated to OMEN native per Derek.

---

## Document map (dispositions applied this commit)

| Doc | Role | Disposition |
|---|---|---|
| **GROUND-TRUTH.md** (this) | canonical entrypoint / state of the world | — |
| **TEST-PROGRAM.md** | the ONLY next-step authority | new this commit |
| VALHEIM-NETCODE-REPLACEMENT-WORKLOG.md | I-ladder spine (invariants + gates) | FIXED: I1 → PASS w/ caveats; impossible OMEN-lab "Next" removed |
| MULTIPLAYER-NETWORK-SETUP.md | topology + traps runbook | FIXED: account/persona table corrected; player-two = OMEN |
| NETCODE-MAP.md | I0 deliverable (trusted anchor) | KEEP as-is |
| handoffs/HANDOFF-I1-INTERCEPTION-REACHABILITY.md | I1 evidence record | FIXED: inlining caveat; dead OMEN-lab recipe annotated |
| handoffs/HANDOFF-QOL-TOOLING-REWIRE.md | gap analysis (absorbed into P1) | FIXED: movement source i5→OMEN; Gap-3 status updated |
| handoffs/HANDOFF-PLAYER-ON-NETWORK-AM4-SERVER.md | player-two war story | BANNERED superseded (topology + account mapping stale) |
| valheim-bringup-plan.html | pre-audit bringup sketch | BANNERED superseded by this doc + TEST-PROGRAM |
| NETWORKSENSE-PERF-DEBUG-PLAN.md · NETWORKSENSE-ERA16-MATRIX.md · handoffs/HANDOFF-PERF-TEST-AB-CHECKLIST.md | July-4→8 perf era (methodology still valid) | BANNERED era-bound; revisit at P2 baseline |
| fieldlab/README.md · root README.md | cold-reader entrypoints | FIXED: pointer block to this doc |

---

## Red-herring graveyard — do NOT re-chase these

Dead theories, each with its refutation. If a doc or memory suggests one of these, it's stale.

**The incident's own theories**
- "Tooling was deleted from the mod" → bypass, not deletion (verdict 2).
- OMEN Windows Firewall blocking UDP → rule was added, still failed; tcpdump proved Docker Desktop publishes no UDP at all.
- "The locally running OMEN game disturbed the docker player-two" → never substantiated; real blockers were llvmpipe, single-account dual-login, UDP non-publish.
- OMEN steam-headless container as player-two → no GPU → llvmpipe ("hand-drawn"), unusable.
- Lending the container OMEN's iGPU/NPU → Docker Desktop can't pass them into Linux containers.
- am4 GPU-passthrough client → Arc B70 needs Mesa 26.x; container ships 25.0.7 → llvmpipe. (That container is still up on am4 as cruft — tear down.)
- Vulkan on weak/no-GPU boxes → crashes; use the OpenGL launch option.
- Fresh Steam account `+connect` → silently no-ops until a character exists.
- Keeping the server on OMEN in any form → dead by design; do not restart `comfy-valheim-lab-valheim-server-1`.
- The OMEN "autonomous Docker lab" as I1 execution path → same dead topology; was still written as "Next" in three docs (now fixed).

**Audit-era false alarms**
- manifest.json 0.5.1 / bin\Debug 0.5.4 DLL "prove a rollback" → stale metadata/artifacts; Release + installed DLLs are 0.5.6.
- Summary counters `calls=0` "prove funnels never fired" → verifier fallback defaults; the 5,000 detail rows are the real signal.
- The 14:32Z ssh wait-loop that found nothing → it watched the config-path **decoy** dir; the probe wrote to bepinex root.
- am4 server "restart loop" → graceful idle-update cycle. `frame_ms≈49s` hitches → boot-time world-load on 9.15M ZDOs, not live degradation.
- `telemetry-client.jsonl` on the headless server → the mod writes client_live rows headless; not a hidden rendered client.
- HEARTH `/healthz` 404 → wrong route, door is up at `/mcp`.
- "Two source trees — reconcile network/mod vs scratch/ComfyMods" → scratch copy is Jul-3 bin/obj output with zero source files; there is exactly one source tree.
- Stray root NETCODE-MAP.md / scattered handoffs under fieldlab/fieldlab → never existed / one ignorable wrong-cwd run dir (removed this commit).
- "Derek only ever ran Valheim in Docker" → hallucination, called out live; native installs confirmed.
- Pre-restart docker connections at 14:17/14:31/14:39Z → the same client across server restarts, not multiple players.
- "step 2 vs step 3 vs step 6" progress conflict → three DIFFERENT ladders being counted (perf tests vs I-rungs vs bringup steps); the real conflicts were the I1 status line and the next-step fork, both now fixed.
- Client "high latency" (rtt_ms≈538ms / jitter≈509ms, 2026-07-10) → NOT the network: ICMP + tailscale OMEN→am4 = 2–4ms, direct LAN (192.168.12.233, no DERP). The mod mislabels `ZNet.GetServerPing()` as RTT, but that returns `ZRpc.m_timeSinceLastPing` — a 0→~1000ms ping-heartbeat sawtooth (`m_pingInterval=1f`, resets on each ping/pong), so a healthy link samples ~500ms avg + ~500ms "jitter". Exclude rtt/jitter from the P2 step 9/10 baselines; true RTT needs a ZRpc ping/pong round-trip patch (deferred, Derek's call 2026-07-10).
- Server boot log "Sending PlayFab login request" → NOT crossplay (2026-07-10, I6 check): that's PlayFab server-registry/matchmaking auth, which a Steam-only server does regardless. The crossplay game socket is a separate "Opened PlayFab server" (ZPlayFabSocket host, only if `m_onlineBackend==PlayFab`, ZNet:344-350) which did NOT appear; "Opened Steam server" did, and env `CROSSPLAY=false`. Steam-only transport confirmed — see `evidence/i6-steam-only.md`.

---

## Cleanup owed (tracked in TEST-PROGRAM P1; none of it blocks work)

1. am4: `docker compose down` the dead `comfy-valheim-am4` llvmpipe client project.
2. OMEN: next time Docker Desktop is running, `docker compose down` the `comfy-valheim-lab` project (server permanently dead; client-01/02 orphaned). Optionally remove the now-irrelevant firewall rule.
3. am4: delete the decoy cfg at `bepinex/config/…comfynetworksense.cfg` (landmine for future sessions).
4. Verifier hardening: max-age + source-host/hash recording (audit-proofing).
