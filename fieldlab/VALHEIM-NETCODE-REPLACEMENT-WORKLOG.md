# Valheim Netcode Replacement — Worklog & Test Program

> **2026-07-09 post-audit note:** state of the world lives in [GROUND-TRUTH.md](GROUND-TRUTH.md);
> the live phased plan is [TEST-PROGRAM.md](TEST-PROGRAM.md). This file remains the ladder spine
> (invariant definitions I0–I7 and their gates).

Date opened: 2026-07-08. Companion to
`VALHEIM-NETCODE-REPLACEMENT-FEASIBILITY-RESEARCH.md` (the grounded feasibility
pass) and `VALHEIM-LUMBERJACKS-FEASIBILITY.md` (the layer matrix).

**Destination:** a 100% swap of Valheim's native network/replication layer for an
external authoritative server (Lumberjacks), with the Valheim client still running
and rendering locally. Everything built to date (sidecar probe → projection →
shadow → priority manifest → datagram lane → in-game consumer) was the
environment-dialing warm-up. This document is the program to reach the actual
destination.

---

## Method: isolate one invariant per slice

Same wind-tunnel discipline the priority-manifest work used. The full swap is not
one build; it is a **ladder of independent yes/no questions**, each of which can be
proven or killed *in isolation* while holding everything else constant. We never
"try the whole swap." We prove one invariant, land a fieldlab packet with a
verifier, then move up. A failed invariant with no untested workaround is the only
thing that stops the ladder — and per the standing directive, "no workaround left"
must be *demonstrated*, not assumed.

Each rung below states: **the invariant** (the one thing being proven), **why it
isolates cleanly**, **prerequisites**, **the probe + pass gate**, and **the offload
split** (what HEARTH/mechnet does vs. what must be frontier or operator).

### The reusable harness (already built — do not rebuild)

- **ComfyNetworkSense** BepInEx mod (`network/mod/ComfyNetworkSense`) — the
  in-Valheim agent. Add one console command + one runner per slice, exactly as the
  priority-manifest work did. Auto-installs to the live plugins folder on build.
- **Lumberjacks Gateway** (`C:\work\Lumberjacks`) — the external authority. Rebuilt
  and running on :4000 (WS) / :4005 (UDP), with the priority-manifest + datagram
  endpoints and the UDP crash fix landed this session.
- **fieldlab** (`fieldlab/scenarios` + `command-plans` + `run-experiment.ps1`) —
  every slice produces a signed run packet with pass/fail gates. Reuse the pattern
  from `valheim-lumberjacks-priority-gateway-plan`.
- **Telemetry convention** — one `*.jsonl` per runner under
  `BepInEx/config/comfy-network-sense/`, mirrored to a fieldlab verifier.

---

## The invariant ladder

### I0 — Netcode map (pre-work for everything) — ✅ COMPLETE (2026-07-09)

**Status:** gate satisfied. Deliverable: `NETCODE-MAP.md` (all five funnels mapped with
verbatim signatures + citations from a decompile of `assembly_valheim.dll` @ 2026-07-01,
net protocol version 36). Key outcomes: (1) the inlining standing-risk is **bounded** — the
whole receive/handshake/routed-RPC handler layer is delegate-registered and inlining-proof,
so residual risk is only three send-side helpers; (2) the connection-handshake sequence the
feasibility research *refuted* is now re-derived end to end (version gate `num != 36`, full
error-code order); (3) native boundary confirmed clean — all managed funnels sit above
`ZSteamSocket`. Fleet-lane reachability (flagged unknown below) **resolved: fleet CAN reach
GitHub**. Next unblocked rungs: I1 (see `handoffs/HANDOFF-I1-INTERCEPTION-REACHABILITY.md`)
and I6.

- **Invariant:** we have an accurate, source-grounded map of Valheim's managed
  replication path: the exact classes/methods/fields for (a) the ZDO send funnel,
  (b) the ZDO receive/apply funnel, (c) ownership storage + the transfer trigger,
  (d) the `ZRoutedRpc` dispatch entry/exit, (e) the connection-handshake sequence.
- **Why it isolates:** pure reading. No game, no build. Produces a reference doc
  every later rung depends on.
