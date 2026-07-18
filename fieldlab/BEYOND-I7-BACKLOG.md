# Beyond-I7 Backlog — post-milestone invariants

> **Cross-reference (2026-07-18):** the M-series living roadmap
> (`C:\work\Lumberjacks\docs\roadmap\` + `docs/plan-m1-strict-admission.md`) now owns the
> sequencing of most of this backlog and did not previously point back here (nor here, there).
> Mapping: **B1** (concurrent-peer composition) is absorbed by **M4b** "prove two real Steam
> clients" (after M4a recipient isolation); **B2** (density/sustained scale) is absorbed by
> **M3** "traffic proof definitive and durable" + **M6** "widen in evidence-backed waves".
> **B3 (ToS/legitimacy) is NOT absorbed by any milestone** — no M-series gate runs the formal
> ToS/EULA/anti-cheat review, so B3 remains owned here and should hard-gate **M5** (the first
> external volunteer) when that milestone is opened. Do not re-derive B1/B2 from this file;
> pick them up through the M-series packets.

**Opened 2026-07-12**, on the close of P7/I7 (the "one client fully on Lumberjacks" milestone —
see the [worklog I7 rung](VALHEIM-NETCODE-REPLACEMENT-WORKLOG.md) and window `i7-w6`,
`fieldlab/evidence/i7-w6/`). This is the standing list of what the proof-of-concept swap
**deliberately did not prove**. It is a backlog, not a spec: each slice is stated as one
yes/no invariant in the same wind-tunnel discipline the I0–I7 ladder used (prove or kill one
thing in isolation, holding everything else constant), so any of these can be picked up as its
own gated packet without re-opening the closed rungs.

Everything below was **explicitly out of scope** for the netcode-replacement program. I7 proved
composition works for exactly one real client on a single Steam-only backend; these are the
questions that stand between that and anything shippable.

---

## Track A — Multi-client / concurrent-peer composition

The I7 close was single-client by design (I2's own grounding notes that "a second peer only adds
*contention*, which is beyond-I7 density work"). Real Lumberjacks authority has to survive more than
one player.

- **B1 — Concurrent-peer composition.** *Invariant:* with **two or more** real rendered clients
  joined at once, the full I2+I3+I4+I5 composition holds — each client stays in-world, ownership
  stays pinned to the Lumberjacks authority under genuine cross-client contention (two peers
  entering the same zone), redirect receipts stay lossless, and no client desyncs — for a full
  window, world intact on reload. *Why it isolates:* it changes exactly one variable versus i7-w6
  (peer count), so any new failure is attributable to contention, not to a rung. *Note:* needs a
  second licensed Steam account on a second real-GPU host (the OMEN+second-seat topology), not a
  second login on one account.

## Track B — Density / scale

I7 ran a bounded window (25 pinned ZDOs, 3474 redirected conifers, ~3 min). Era16 is ~9.15M ZDOs.
Scale is a separate question from correctness.

- **B2 — Density and sustained-window scale.** *Invariant:* with a **materially larger** tagged-prefab
  set and redirect volume (order-of-magnitude more pinned/redirected ZDOs) sustained over a **long**
  window, the composition still gates green — redirect stays `receipts_match_no_loss` at volume, the
  pin holds at scale, no gateway backpressure or mod-side queue overflow drops receipts, and
  save-integrity stays within tolerance. *Why it isolates:* holds the composition constant and pushes
  only volume/duration, so a failure is a throughput/backpressure limit, not a logic bug. *Note:*
  performance-under-density (tick rate, hitches) was the July-4→8 perf era's methodology — revive
  those baselines here rather than re-deriving them.

## Track C — ToS / legitimacy review

This program is a **network-layer intercept of a commercial game** (Valheim). Every rung to date ran
under one framing: **authorized research on our own licensed dedicated server**, single operator, no
redistribution, no interference with other players' sessions. That framing is a hard gate before
anything leaves the lab, and it is a *legitimacy* question, not a technical one.

- **B3 — Redistribution legitimacy.** *Invariant:* a concrete answer exists to "may this ship, and to
  whom, under what license/consent" — i.e. the ToS/EULA/anti-cheat posture for the specific
  distribution shape is reviewed and returns a clear **yes/no with conditions**, rather than the
  research's current *unresolved*. *Why it isolates:* it is orthogonal to every technical rung and
  gates nothing about *proving feasibility locally* — but it hard-gates any public release. *What a
  real deployment would need to document:* the licensed-server-only boundary (server operator owns the
  install), no modification of clients we don't own, explicit player consent for the authority swap,
  the anti-cheat interaction (a network intercept can read as tampering), and whether the redistributed
  artifact is the mod alone (operator supplies their own game) or anything bundling Valheim code.

---

*These are the successors to I7, not extensions of it. I7 stays CLOSED; picking up any B-slice opens a
new packet with its own gate, evidence dir, and the same 2-independent-non-doc-source rule.*
