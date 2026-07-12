# Session Retro — 2026-07-12 · P7/I7 close: one client fully on Lumberjacks

**One-line:** We **reconciled, captured, and closed** the final rung — a single clean window on a
roomy GCP VM landed all four Harmony rungs green at once, proving one Valheim client running fully
on Lumberjacks — after establishing that the weeks-long blocker was never the code but an am4 host
RAM ceiling, and that the "already-passed" GCP claim was real-but-unarchived.

## What this session was

A **reconcile-then-capture** session, not a build one. No new mod code shipped. The prior sessions
had built and individually gated all four rungs (I2–I5) and proven they compose without collision;
what remained was one clean single-window four-for-four capture, blocked purely by am4 OOM. The task
opened with an explicit warning — the GCP P7 environment "may already have passed a live window,
reconcile that FIRST." So the work was: verify the true state against live non-doc sources, decide
whether step5 was genuinely open, then land the airtight capture and package the milestone. Derek's
only physical act was the one thing no automation can do: a fresh quit-to-desktop launch + join +
password.

## What shipped

| Commit | What |
|---|---|
| `fb972b1` | **P7/I7 CLOSED** — one-client-fully-on-Lumberjacks. Reconciled the board vs. the GCP claim; archived the `i7-w6` full capture + `i7-gcp-w1` corroboration; board → all 8 phases done; dashboard republished; worklog I7 closed; beyond-I7 backlog opened. |

New durable artifacts:
- `fieldlab/evidence/i7-w6/` — the milestone bundle: `gate-summary.json` (four MCP gate verdicts) + gateway/mod/client raw artifacts + `server-log-lifecycle.txt`, all sha256d, honest `PROVENANCE.json`.
- `fieldlab/evidence/i7-gcp-w1/` — corroborating **partial** bundle for the earlier GCP window (server-log ACCEPT + mod-side redirect `auto_stop seq=6316`).
- `fieldlab/BEYOND-I7-BACKLOG.md` — post-milestone invariants (B1 multi-client, B2 density, B3 ToS).
- Memory: [[gcp-p7-live-target]], [[iap-ssh-foreground-only]]; updated [[valheim-lab-working-topology]].
- ADR 0004 (GCP migration to lift the OOM ceiling).

## The team retro — our collaboration across the seats

We ran it as a small team with two seats filled: **Claude** held the whole picture, drove the
reconciliation, tools, instrumentation, and every repo write; **Derek** paced the go/stop calls and
supplied the single live launch+join+password that is the gate.

**Architect (Claude drove).** The load-bearing call this session was epistemological, not structural:
treat the GCP README's "gate passed" as an *unverified doc claim* and reconcile it against live
non-doc sources before acting — exactly the program's own ≥2-independent-sources trust rule turned on
its own optimistic paperwork. That caught the real shape (migration genuinely done and healthy; the
gate itself doc-only, no evidence bundle, and the box drifted *armed*) and prevented both a false
"already done" and a wasteful blind re-run. What I'd keep: the reconcile-before-rerun discipline.
What to change: nothing structural — the composition design was already proven; this seat's job was
to not overtrust a friendly document, and it held.

**Implementer (Claude drove; Derek validated live).** There was no code to implement — the "build"
was orchestration: point the proven harness at GCP (`set-gcp-p7-target.ps1`), stage, arm, gate,
disarm, all reusing the shipped scripts and mod unchanged (0.5.18, SHA verified on the live box).
Near-zero authored artifact, high leverage. The friction was environmental, not logical (see the two
traps below), and the right move each time was to fall back to a foreground/bash primitive rather
than fight the wrapper.

**Reviewer / QA (Claude drove; the receiver cross-checked).** This seat was strong. The four gates
were verified at the *receiver* (gateway distinct_seq 3474 == mod 3474; injection render-confirmed
with owner-match at the gateway ack), not the sender's counter — the exact lesson bought in blood
last session. The one honest snag was save-integrity coming back `fail` on a lone `targets -1`; the
right QA call was neither to hand-wave it nor to overclaim delta-0, but to run the authoritative
cross-reload check, show ZDOs within tolerance and structural anchors exact, and reason it to benign
player+reload churn (the composition persists nothing — proven byte-identical P3–P6). Where QA stays
thin: still no regression battery; "world intact" rests on the anchors + the no-persist property, not
an exhaustive diff.

**Operator / SRE (Claude drove; the GCP box is now the P7 server).** The single operational fact that
mattered — headroom — was confirmed and decisive: ~48 GiB free of 62, swap unused, the full window
ran with a clean probe stop and no OOM. Deploy/te ardown discipline held: mod SHA verified live,
disarmed baseline confirmed by cfg readback, `supervisorctl restart` (never `docker restart`), server
left at observe-only. Two GCP-specific gotchas cost time and are now banked: the IAP-tunnel SSH hangs
in a background task (no console stdin) and PS 5.1 aborts on the tunnel's stderr WARNING. Both were
diagnosed to root cause, not worked around blindly.

**Product / planning (Derek set direction; Claude executed).** We built the right thing at the right
size and, crucially, *cheaply for the human*: one manual window, not two. The approved plan — retro-
archive the real-but-partial w1 as the corroborating first occurrence + run one fully-archived fresh
window, the two together satisfying repeatability — minimized Derek's involvement to a single
touchpoint while keeping the evidence airtight. Pacing honored "keep me out of the loop": HEARTH and
a subagent absorbed the doc prose; Derek was pulled in only for the irreducible physical act and for
the two genuine decisions (capture rigor; is-the-box-mine-to-drive).

### Two seats, two views

