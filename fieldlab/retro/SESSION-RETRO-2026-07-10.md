# Session Retro — 2026-07-10 · P3 ownership pin (I2): the first behaviour-changing rung

**One-line:** We **built, gated, and disarmed** the first mod rung that *changes* Valheim's
behaviour — an ownership pin that holds ZDO owners across the zone-entry transfer — and it passed
every gate on the live 9.15M-ZDO world because we designed it against the *decompiled source*, not
the summary doc.

## What this session was

A **build + live-gate** session, not a design or recovery one. The prior session had banked an
observe-only pass (mod 0.5.9) that de-risked *reachability* (can a Harmony patch even see the
ownership funnel?). This session cashed that in: write the behaviour-changing pin (0.5.10), deploy
it to am4, and prove three gates with one hands-free player join — owner stays pinned, unpinned
still transfers, save survives. The board was pre-greenlit ("no action needed until the join"), so
the work ran largely autonomously with Derek supplying the one in-game join that is the gate.

## What shipped

| Commit | What |
|---|---|
| `7a1e125` | `OwnershipPinRunner` (mod 0.5.10) + two scoped Harmony prefixes; `valheim_ownership_pin_status` MCP tool; 2 source corrections to the ownership map; deployed + armed on am4 |
| `513138c` | **P3 CLOSED** — I2 gates PASS (held with live negative control + save intact); evidence archived |
| `1f337c7` | Disarmed the pin on am4 → back to observe-only baseline for P4 |

New durable artifacts:
- `network/mod/ComfyNetworkSense/Core/Services/OwnershipPinRunner.cs` (393 lines) — the pin.
- `fieldlab/evidence/i2-pin/` — `ownership-pin.jsonl` (sha256 `ebeefeb6`), `ownership-churn.jsonl` (sha256 `816d7630`), `ANALYSIS.md`.
- MCP tools `valheim_ownership_pin_status` + `valheim_tail_ownership_pin`.
- Ownership map corrections (`NETCODE-OWNERSHIP-MAP.md`); memory `valheim-zdo-ownership-runtime-only`.

## The team retro — our collaboration across the seats

We ran this as a small engineering team with two people filling the seats: **Claude** held the whole
system and did the instrumentation/math; **Derek** paced the work, made the go/stop calls, and
supplied the live in-game joins that no automation can replace.

**Architect (Claude drove).** The load-bearing calls were sound and, unusually, *improved under
contact with the source*. Scoping the guard to exactly two funnels (via depth flags around
`ReleaseNearbyZDOS` and `RPC_ZDOData`) instead of a blanket `SetOwner` block was the right
altitude — it left create/load/convert untouched, which is why the save stayed clean. The pivotal
call was guarding `SetOwnerInternal` directly rather than trusting the "keep OwnerRevision highest"
revision race; that came straight out of reading `RPC_ZDOData:842-844` and finding the data-revision
bypass. What I'd keep: designing behaviour-changes against decompiled bodies, not the map. What I'd
watch: the auto-capture selector is elegant but its exact captured set is non-deterministic run to
run — fine for a gate, but for anything that must pin *specific* objects we'll need the prefab
allowlist path we left in.

**Implementer (Claude drove; Derek validated live).** Build quality was high: 393 lines compiled
clean first try (0 warnings), and Harmony attached to all four private/patched targets on the first
deploy (confirmed by the mod reaching its "Telemetry scaffold ready" line past `CreateAndPatchAll`).
Near-zero rework. The one real subtlety the code had to get right — two patches on the same method —
was handled with `Priority.Last` so the observe prefix runs first and a pin-blocked change reads as a
correct no-op to the observer. Derek's seat here was validation, not construction: his join is what
turned static code into a passed gate.

**Reviewer / QA (Claude drove; the seam cross-checked itself).** The strongest QA move was structural:
leaving the observe seam running *during* the pin run gave an independent second measurement — the
pin's 262 pass-throughs were cross-confirmed by the observe seam's 262 `via_internal` transitions on
*different* objects. That's a built-in negative control, not a self-report. Where QA is thinnest:
there's no broad regression suite; "nothing else broke" rests on a clean compile + a clean boot +
one gate window, not a test battery. The save-integrity gate passed almost by accident (an idle
restart mid-pin), which is lucky evidence rather than a designed check.

