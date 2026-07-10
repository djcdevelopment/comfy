# Handoff prompt — next build session (paste into a fresh session opened in `C:\work\comfy`)

> Snapshot as of 2026-07-10 after P3/I2 closed. Regenerate if it goes stale.

---

We're continuing the **Valheim × Lumberjacks netcode-replacement program**. Start by orienting from
canon — `fieldlab/GROUND-TRUTH.md`, the live dashboard
(https://claude.ai/code/artifact/1c10f4f8-d747-4411-a400-26d5fb155117), `fieldlab/TEST-PROGRAM.md`,
`fieldlab/DECISIONS-PENDING.md`, and the last retro `fieldlab/retro/SESSION-RETRO-2026-07-10.md`
(read its "Claude's addendum" — it has the technical carryover for this session). Trust rule still
holds: nothing after commit `c196f88` counts without ≥2 independent non-doc sources; design any
behaviour-change against the **decompiled assembly**, not the summary docs.

**Where we are.** P3 is CLOSED — I2 ownership pin PASSED its gates (mod 0.5.10; held on both funnels
with a live negative control; save intact). Current live state:
- **am4** (the dedicated server, 9.15M-ZDO world): mod **0.5.10**, pin **DISARMED**
  (`ownershipPinEnabled=false`) — back to the observe-only baseline. Save-integrity baseline stored at
  `network/var/valheim-save-integrity-baseline.json`. Silent between sessions.
- **comfy-gateway (:8720):** not running between sessions — **start it first**
  (`start-comfy-gateway.ps1`) before relying on MCP. It will load the 4 ownership read tools
  (`valheim_ownership_churn_summary` / `valheim_tail_ownership_churn` /
  `valheim_ownership_pin_status` / `valheim_tail_ownership_pin`).
- **OMEN client:** still 0.5.8 — fine; the pin was server-side. HEARTH door (:8710) up for offload.

**Pick the fork first (my open decision — ask me):**
1. **P4 / I3 — outbound redirect → Lumberjacks** (the natural next rung; does not require another I2
   run), **or**
2. **one more clean I2 repeatability join** first (window 1 last time was a corroborating floor cut
   short by the idle-restart; a 2nd authoritative window would make P3 airtight — quick, ~3 min).

**If P4:** the plan is in `TEST-PROGRAM.md` P4 / `WORKLOG` I3. Carryover from I2 that applies directly:
scope the send-suppression prefix to *exactly* the send funnel and nowhere else (the "one funnel, one
flag" discipline that kept the pin surgical); confirm I3 writes no persisted ZDO state so it inherits
the same save-safety the pin got from ownership-being-runtime-only; and reuse ADR 0002's
observe-during-change pattern — leave a send-observe seam on so suppressed-sends and Lumberjacks
receipts cross-confirm in one window. Bring up the Lumberjacks gateway (:4000/:4005) as step 1.

**Standing rules for this program:**
- **Before any timed gate window**, check am4's ~30-min `UPDATE_IF_IDLE` restart clock — it clipped a
  150s gate last session. Time the join clear of the boundary or pause the updater for the window.
- Behaviour-changes are **rollback-flagged, scoped, and gated** on the live world; deploy to the ROOT
  cfg (never the `config/` decoy), verify the boot log, snapshot save-integrity before arming, disarm
  after.
- Leverage **HEARTH `local_generate`** for draftable prose; keep judgment + repo-coherent writes
  frontier. Keep me (Derek) out of the loop except the one in-game join a gate needs — but pull me in
  before a thrash.
- One launch+join is the gate; build + deploy + prime so that join is the only thing I do.

Confirm the fork with me, then go.