**From Claude's seat.** My highest-leverage move was refusing to close step5 on the strength of a
document that agreed with me. The README + worklog both said "passed," and both were one commit — I
went to `gcloud`, SSH, the health endpoint, the live server log, and the mod SHA instead, and only
then had a defensible status. My weakest moment was the arm hang: I ran the arm in a background task
and it stalled silently on the snapshot SSH; I should have known IAP-tunnel SSH needs a console and
driven it foreground from the start (it's now a memory so I won't repeat it). The thing I'd want next
time: a harness stage that self-detects background-vs-foreground and refuses to background an
IAP-ssh step rather than hanging.

**From Derek's seat** *(my reconstruction — correct me).* "The whole point of the tooling is to keep
me out of the loop, and this time it mostly did — I said 'go,' launched once, typed the password, and
got a closed milestone back with clean provenance. I flagged the tight arm window because I've been
burned by timing before; the answer that it's connect-relative, not arm-relative, was the right kind
of answer — it corrected my mental model instead of just reassuring me. I care that you didn't fake
delta-0 on the save when a real player had been walking around; the honest 'within tolerance, here's
why it's not corruption' is what keeps me trusting the green board."

## Last time's lessons — follow-through

| id | lesson | status |
|---|---|---|
| `L-2026-07-10b-1` | server-side mod HTTP must use raw sockets | **held** — the composed handshake/redirect ran server-side over the socket helper (ADR 0003), zero POST failures |
| `L-2026-07-10b-2` | "mechanism fired" ≠ "payload arrived"; verify at the receiver | **acted-on** — every gate verdict read from the gateway/receiver side, not the mod counter |
| `L-2026-07-10b-3` | external I/O edge needs end-to-end delivery proof | **acted-on** — the redirect + injection gates are receiver-verified end-to-end |
| `L-2026-07-10b-4` | mod `*-send.jsonl` buffers; a mid-window poll reads stale | **acted-on** — the live progress watcher polled the **gateway** receipts, not the buffered mod counter |
| `L-2026-07-10b-5` | ground-truth spatial targets from the world-save | n/a this session (reused the banked ground-truthed conifer stand 9376,105,544) |
| `L-2026-07-10b-6` | client auto-walk re-arms only on a full relaunch | **acted-on hard** — required Derek's fresh quit-to-desktop launch; caught + reset an early premature connect before it contaminated the window |
| `L-2026-07-10b-7` | reach for subagents + data, not Derek as live eyes | **acted-on** — one human touchpoint; worklog/backlog/map delegated to a subagent, retro prose to HEARTH |

## Lessons learned

1. **`L-2026-07-12-1` — Apply the trust rule to your own optimistic docs, not just to the game.**
   A README + worklog claiming "gate passed" were one commit and zero evidence; live `gcloud`/SSH/
   server-log/mod-SHA turned "maybe done" into a defensible "migration real, gate unarchived, box
   drifted armed." Reconcile before you re-run. → **ADR 0004** (consequence); reinforces
   [[post-i0-distrust-rule]].
2. **`L-2026-07-12-2` — The blocker was a resource ceiling, not the code; move the role, don't
   patch the mod.** Weeks of "clips" were all am4 host OOM (`oom_kill=9`); the fix was 62 GiB of GCP
   headroom, and the composition passed first clean window. Suspect the host before the patch when
   every failure is a mid-run disconnect. → **ADR 0004**.
3. **`L-2026-07-12-3` — gcloud IAP-tunnel SSH must run foreground; it hangs in a background task
   and PS 5.1 aborts on its stderr WARNING.** The arm hung on the snapshot SSH under backgrounding;
   the disarm died on the tunnel's harmless NumPy warning. Drive stages foreground; recover in bash.
   → **memory** [[iap-ssh-foreground-only]].
4. **`L-2026-07-12-4` — For a live-play window, save-integrity is "structural anchors exact + ZDOs
   within tolerance," not literal delta-0.** A real player walking a dense route churns a handful of
   spawner targets / ZDOs across reloads; that is not composition corruption (the composition persists
   nothing). Report it that way — don't fake delta-0, don't cry corruption. → practice.
5. **`L-2026-07-12-5` — Retro-archive a real-but-partial prior window as a corroborating occurrence
   to buy repeatability with one human touch.** i7-gcp-w1 (partial, server-log + surviving mod
   redirect) + i7-w6 (full) = two independent windows, satisfying repeatability without a second
   Derek window. Honest about which is which. → practice.
6. **`L-2026-07-12-6` — Reset the gateway windows before the real connect if anything touched them.**
   Derek's premature connect had already consumed the injection fixture (rendered ack timestamped
   before the fresh restart); resetting redirect/injection/handshake for the window made the evidence
   correspond only to the clean connect. → practice.

## Provenance

- **Git range:** `56597b9..HEAD` (1 commit, `fb972b1`). Prior GCP-build commits (`6b30502`..`56597b9`)
  were earlier sessions, not this one.
- **Offloaded (HEARTH `local_generate`, qwen3-coder:30b):** the five-seat team-retro first pass —
  **edit verdict: `minor-fixes`** (faithful to the factsheet, no invented facts; edited to add the
  seat-driver nuance the model flattened, inject the concrete numbers, and drop a "production"
  framing that doesn't fit a research program).
- **Frontier (Claude):** the reconciliation, factsheet, both seats' views, the follow-through grades,
  lessons, ADR 0004, `DECISIONS-PENDING`, memory, every repo-coherent edit.
- **`--fleet`:** not requested; no repo-aware fleet worker in this environment.
- **Ledger:** compact observation recorded via `valheim_record_note` (no strict `record_event`
  envelope tool in this environment — noted for faithfulness).