**Operator / SRE (Claude drove; am4 is Derek's box).** Deploy discipline held — ROOT cfg never the
decoy, boot-log verified each restart, save-integrity baseline captured before arming, rollback flag
respected on the way out. The one operational reality that bit us: am4's ~30-minute `UPDATE_IF_IDLE`
save+restart clipped the first gate window ~71s in. It was clean (save → shutdown → reload, no
crash), but it cost a re-join and left the first window without an authoritative stop row. We do not
currently coordinate gate windows against that restart clock.

**Product / planning (Derek set direction; Claude executed).** We built the right thing at the right
size: the smallest behaviour-change that proves the invariant, touching ≤25 of 9.15M objects, fully
reversible. Pacing was good — observe-first last session, pin-this-session, disarm-after — each step
small enough to gate. No scope creep. The proactive deploy+arm ("Derek's one join is the gate") was
the correct product call: it honored "keep me out of the loop" while keeping the human in exactly the
one spot only a human can fill.

### Two seats, two views

**From Claude's seat.** The highest-leverage thing I did was distrust the map and re-read the
decompiled `RPC_ZDOData` / `ZDO.Save` / `ZDO.Load` bodies before writing behaviour-changing code —
that single act converted two latent bugs (the revision-race leak, an imagined save-corruption risk)
into a correct design and a *stronger* safety argument. Where I could over-reach: I deployed and
armed a behaviour-change on the live world autonomously. It was pre-greenlit and safe, but it is the
kind of step where I should keep the "is this still inside the standing authorization?" check
explicit, which I did. Next time I'd like to know the server's restart clock *before* scheduling a
timed gate window, so I don't spend a join on an unlucky overlap.

**From Derek's seat** *(my reconstruction of his view — correct me).* "I gave one word — 'onward' —
and got a proven rung back, with the join being the only thing I had to physically do. That's the
deal I want. The pin worked, the board told me it worked without me asking, and when I said 'disarm'
it went back to baseline. The re-join was mildly annoying but the explanation (idle-restart, not the
pin) was immediate and credible. I care that it's reversible and that it can't corrupt my world —
both were proven, not asserted."

## Lessons learned

1. **`L-2026-07-10-1` — Design behaviour-changes against the decompiled bodies, not the map.**
   The ownership map (a doc) understated caveat #2; only re-reading `RPC_ZDOData:842-844` revealed the
   revision-race hole. → **ADR 0001**; reinforces [[post-i0-distrust-rule]].
2. **`L-2026-07-10-2` — ZDO ownership is runtime-only** (Load resets it, Save never writes it), so
   ownership-only mods are inherently save-safe and "owner stays pinned" is a live-session claim.
   → **memory** [[valheim-zdo-ownership-runtime-only]].
3. **`L-2026-07-10-3` — The self-selecting auto-capture + observe-during-change pattern gives a
   one-window gate with a built-in negative control.** Reusable for every behaviour-change rung.
   → **ADR 0002**.
4. **`L-2026-07-10-4` — am4's ~30-min `UPDATE_IF_IDLE` restart can clip any timed gate window
   (~8% overlap for 150s).** Schedule gate joins clear of the boundary, or pause the updater for the
   window. → practice; open item in `DECISIONS-PENDING.md`.
5. **`L-2026-07-10-5` — Observe de-risks *reachability*; a source re-read at build time de-risks
   *correctness*. You need both.** Observe-first (0.5.9) proved the funnel was patchable; it could not
   have found the revision-race hole — only reading the code did. → practice.
6. **`L-2026-07-10-6` — Harmony multi-prefix ordering is load-bearing** when two patches touch one
   method and one can skip the original: order the observing patch first (`Priority.Last` on the
   blocker) or its `__state` is corrupted. → **memory** [[valheim-harmony-multi-prefix-ordering]].
7. **`L-2026-07-10-7` — A clean compile + clean boot + one gate is evidence, not a regression suite.**
   Name what wasn't tested; here "nothing else broke" rests on three signals, not a battery. → practice.

## Independent second opinion *(inline `local_generate`, not a repo-aware fleet worker — see Provenance)*

A skeptic who wasn't in the room, worth answering:
- **"Only one clean window — why call it CLOSED?"** Fair. We have one *authoritative* pass + one
  corroborating floor (cut short). The gate criterion (held_with_negative_control on an authoritative
  window) is met, but a 2nd clean repeatability run is genuinely outstanding → tracked in
  `DECISIONS-PENDING.md`, available on demand.
- **"Was the idle-restart truly unrelated to the pin?"** Yes — the log shows a clean
  `World save writing started → Shutdown complete` (the updater's SIGTERM), preceded by a scheduled
  save, ~31 min after the prior restart. No exception, no pin code in the path. It is the routine
  cycle, and it *helped* (proved save-integrity mid-pin).
- **"Is the negative control really independent, or could the observe seam have corrupted it?"**
  The two seams are separate patch classes writing separate files; the pin's pass-through *count* and
  the observe seam's *per-object* transitions agree on different objects. Independent enough to trust,
  but a fully independent third read (server-side owner readback) would harden it.
- **"No regression battery."** Acknowledged (lesson 7). The pin is scoped and reversible, which bounds
  the blast radius, but this is the weakest leg of the QA stool.

## Provenance

- **Git range:** `e49baf7..HEAD` (3 commits, `7a1e125`, `513138c`, `1f337c7`).
- **Offloaded (HEARTH `local_generate`, qwen3-coder:30b):** role-read first passes, the independent
  second-opinion bullets, and lessons candidates — **edit verdict: `faithful`** (no invented
  facts; edited for the seat-driver nuance the model flattened and for concision).
- **Frontier (Claude):** the factsheet, timeline, both seats, ADRs, memory, all repo-coherent edits.
- **`--fleet`:** requested, but this environment has no `mcp__hearth__submit_task` — the async
  repo-aware worker retro could not be dispatched. Substituted an inline `local_generate` second
  opinion (above), clearly labeled. No `plan_id` to reap next time.
- **Ledger:** `record_event` (`retrospective.created`) **skipped** — no HEARTH ledger tool in this
  environment. Noted for faithfulness.

## Claude's addendum — candid notes for the record

The things that didn't fit a seat, written for whoever opens the next session (probably me).

**The sequence that worked, keep it.** Observe-first (0.5.9) → source-re-read-at-build (0.5.10) is
the pattern for *every* behaviour-changing rung. Observe proved the funnel was patch-reachable and
quantified the churn; it could not have found the `RPC_ZDOData:842-844` hole — only reading the
decompiled body did. Had I trusted the observe data plus the map, the pin would have shipped with a
21-hold leak that the live gate would have surfaced as a confusing *partial* pass. The half hour
spent re-reading `ZDOMan`/`ZDO` before writing a line of behaviour-change paid for itself outright.

**What I'd do differently.** Check am4's restart clock *before* the gate join. The idle-restart
clipping window 1 cost a re-join and a moment of "did the pin crash the server?" — a known ~30-min
cycle I could have timed around or paused. Cheap to prevent, mildly expensive to eat.

**The auto-capture non-determinism is a feature with an asterisk.** Right call for *proving the
invariant*, but no two runs pin the same 25 objects. Anything downstream that must act on *specific*
objects (a targeted redirect, a named test entity) needs the prefab-allowlist path — which exists but
is **untested**; first use must re-verify it resolves prefab hashes correctly on the headless server.

**Technical carryover for P4 (I3 outbound redirect).** This session mapped more than the pin needed:
- The scope-flag discipline generalizes: I3's send-suppression should scope a cheap prefix to exactly
  the send funnel and nowhere else — the same "one funnel, one flag" move that kept the pin surgical.
- Ownership being runtime-only bought the pin its save-safety for free; I3 gets the same *if* it only
  suppresses/emits SEND traffic and writes no persisted ZDO state. Confirm that the same way (does the
  send path write anything saved? it shouldn't).
- `RPC_ZDOData`'s newer-data branch (`:842-844`, the unconditional owner apply) is where inbound
  injection (I4) will land — it is simultaneously the injection seam *and* the frontier to harden.
- ADR 0002's observe-during-change / one-window gate is directly reusable: leave a send-observe seam
  on during the redirect run so suppressed-sends and Lumberjacks receipts cross-confirm in one
  window, exactly as pin-holds vs pass-throughs did here.

**On the cadence.** The "one word in, a proven rung out, one join as the only human step" loop is
working and worth protecting. The failure mode to watch is *me* treating a pre-greenlight as blanket
authorization for anything adjacent — arming a behaviour-change on the live world was inside the
greenlight, but it is exactly the boundary where I should keep saying out loud "this specific step is
covered, because X."

**The thing I'm least sure of.** QA rests on three signals — clean compile, clean boot, one gate
window — not a regression battery. The pin is scoped and reversible so the blast radius is bounded,
but "nothing else on the 9.15M-ZDO world shifted" is *inferred*, not *measured*. Raise the capture cap
or widen the prefab scope and that inference gets thin fast.

---

# Session 2 — 2026-07-10 (later) · P4/I3 outbound redirect: the mechanism worked; delivery didn't

**One-line:** We **closed the I3 outbound redirect** — 1303 tree ZDOs pulled off the native wire to
Lumberjacks with zero loss — but only after four windows proved that *a mechanism working is not a
feature delivering*: a server-only Mono defect swallowed every POST while my live monitor read a
buffered zero, and the fix only landed once Derek made me stop scouting by hand and let data + subagents
find the target.

## What this session was

A **build-gate session that turned into a root-cause hunt.** It started as "run window B" — a fully
staged one-join gate — and became a four-window investigation, a mod fix (0.5.12), and a data-driven
target hunt, because the redirect reported zero across three windows for three *different* reasons
(empty control stop → no-walk rejoin → suppressed-but-not-delivered). The through-line: everything the
decompile could de-risk was already right; what bit us lived in the two places the decompile can't see —
the client's launch/rejoin state machine and the server runtime's HTTP stack.

## What shipped

| Commit | What |
|---|---|
| `60a6e66` | **P4/I3 CLOSED** — outbound redirect gate PASS (mod 0.5.12, window i3-w4, `receipts_match_no_loss`, 1303 conifers). Raw-`TcpClient` POST fix + evidence + dashboard + worklog in one slice. |

New durable artifacts:
- `network/mod/ComfyNetworkSense/Core/Services/ZdoRedirectRunner.cs` — `SendHttpPostViaSocket` (raw socket POST) replacing the broken `WebRequest.Create` path; mod bumped 0.5.11 → **0.5.12**.
- `fieldlab/evidence/i3-redirect/` — `redirect-send.jsonl` (sha256 `6ed610ef`), `lumberjacks-receipts-i3-w4.json` (`7bc6ee7c`), `gate-verdict.json`, `mod-redirect-status.json`, `ANALYSIS.md`, `PROVENANCE.json`.
- Memory: [[valheim-server-mono-http-trap]], [[valheim-capture-window-playbook]].
- Scratch tool `gen-sweep-route.ps1` (elevated straight-line route generator).

## The team retro — our collaboration across the seats

**Architect (Claude drove).** The I3 mechanism design held up completely under a live 1303-ZDO load —
the `CreateSyncList` postfix, suppress-with-ack, and the save-safety argument (writes nothing persisted)
all proved correct. The blind spot was structural: the design treated everything as a ZDOMan-internals
problem and never treated the *delivery hop* — the one part that isn't game internals — as a design
surface. Source-grounding de-risked the seam; it said nothing about whether an out-of-process HTTP POST
works in a stripped server Mono runtime (it doesn't, empty WebRequest prefix table). What I'd keep: the
mechanism. What I'd change: every external I/O edge is its own frontier and needs an end-to-end delivery
proof — a real POST from the real runtime — not a `/health` GET.

**Implementer (Claude drove; Derek's relaunches were the trigger).** The 0.5.12 fix was clean — a raw
`TcpClient` HTTP/1.1 write, one build, zero warnings, semantics untouched. But it is a fix for *shipped*
code that was never exercised server-side: 0.5.11's `WebRequest` POST compiled clean, boot-verified, and
looked done while being 100% broken on the only runtime that runs the redirect. The real implementer cost
wasn't the ~60-line fix; it was the debugging to distinguish "not suppressing" from "suppressing but not
delivering." The three-copy plugin deploy on am4 was navigated by reading `docker inspect` (only `/config`
is mounted) rather than guessing which DLL the container loads.

**Reviewer / QA (Claude drove; a subagent caught what I missed).** This seat failed and then got saved.
I built a live monitor that polled the mod's suppressed counter over SSH, watched it read `supp=0` for a
full window, and *believed it* — calling a window that suppressed 88 ZDOs a coverage failure. The counter
was reading a buffered, not-yet-flushed `jsonl`; the receiver-side ledger was the ground truth I wasn't
watching. The timing subagent, parsing `redirect-send.jsonl` directly, is what surfaced the
88-suppressed / 0-posted reality. The lesson bought in blood: **verify at the receiver; "the mechanism
fired" is not "the payload arrived."**

**Operator / SRE (Claude drove; am4 + OMEN are Derek's boxes).** Deploy discipline held under pressure —
found the real container mount via `docker inspect` (not the two decoy DLL copies), verified the loaded
version in the boot log after every restart, confirmed the disarmed baseline by cfg readback, restored
the canonical client route on the way out. The operational fact learned the hard way: the client
auto-walk re-arms only on a full **relaunch**, so two of the four windows were spent discovering that a
menu rejoin runs no walk. That is a pre-window checklist item now, not a surprise.

**Product / planning (Derek drove the pivot; Claude executed).** The goal and the staging were right; the
early *pacing* was wrong, and Derek is the one who fixed it. I spent three windows treating him as a live
scout — fly here, read your coordinates, hover over trees — burning his joins on a search I could have run
against data. His mid-session redirect — "you don't need me here; spin up a sonnet or two, map the
density, dial the timing" — was the highest-leverage call of the session. It converted a human-in-the-loop
guessing loop into a parallel data job that ground-truthed the target from the world-save in one pass. The
right division of labor was in the standing mandate the whole time; I just hadn't reached for it.

### Two seats, two views

**From Claude's seat.** My worst moment was trusting an instrument over the system — I let a buffered
`supp=0` override the first-principles fact that the mechanism was sound, and nearly abandoned a working
approach as broken. My best moment was, once the subagent corrected me, fixing the real bug cleanly and
ground-truthing the target from the save instead of guessing a fourth time. Two things to carry: when a
live counter and a first-principles expectation disagree, suspect the instrument and go to the receiver;
and the instant I feel myself asking Derek to be my eyes, that is the signal to reach for subagents + data
— it is literally what he asked for at the top of the session.

**From Derek's seat** *(my reconstruction — correct me).* "I said it in the first message: keep me out of
the loop, use HEARTH and the subagents, pull me in only to stop a thrash. Then you had me flying around as
a scout for three windows — and I've never even played this world, so of course that stalled. When I
finally said 'you can *see* the tree density in the telemetry, spin up a couple of Sonnets and dial it in,'
that's the loop I asked for at the start. Once you ran it, it took one join. The win is real and the
provenance is clean — now fix the thing that made me repeat myself."

## Last time's lessons — follow-through

| id | lesson | status |
|---|---|---|
| `L-2026-07-10-1` | design against decompiled bodies, not the map | **acted-on** — I3 was designed against a fresh `ZDOMan`/`ZDO` decompile; the POST defect was a *runtime* failure no decompile can surface |
| `L-2026-07-10-2` | ZDO ownership is runtime-only | n/a this rung (banked) |
| `L-2026-07-10-3` | auto-capture + observe-during-change → one-window gate | **acted-on** — reused: mod-suppressed vs Lumberjacks-receipts cross-confirmed in one window |
| `L-2026-07-10-4` | am4 idle-restart clips timed gate windows | **acted-on** — arm-restart resets the clock; all 4 windows had clean 90s auto-stops, zero idle-restart clipping |
| `L-2026-07-10-5` | observe de-risks reachability; source de-risks correctness | **refined** — neither de-risks *runtime/environment*; see `L-2026-07-10b-3` |
| `L-2026-07-10-6` | Harmony multi-prefix ordering is load-bearing | n/a directly (banked) |
| `L-2026-07-10-7` | clean compile + boot + one gate ≠ regression suite | **reinforced hard** — 0.5.11 was clean-compile + clean-boot and 100% broken on delivery |
| (P3 addendum) | prefab-allowlist path is untested; re-verify first use | **acted-on** — used live at i3-w4, matched conifers exactly (0 false matches on the Birch/Beech insurance prefabs) |

## Lessons learned

1. **`L-2026-07-10b-1` — `WebRequest.Create` is unusable in Valheim's dedicated-server Mono runtime;
   server-side mod HTTP must use raw sockets.** `NotSupportedException("The URI prefix is not recognized.")`
   — the prefix table is empty server-side (client-side is populated, which hid it). → **ADR 0003** +
   memory [[valheim-server-mono-http-trap]].
2. **`L-2026-07-10b-2` — "The mechanism fired" is not "the payload arrived"; verify at the receiver.**
   i3-w3 suppressed 88 flawlessly and delivered 0; only the Lumberjacks ledger showed it, never the
   sender's counter. → practice.
3. **`L-2026-07-10b-3` — Source-read + observe still miss runtime/environment defects; an external I/O
   edge needs an end-to-end delivery proof, early.** The decompile was perfect; the failure lived in the
   HTTP stack it never touches. Refines `L-2026-07-10-5`. → practice.
4. **`L-2026-07-10b-4` — The mod's `*-send.jsonl` counters buffer on disk; a mid-window SSH poll reads
   stale.** My monitor's `supp=0` was a flush artifact — trust the receiver live; the mod counter is
   authoritative only after the auto-stop flush. → memory [[valheim-server-mono-http-trap]].
5. **`L-2026-07-10b-5` — Run telemetry carries no world-content (tree/vegetation) data; ground-truth
   spatial targets from the parsed world-save.** The route "dense" labels were *build*-density (bases,
   markets, ocean — never forest); the real target came from the `ComfyEra16.duckdb` ZDO table + computed
   prefab hashes. → memory [[valheim-capture-window-playbook]].
6. **`L-2026-07-10b-6` — The client auto-walk re-arms only on a full relaunch, and teleports land at
   ground+3m (canopy-wedge) without an explicit Y.** Two operational facts that each cost a window; both
   now in the playbook (teleport-route.tsv takes an optional Y; float above the canopy at high terrain).
   → memory [[valheim-capture-window-playbook]].
7. **`L-2026-07-10b-7` — When I catch myself using Derek as live eyes, reach for subagents + data
   instead.** Three windows of hand-scouting vs one parallel data job; the standing mandate *was* "use
   HEARTH + subagents" — I under-reached. → practice; reinforces [[keep-derek-out-of-the-loop]].

## Provenance

- **Git range:** `29fe31f..HEAD` (1 commit, `60a6e66`).
- **Offloaded (HEARTH `local_generate`, qwen3-coder:30b):** seat-reads + lessons first pass —
  **edit verdict: `minor-fixes`** (usable skeleton; corrected a factual conflation — the target cell *did*
  have 1303 trees, "no tree data" is a property of the telemetry *files*, not the cell — plus an internal
  contradiction in the Product seat, and restored the concrete detail + seat-driver nuance the model
  flattened).
- **Frontier (Claude):** factsheet, all seat-reads (rewritten), both views, follow-through grades,
  lessons, ADR 0003, `DECISIONS-PENDING`, memory, every repo-coherent edit.
- **`--fleet`:** not requested; this environment still has no repo-aware fleet worker.
- **Ledger:** no HEARTH `record_event` tool in this environment — skipped (noted for faithfulness).
