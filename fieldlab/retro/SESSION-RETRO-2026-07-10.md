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