- **Prerequisites:** none. This is the floor.
- **Probe + gate:** a `NETCODE-MAP.md` naming, for each of the five funnels above,
  the real method signature and the mod's intended hook point (prefix/postfix/
  transpiler), each backed by a source citation from one of: `dnSpy`/`ILSpy`
  decompile of `assembly_valheim.dll`, `tpill90/ValheimMods/Notes.md`,
  `ddormer/valheim-serverside` source, `CW_Jesse/BetterNetworking` source. Gate =
  all five funnels mapped with a citation; no "TODO/unknown" left in the send,
  receive, or ownership rows.
- **Offload split — heavily offloadable:**
  - **local_generate:** feed it pasted decompiled method bodies / source files in
    chunks; ask it to extract the method signature, the fields it touches, and
    whether the call bottoms out in a native/`extern` call (which Harmony can't
    reach). Pure text extraction — its sweet spot. Cold-start tax once, then fast.
  - **submit_task (fleet):** a self-contained "read these two public GitHub repos
    (valheim-serverside, BetterNetworking) and produce a structured summary of
    exactly how each one hooks ZDO ownership and the send queue" brief — *if* fleet
    workers have outbound internet. Verify that first (see Offload Strategy below);
    if not, fall back to local_generate over source I fetch and paste.
  - **frontier (me):** decide the final hook points and Harmony strategy per funnel
    — judgment over decompiled IL, not offloadable.
  - **operator:** none.

### I1 — Interception reachability — ✅ PASS (2026-07-09, connected session), one loose end

**Status (post-audit, 2026-07-09 evening):** the gate is **PASS** — cross-verified by the
ground-truth audit against run artifacts, session logs, live am4 state, and docker logs (see
`GROUND-TRUTH.md`, verdict 3). A real client↔am4-server session (14:46–14:47 UTC) produced
1,154 recv + 3,846 send ZDO rows, uid/owner legible on all 5,000 detail rows. Both funnels are
reachable and legible at runtime.

**⚠️ Caveat that survives the PASS:** the run used `autostop=0`, so **no counters row was ever
emitted** — every `*_calls` value and `parse_errors=0` in the summary is a verifier fallback
default, not a measurement. Therefore the "SendZDOs is JIT-inlined — settled" headline in the
I1 handoff is **unverified** (plausible, but the deciding counter never fired). Attaching later
rungs at `CreateSyncList` is safe regardless — that seam is proven. The airtight re-run
(finite `autostop`, real counters, which also genuinely settles inlining) is
**TEST-PROGRAM.md Phase P2**.

**Discovery (2026-07-09):** the first probe run captured a clean **zero** on all three
funnels — because it ran in a **singleplayer world**. In the decompile, `SendZDOs` is only
ever invoked as `SendZDOs(m_peers[m_nextSendPeer], …)` and `RPC_ZDOData` only fires on data
received *from a peer*; with an empty peer list all three funnels (incl. `CreateSyncList`,
called only from `SendZDOs`) are dormant no matter how much you move. **I1 requires a
connected session (client↔dedicated-server), not singleplayer.** This corrects the original
handoff's "load any world and move around" recipe.

**0.5.6 auto-start:** a `[Netcode]` config auto-start fires once
`ZNet.GetPeerConnections() > 0` (no local player needed, so it works headless on the dedicated
server too), runs a bounded window, and auto-stops with a counters row. ~~Next: run
`run-autonomous-valheim-lab.ps1`~~ **DEAD PATH — the OMEN Docker lab topology cannot work
(Docker Desktop publishes no UDP; containerized clients llvmpipe-crash). The live recipe is the
am4 + native-OMEN-client topology in `MULTIPLAYER-NETWORK-SETUP.md`.**

**Build:** probe built, compiled clean, and auto-installed (ComfyNetworkSense **0.5.6**).
Deliverables: command `network_sense_lumberjacks_netcode_probe [start|stop|status]
[max-detail-rows]`; runner `NetcodeProbeRunner.cs` with three auto-applied `ZDOMan`
postfixes — `RPC_ZDOData` (receive), `SendZDOs` (residual-inlining-risk send helper),
`CreateSyncList` (send-side fallback seam + per-ZDO detail); writes `netcode-probe.jsonl`;
verifier `fieldlab/scripts/verify-netcode-probe.ps1` + scenario
`valheim-lumberjacks-netcode-probe.yaml`. Observe-only: the receive side re-parses a *copy*
of the wire bytes (live read cursor untouched), the send side only reads already-selected
ZDO objects. **Next: operator runs the ~2-min in-game window; then read the verifier gate.**
Follow-up (deferred, not blocking): wire the scenario into `run-experiment.ps1`'s dispatcher
for a full signed packet — the standalone verifier already applies the gate.

