# Creator Event Rules — Old → New, through the enforceability lens

- **Old:** `data/raw/creator-event-rules-old.md` (16 rules)
- **New:** `data/raw/creator-event-rules-new.md` (9 rules)
- Companion: `docs/governance.md` (why policy is a distinct axis).

## Headline

The rewrite **already performed the "decouple the two objectives" move.** The newbie-facing
"how to play" (New #1–#5) is separated from the anti-abuse limits (New #7, #9) — and the anti-abuse
limits were **written as hard, countable numbers**, not vague norms. That is exactly the shape a
back-end detector wants. Whoever wrote these made objective #2 *mechanically checkable*.

## What changed, by objective

### Objective 1 — simpler for newbies
- **16 → 9 rules.** Related items bundled (New #3 "Completing an Event" = clear enemies + loot
  search + loot split + leaving early, which were Old #5/#11/#12 scattered).
- **Gear rules collapsed** from two dense paragraphs (Old #3/#4, with "requires eitr food"
  definitions and Mistlands-vs-Ashlands split) to one line (New #2).
- **Culture/tone added** (New after #6): "be a comfy neighbor," "follow the spirit so more rules
  don't need to be made," praise for guiding newbies as "Protection" and leaving them the loot.
- **New onboarding mechanic — LFFT** ("Looking For First Time," New #9b): a discoverable way for a
  first-timer to get a run where prior-runners can't take loot.

### Objective 2 — discourage farming
- **Anti-farming promoted to its own block (New #7)** and stated as hard limits.
- **NEW solo cap (#7c):** "No event may be soloed more than 3 times per era" — includes solo runs
  of multiplayer events; parkour practice without loot is exempt. Closes the solo-farmer loophole
  that the old rules didn't cap at all.
- **Tightened (#7a):** "twice **per week**" (every week) vs. Old #10a "twice during its **first
  active week**." Much broader.
- **First Time Thursdays made permanent (#9a):** Old #16 sunset after "the first 6 weeks of an
  era"; New removes the sunset (every Thursday, 24h).
- **LFFT loot restriction (#9b):** players who already ran must not take loot / must yield to first
  timers.

### Notable simplifications/losses to sanity-check with the Creator Lead
- Old #3/#4 gear thresholds were explicit per tier; New #2 is cleaner but leaves the **exact
  Carapace-tier case** implicit (Mistlands magic yes, Ashlands magic/gems no). Worth confirming no
  gap was introduced between "Padded and under" and "Carapace."
- Dropped the "events can take 2–3 hours" heads-up (Old #11) — minor newbie-expectation info.

## Enforceability map — the core of this analysis

| New rule | Enforceable by data? | What it takes |
|---|---|---|
| #7a — ≤ twice per event per week | ✅ **Countable** | count runs per (player, event, ISO-week) |
| #7b — not two resets in a row | ✅ **Countable** | run timestamps vs. reset schedule per (player, event) |
| #7c — solo ≤ 3× per era | ✅ **Countable** | count solo runs per (player, event, era) |
| #9a — FTT: ≥50% new-to-event | ✅ **Countable** | each participant's prior-run history for (event, era) |
| #9b — LFFT: prior-runners take no loot | ⚠️ **Partly** | prior-run history + loot attribution per run |
| #5 — first full group claims | ⚠️ real-time | in-game arrival timestamps / presence |
| #2 — gear tier limits | ⚠️ hard | per-player inventory snapshot at event |
| #1 — no build/deconstruct/recolor | ⚠️ hard | game-state monitoring |
| #3.1/#3.3 — "good faith" clear / fair split | ❌ judgment | (social; loot-split only if loot logged) |
| "follow the spirit" | ❌ by design | non-detectable, intentionally |

**Everything in the "✅ Countable" rows collapses to one dependency: a per-run log.**

## The one thing it all hinges on — the RUN LOG

Minimum record to make New #7a/b/c and #9a/b enforceable:

```
event_run {
  run_id
  event_id
  era               # e.g. 16
  reset_id | run_started_at   # to evaluate "two resets in a row"
  participants: [player_id]
  solo: bool
  loot_claimed_by: [player_id]   # enables #9b; also feeds fairness
}
event_reset_schedule {           # already lives in #🔁-event-resets
  event_id
  reset_times[]
}
```

- **If this log already exists** (a Creator/bot records each run) → a farming detector is buildable
  **now**, and it's the natural first hub feature.
- **If it doesn't** → the countable rules are *currently unenforceable by data* (they rely on humans
  noticing). Then the first build is smaller and even more fundamental: **give Creator Events a
  run-log** — a lightweight submission at run completion, exactly like the guild/Best West bots
  already do for turn-ins. The rules were written to be counted; they just need something counting.

## Recommendation — a concrete first hub feature

**Creator Event run-log + anti-farming detector.** It:
- operationalizes objective #2 in data (auto-flags #7a/b/c and #9a violations for Moderator /
  Creator Lead) — so the newbie rulebook (#1–#5) can stay simple (objective #1);
- reuses assets we already have (the submission-bot pattern; the era dimension; the
  fairness-telemetry framing from the weapon-choices join);
- is small, high-value, and serves clear owners (Moderator enforces, Creator Lead sets policy).

### Open questions
1. Does a **run-log exist today**, and how is a "run" recorded — Creator marks completion, or
   players submit (like turn-ins)? Is **solo** flagged?
2. Is **loot attribution** captured per run (needed for #9b and for loot-split fairness)?
3. Where does the **reset schedule** live in machine-readable form (or only as posts in
   `#🔁-event-resets`)?