- **Invariant:** a ComfyNetworkSense Harmony patch actually fires on the live ZDO
  send funnel and the receive funnel, and can read the ZDO payload passing through
  — *observe only, change nothing*.
- **Why it isolates:** proves the hook point from I0 is real and reachable at
  runtime, decoupled from any redirect/authority logic. If a target method is
  inlined (Harmony can't patch it — confirmed research finding), we discover it
  here, cheaply, before building anything on top.
- **Prerequisites:** I0.
- **Probe + gate:** a new command `network_sense_lumberjacks_netcode_probe
  [start|stop|status]` that counts ZDO sends and receives observed via the patch,
  writing `netcode-probe.jsonl`. Gate = nonzero observed sends AND receives during
  normal play, with the ZDO id/owner fields legible. Fieldlab verifier confirms the
  counts are plausible against a short play window.
- **Offload split:**
  - **local_generate:** draft the runner boilerplate + the fieldlab verifier
    scaffold (it drafted the priority observer well). I edit for correctness.
  - **frontier:** the Harmony patch itself + reading the ZDO struct.
  - **operator:** ~2 min in-game — load world, move around, run the command.

### I2 — Ownership seizure

- **Invariant:** we can force the owner field of a chosen ZDO (or all ZDOs in a
  zone) to a designated authority id and prevent Valheim from handing it back on
  the normal first-client-in-zone trigger.
- **Why it isolates:** ownership is a distinct concern from transport. Proving we
  can *hold* authority (even while traffic still flows over vanilla Steam sockets)
  is separable from proving we can *redirect* traffic. valheim-serverside targets
  exactly this; I0 should have mapped its mechanism.
- **Prerequisites:** I0, I1 (need the read hook to confirm the owner field before/
  after).
- **Probe + gate:** command extends the probe to set + re-assert ownership on a test
  ZDO; `netcode-probe.jsonl` logs owner before, after, and after the next natural
  transfer trigger. Gate = owner stays pinned across a trigger that would normally
  reassign it, with zero client crash and no save corruption on quit.
- **Offload split:**
  - **local_generate:** extract valheim-serverside's exact ownership-pin approach
    from its source (paste it in) into a step list I can adapt.
  - **frontier:** the actual patch + the safety reasoning (not corrupting save).
  - **operator:** in-game, drive a zone ownership-transfer scenario.
- **Status: ✅ PASS (2026-07-10, mod 0.5.10).** `OwnershipPinRunner` holds owner on
  both churn funnels via scoped Harmony prefixes on `ZDO.SetOwner` (release scope) +
  `ZDO.SetOwnerInternal` (RPC scope). Authoritative gate window: 25 ZDOs pinned, 55
  holds (34 `SetOwner` + 21 `SetOwnerInternal`), 262 pass-through transfers on unpinned
  ZDOs as the live negative control, save-integrity PASS with the pin engaged. The
  mechanism was grounded directly on the decompiled assembly (not the summary doc),
  which surfaced two corrections: the `RPC_ZDOData:842-844` revision-race hole (so we
  guard `SetOwnerInternal` directly) and that ZDO ownership is runtime-only (so the pin
  is inherently save-safe). Evidence: `evidence/i2-pin/` (sha256 `ebeefeb6`). Retro:
  `retro/SESSION-RETRO-2026-07-10.md`. ADRs 0001, 0002.
- **Repeatability hardened (2026-07-10 evening, window A of the P4 gate session):** a 2nd
  fully authoritative window on a fresh join — 25 pinned, **232 holds** (222 SetOwner +
  10 SetOwnerInternal), **280 pass-through** as the live negative control, clean 150s
  auto-stop (no idle-restart clipping; join timed to a fresh updater cycle), save-integrity
  exact across the post-window save→reload. Ran on 0.5.11 with the pin code carried
  unchanged (mechanism-across-builds; recorded honestly in `evidence/i2-repeat/ANALYSIS.md`,
  sha256 `b375d9ec`). P3's one soft spot is closed.

### I3 — Outbound redirect

- **Invariant:** we can suppress the native outbound send for a class of ZDO/RPC
  traffic and emit the equivalent to Lumberjacks instead, without the client
  erroring.
- **Why it isolates:** one direction only. The client can tolerate "sent nowhere
  useful" far better than "received garbage," so outbound is the safer half to prove
  first. No inbound injection yet.
- **Prerequisites:** I0, I1. (I2 not strictly required — redirect is separable from
  ownership.)
- **Probe + gate:** the send patch drops the native send for tagged ZDOs and posts
  them to a Lumberjacks endpoint; verifier confirms Lumberjacks received them AND
  the client logged no `INVALID_MESSAGE`/socket errors during the window. Gate =
  Lumberjacks receipt count matches suppressed-send count, client stable.
- **Offload split:**
  - **local_generate:** draft the Lumberjacks-side receive endpoint handler + the
    serialization shim (ZPackage → JSON) as boilerplate.
  - **frontier:** the suppression patch (must not break the send loop's state) +
    the Gateway endpoint contract.
  - **operator:** in-game window.
- **Design (2026-07-10, recorded before code — target mod 0.5.11):** grounded on a fresh
  decompile of `ZDOMan`/`ZDO` (l-0.221.12), not the map.
  - **Seam:** Harmony **Postfix on `ZDOMan.CreateSyncList`** (server-side, `IsServer`-guarded),
    not a prefix on `SendZDOs` — `toSync` is populated *inside* `CreateSyncList` (ZDOMan:893),
    so only a postfix can filter it before the serialization loop (ZDOMan:761-784) writes and
    dispatches via `Invoke("ZDOData")` (ZDOMan:787). Same "one funnel, one flag" scoping that
    kept the pin surgical.
  - **Suppress-with-ack:** each tagged ZDO removed from `toSync` gets the native bookkeeping
    replicated — `peer.m_forceSend.Remove(uid)` + `peer.m_zdos[uid] = PeerZDOInfo(DataRevision,
    OwnerRevision, now)` (mirroring ZDOMan:767/780) — so native re-offers it only on revision
    change. Without the ack, `ShouldSend` re-selects every tick (duplicate storm, broken gate
    math); with it, suppressed-count equals exactly what native would have sent.
    *Implementation risk:* `ZDOPeer.m_zdos`/`PeerZDOInfo` are non-public — AccessTools/reflection;
    verify at build.
  - **Tag scheme:** config prefab-hash allowlist, single test prefab first; `redirectEnabled`
    off by default; windowed auto-stop (probe-style) + stop command = the instant rollback.
  - **Payload scope:** wire-equivalent envelope — `{seq (per-window monotonic), uid, owner,
    owner_rev, data_rev, prefab, pos, body_b64 = base64(zdo.Serialize bytes)}` — **not** a full
    ZPackage→JSON decomposition. The I3 gate needs equivalence + count math, not legibility;
    the rebuild problem belongs to I4. Batched POSTs (bounded queue, retries) to the Lumberjacks
    gateway `POST /valheim/zdo-redirect/receipts`; every suppression also appends to a local
    `redirect-send.jsonl` (the mod-side count of record).
  - **Observe-during-change (ADR 0002):** the netcode probe's existing `CreateSyncList` postfix
    stays on; the redirect postfix runs at `HarmonyPriority.High` so the probe logs the
    *post-filter* list. Three independent measures in one window: mod suppressed rows ==
    gateway receipts (seq-gap loss detection) AND probe rows show zero tagged native sends.
    Postfix order is load-bearing (cf. the I2 multi-prefix lesson).
  - **Save-safety:** decompile-verified — the send path writes no persisted ZDO state (only
    runtime peer bookkeeping: `peer.m_zdos`, `m_forceSend`, `m_clientChangeQueue`, `m_zdosSent`;
    `ZDO.Serialize` only reads `ZDOExtraData`; the world save is the separate
    `PrepareSave`/`SaveAsync` clone path). The redirect adds no ZDO writes → inherits the pin's
    save-safety class. Save-integrity gate still runs regardless.
  - **Network path (proven 2026-07-10):** am4 server *container* → tailnet → OMEN `:4000`
    `/health` answers; the gateway must bind `0.0.0.0:4000` (launch flag — `appsettings.json`
    default is localhost-only).
  - **Client-stability read:** the client is untouched (server-side suppression only); it just
    receives fewer ZDOs — a normal play condition. Gate reads OMEN logs via MCP for
    `INVALID_MESSAGE`/socket errors.

### I4 — Inbound injection

- **Invariant:** authoritative state pushed from Lumberjacks can be injected into
  the client's ZDOMan such that the client renders it, without going through a real
  Steam peer.
- **Why it isolates:** the mirror image of I3, and the higher-risk half — malformed
  injected state can desync or crash. Proving it alone (with outbound still vanilla)
  contains the blast radius. Note: the earlier projection spike rendered *proxy
  primitives*; this is different — it injects into the real ZDO system so real game
  objects appear.
- **Prerequisites:** I0, I1, and ideally I3 (shared serialization shim).
- **Probe + gate:** Lumberjacks pushes a known synthetic ZDO (e.g. a single dropped
  item at a coordinate); command applies it via the mapped receive/apply funnel.
  Gate = the object appears in-world and persists a few seconds; no crash; owner
  reads as the Lumberjacks authority id.
- **Offload split:**
  - **local_generate:** draft the JSON → ZPackage rebuild boilerplate.
  - **frontier:** the apply-path patch + malformed-input hardening (highest-judgment
    rung so far).
  - **operator:** in-game confirmation the object renders.

### I5 — Handshake satisfaction

- **Invariant:** the Valheim client can complete a connection whose peer is
  Lumberjacks (or a Lumberjacks-fronted shim) — version/password/etc. checks
  satisfied — instead of a vanilla Valheim host.
- **Why it isolates:** the connection gate is orthogonal to steady-state
  replication. The research confirmed the gate exists (version/password/ban/
  whitelist/count/dup) but *refuted* the exact method sequence — so I0 must
  re-derive the sequence from source, and this rung is where it's proven end to end.
- **Prerequisites:** I0 (handshake sequence re-derived), and realistically I3+I4
  (a peer you connect to must be able to exchange state).
- **Probe + gate:** client initiates a connection that Lumberjacks answers; verifier
  confirms the client reaches the in-world state (past character/spawn) against the
  Lumberjacks-fronted peer. Gate = client spawns and stays connected ≥30s.
- **Offload split:**
  - **local_generate:** extract the handshake RPC exchange (`RPC_ServerHandshake` /
    `RPC_PeerInfo` etc.) field-by-field from decompiled source into a checklist.
  - **frontier:** the Gateway-side handshake responder — protocol-critical, mostly
    not offloadable.
  - **operator:** in-game connect attempt.

### I6 — Single-transport constraint (low risk, do early)

- **Invariant:** we can force Steam-only (crossplay/PlayFab disabled) so the swap
  handles one backend, not two.
- **Why it isolates:** trivially separable and confirmed feasible — BetterNetworking
  ships a crossplay toggle. Lands early to shrink every later rung's surface.
- **Prerequisites:** I0.
- **Probe + gate:** command asserts crossplay off; verifier confirms only the Steam
  socket path is active (no PlayFab relay). Gate = binary.
- **Offload split:** almost entirely **local_generate** (extract BetterNetworking's
  toggle) + a small frontier patch. No operator step beyond a restart.

### I7 — Single-client loopback integrity (the integration gate)

- **Invariant:** with I2 (ownership) + I3 (outbound) + I4 (inbound) + I5 (handshake)
  all active at once, one client stays in-world, renders authoritative state from
  Lumberjacks, and quits without save corruption.
- **Why it's last:** it is the only rung that deliberately does *not* isolate — it
  composes the proven pieces. Everything before exists to make this rung's failures
  legible.
- **Prerequisites:** I2, I3, I4, I5, I6.
- **Probe + gate:** a full fieldlab packet: client connects to Lumberjacks, moves,
  interacts with one Lumberjacks-authoritative object, quits. Gate = no desync
  errors, no crash, world file intact on reload. This is the "proof of concept swap"
  milestone — not multiplayer, not performance, just *one client fully on
  Lumberjacks*.
- **Offload split:** integration reasoning is **frontier**; the packet scaffold is
  offloadable; verification is **operator** + me.

Beyond I7 (explicitly out of scope for this program, noted so they aren't
forgotten): multi-client, performance under Era16 density, the two-backend problem
if I6 proves insufficient, and the legal/anti-cheat posture for redistribution
(unresolved by the research — needs a dedicated check before any public release).

---

## Offload strategy — honest split

Derek's goal is to task out as much as possible to HEARTH/mechnet. Here is the
realistic ceiling, stated plainly rather than oversold.

**Genuinely offloadable to `local_generate` (self-contained text, no repo access
needed — pass everything in the prompt):**
- I0 source extraction: signatures, field lists, native-vs-managed classification.
- Per-slice runner + verifier *boilerplate* drafts (proven to work this session).
- Serialization-shim boilerplate (ZPackage↔JSON) for I3/I4.
- Extracting the exact approach of valheim-serverside / BetterNetworking / the
  handshake RPCs from pasted source into step lists.

**Conditionally offloadable to `submit_task` (fleet):** research-style briefs like
"summarize how these two public repos seize ZDO ownership." **Blocker to verify
first:** fleet workers have read-only `~/commandcenter-src` only — **not** the
`comfy` or `Lumberjacks` repos — and their internet access is unconfirmed. So they
cannot touch the mod or Gateway directly, and may not be able to fetch GitHub. Test
one small brief before relying on this lane; if it can't reach the source, this lane
collapses into "I fetch + paste to local_generate."

**Inherently frontier (me), not offloadable:** every Harmony patch decision over
decompiled IL, the Gateway protocol/handshake responder, malformed-input hardening
on the inject path, and all integration reasoning. This is the judgment core and
it's most of the *hard* work.

**Inherently operator (Derek):** every in-game verification. Each rung needs a live
Valheim session to fire its probe; that cannot be delegated. Cadence mirrors this
session: I build + install the DLL, Derek runs one console command, I read the
telemetry and gate it.

**Deep-research fan-out (the Workflow harness, distinct from HEARTH):** best reserved
for genuinely open external questions (e.g. "has anyone published a Valheim ZDO
injection technique") — not for reading source we already have, which is cheaper via
local_generate.

**Net:** the *reading/extraction/drafting* tier (a real fraction of total effort,
and the tedious part) offloads well to local_generate. The *patching/protocol/
integration* tier stays frontier. The *verification* tier stays operator. No amount
of mechnet removes the operator-in-the-loop or the frontier-judgment core — but the
grunt tier is exactly what should never burn frontier tokens, and this program routes
it accordingly.

---

## Sequencing

```
I0 (map) ──┬─> I1 (observe) ──┬─> I2 (own)  ─────┐
           │                  ├─> I3 (out)  ──┐  │
           │                  └─> I4 (in) ────┤  │
           ├─> I6 (steam-only, early)         │  │
           └─────────────> I5 (handshake) ◄───┘  │
                                                  │
   I2 + I3 + I4 + I5 + I6 ─────> I7 (loopback integrity)
```

I0 first and hard. I6 is a cheap early win. I1 unlocks the observe hooks everything
needs. I2/I3/I4 are parallelizable once I1 lands (independent invariants). I5 needs
the state-exchange pieces. I7 composes.

## Standing risks & kill-criteria

- **Inlining (bounded by I0):** the receive/handshake/routed-RPC handler layer is
  delegate-registered (`ZRpc.Register`/`ZRoutedRpc.Register`) and therefore inlining-proof —
  the JIT cannot inline a delegate target. Residual risk is confined to three send-side
  helpers (`SendZDOs`, `CreateSyncList`, `RouteRPC`), all large/multi-callsite (low). I1
  tests `SendZDOs` directly. Workaround before declaring dead: postfix `CreateSyncList`, a
  transpiler patch, or hook a caller one frame up. Only "dead" if *no* reachable seam exists.
- **Native boundary (confirmed):** Harmony can't touch the native Steamworks send.
  The whole strategy assumes interception at the *managed* `ZSteamSocket` wrapper
  above it. If traffic can bypass that wrapper, I3/I4 need rethinking — flag at I0.
- **Save corruption:** any rung that writes ZDO state (I2/I4/I7) must prove clean
  quit-and-reload before it counts as passed. Non-negotiable gate.
- **Legal/ToS:** unresolved. Not a technical blocker to *proving feasibility
  locally*, but a hard gate before anything ships publicly. Do not skip before
  release.
