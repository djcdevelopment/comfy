# Proposal Weighing Workbook — building the balance instrument in steps

> Companion to [`rules-as-decision-records.md`](rules-as-decision-records.md) (a rule is a resolved
> conflict with its history stripped off) and [`governance.md`](governance.md) (make fairness
> measurable). Those describe the *record*; this describes the *instrument*: how to get, in small
> reversible steps, from the analysis material we already have to a way of asking — deterministically
> where possible, legibly where not — **"is this proposal balanced?"**

## The honest frame first

No instrument makes a judgment call objective. What an instrument can do:

1. Make the **structure** of a proposal checkable deterministically (does it name an owner, a
   rollback, a measurable claim?). This part can be a lint, and a lint has no opinions.
2. Make the **judgments** explicit, anchored, and comparable (a 0–5 score against a written rubric
   with historical anchor incidents, under a published weight vector). This part stays human, but
   the *bias moves out of the head and into the weight vector*, where it can be argued about once
   and versioned — instead of re-litigated invisibly inside every decision.
3. Make **disagreement legible**: two scorers who diverge by 3 points on one dimension have found
   where the politics live. That divergence is the instrument's most valuable output, not noise.

"Balanced" is operationalized, not idealized: a proposal is balanced when **(a)** every claimed
impact has a measurable check, **(b)** the burden it creates is not concentrated on one seat
(maintenance gravity is the burden that hides), and **(c)** the impact-to-burden ratio clears the
bar *under more than one weight preset* — if it only wins under one lens, it is a faction's
proposal, which is allowed, but should be known.

## Part 1 — what we actually have (the evidence inventory)

Four analysis directories, one synthesis layer, and two policy docs. Weighted by evidential class,
not by effort spent:

| Tier | What | Examples | Weight it deserves |
|---|---|---|---|
| **A — deterministic** | Counts, checksums, exact quotes with evidence IDs, the rules' own countable numbers | monthly message histograms (plain awk), `evidence-index.csv`, `qa-report.json`, the ≤2×/week-style limits in the Creator Events rules | Full weight. Cite directly. This is the only tier that can settle an argument alone. |
| **B — extraction** | Patterns read out of a subject's *own* words | the three dossiers' arcs, recurring-friction lists, idea ledgers | High weight for "this person experienced X repeatedly." Zero weight for what any counterparty did — the corpora are one-sided by construction. |
| **C — reconstruction** | The negative space: counterparty archetypes, the 8 forces, the 0–5 scores, the default weights | all three pushback matrices | Priors, not measurements. Useful to *shape* questions; never load-bearing for a decision. The matrices' own READMEs say this — hold them to it. |
| **D — synthesis** | Two abstraction layers up | the ascent pattern, maintenance gravity, the archetype atlas | A thesis with n=3, all self-selected technical builders, one of whom is the analyst. It has survived one adversarial revalidation (the third history added counterevidence to earlier absolutes — good sign). Treat as the best current *lens*, re-testable, not settled. |

Three biases to keep written on the wall:

- **Every corpus is subject-side only.** The other half of every conversation is inference.
- **Sampling on the outcome.** The three subjects were chosen *because* they fit the builder
  pattern; the thesis has never been tested against a history that doesn't.
- **Nothing is calibrated yet.** Every weight and score in the matrices was authored, not fitted —
  no instrument output has ever been checked against how a decision actually turned out.

The house evidence rule already covers this: **two independent sources or it isn't a fact.** The
deterministic crossover (the awk histogram behind the ascent timeline) is the exemplar — one model
narrative, one model-free count, agreeing.

## Part 2 — what already exists toward the instrument

More than it looks like. The leap to "a governance system" is not one leap because three of the
pieces are built:

- **The force taxonomy exists twice, independently.** The staff-side matrix converged on eight
  resistance forces (Authority & Perms, Bandwidth & Burnout, Blast Radius, Enforceability, Engine
  Feasibility, Evidence Gap, Precedent & Powercreep, Timing & Dependency); the guild-master-side
  matrix independently produced eight of its own (Adoption Load, Cross-System Externalities,
  Fairness/Precedent Optics, Information Entropy, Jurisdiction Ambiguity, Reset Compression,
  Technical Fragility/Operator Dependency, Volunteer Bandwidth/Maintenance Gravity). Two vantages,
  heavy overlap → the overlap is the real taxonomy.
- **The scoring UI pattern exists** — weighted dimensions, drag-to-reweight, persona presets,
  live re-sort. The who-first matrix is the same instrument pointed at people-sequencing.
- **The record substrate is designed** — `rule_record` with `conditions_assumed` and a supersede
  step ([`rules-as-decision-records.md`](rules-as-decision-records.md)). A proposal record is the
  same artifact, upstream of the decision instead of downstream.

What does **not** exist: one canonical taxonomy, anchored rubrics, a proposal schema, any
calibration, and the process wrapper. That is the workbook.

## Part 3 — the steps

Each step is useful standing alone, is reversible, and produces a checkable deliverable. Stop at
any step and you still have more than today.

### Step 0 — Write the objectives down (the weights come from values)

Any weight vector is a values statement. If the values are implicit, the instrument launders bias
instead of exposing it. So first: one page, ratified, versioned —

- The kernel's core loop (action → creation → appreciation → renewed action) as objective #1.
- One **objective header per balance scale** (gameplay / creator / supply / grind): a single
  sentence stating what that scale protects. (Already prescribed in
  [`rules-as-decision-records.md`](rules-as-decision-records.md) §What-this-implies #4.)
- The standing constraints as hard gates, not weights: *no bot, no basement*, additive-never-
  indicting, accountability of rejection.

**Deliverable:** `docs/objectives-sheet.md`. **Check:** the four scale owners each agree their
header is what they are actually protecting — per the open question already on file, if they
*don't* agree, that disagreement is the most valuable finding so far, and the workbook pauses
here, because you cannot weight against objectives that aren't shared.

### Step 1 — Merge the force taxonomies into one, with anchored rubrics

Fold the two independent 8-force sets (plus the merchant-side matrix's forces) into one canonical
set of ~8. For each force, write a **0–5 rubric with historical anchors**: a real (structurally
described, never named) past incident for what a 1 looks like and what a 4 looks like. Anchors are
what make two scorers land within a point of each other — an unanchored 0–5 scale is a mood ring.

**Deliverable:** `docs/force-taxonomy.md` — name, definition, what-it-is-not, anchor incidents per
level. **Check:** two people independently score three *past* proposals against it; any dimension
where they diverge by ≥2 gets its rubric rewritten. Iterate until median divergence ≤1.

### Step 2 — The proposal record (structure is the deterministic half)

Mirror of `rule_record`, filled in *before* the argument instead of reconstructed after:

```
proposal_record {
  id, era, author_seat
  change              # what actually changes, in one sentence
  scales_touched      # which of the four balance scales this moves (the coupled-loop check)
  beneficiaries       # which seats gain, and what
  burden              # which seats pay: hours, attention, maintenance — per seat
  maintenance_owner   # who owns it in 6 months — named seat + an *accepted* handoff
  rollback            # how it is undone, and the cost of undoing
  measurable_claim    # the impact restated as something checkable, with its data source
  conditions_assumed  # what must stay true for this to remain a good idea
}
```

Then the **structural lint** — deterministic, no judgment: every field present; ≥1 measurable
claim with a real data source; a rollback that isn't "we just won't"; an accepted (not assigned)
maintenance owner; if ≥2 scales touched, the cross-scale effect stated. A proposal that fails lint
isn't rejected — it's **not yet scoreable**, which is a kinder and more useful verdict.

**Deliverable:** the schema + a lint checklist (or 50 lines of script over a YAML front-matter
form). **Check:** run three past proposals through it; the lint should catch, structurally, the
things that actually bit later (the missing owner, the absent rollback).

### Step 3 — The dual ledger (impact vs. burden, scored)

Now the instrument. Two sides, kept separate on purpose:

- **Impact side:** for each objective on the sheet, 0–5 with anchors — how much does this advance
  it? Every score above 0 must point at the proposal's `measurable_claim` for that objective.
- **Burden side:** the canonical forces, 0–5 with anchors — how hard does this pull on each? Plus
  the burden-per-seat table straight from the record.

Composite = weighted impact minus weighted burden, **under a published weight vector** — and run it
under 3–4 presets (per-seat lenses, like the matrices already do). Report all presets, never just
one number. The reading:

- clears the bar under all presets → genuinely balanced, proceed;
- clears under some → a faction proposal; the divergent dimensions name the negotiation;
- clears under none → the record still documents *why not*, which retires the idea instead of
  letting it resurface annually.

**Deliverable:** one self-contained HTML instrument (the pushback-matrix pattern, generalized) that
takes a proposal record and renders the ledger. **Check:** it reproduces, from the record alone,
roughly the verdict the room already reached on two known-outcome past proposals.

### Step 4 — Calibrate against history (the step nobody skips honestly)

The rulebook is a labeled dataset: every standing rule is a proposal that *passed*, and its
subsequent life (stable, endlessly-excepted, superseded, resented) is the outcome label. As the
decision-record recovery work proceeds, backtest: score recovered past decisions with the
instrument, blind to outcome, and see whether high-burden-concentration scores predict the rules
that later generated exceptions and politics. Adjust anchors and weights against that — now the
weights are *fitted*, not authored, which is as close to "unbiased" as this can honestly get.

**Deliverable:** a short calibration memo — instrument said / history said / what changed.
**Check:** after adjustment, the instrument retro-flags a majority of the known painful decisions
without flagging everything (a smoke detector that always fires is furniture).

### Step 5 — The process wrapper (governance-lite, still no basement)

Only now does it become a mechanism, and the mechanism is thin:

1. Proposal enters as a `proposal_record` (author fills it; the lint gates scoring).
2. **Two independent scorers** — different seats, or one human + one model pass; the point is
   independence. Scores diverging ≥2 on a dimension → the discussion agenda *is those dimensions*,
   nothing else. (This is where meetings stop being re-litigations of everything.)
3. Decision → decision record, with `conditions_assumed` — feeding the supersede loop so today's
   proposal becomes tomorrow's revisable rule instead of tomorrow's scar tissue.

No new authority, no approval bot, no change to who decides — the same people decide, but the
argument arrives pre-structured, the disagreement arrives pre-located, and the decision leaves a
record. **Check:** one full cycle on one real proposal, and the participants say the discussion was
shorter and hit the real issue.

### Step 6 — Automate the countable edges (last, not first)

Once the instrument has survived contact: telemetry-backed auto-scores for the deterministic
dimensions (the Creator-Event run-log detector from [`governance.md`](governance.md) is the
prototype — "farming pressure" becomes a number the burden ledger reads instead of a guess), a
model-generated first-pass score for the human scorers to correct, a dashboard over the decision
log. Automation is step 6 because automating an uncalibrated instrument just makes it wrong faster.

## What this is not

- **Not an oracle.** The deterministic parts are the lint and the arithmetic; the scores stay
  judgments. The instrument's promise is *reproducible, inspectable* judgment, not objective truth.
- **Not new governance.** Nothing here changes who decides anything. It changes what a decision
  costs and what it leaves behind.
- **Not a verdict machine on people or the past.** It scores proposal records — structures, never
  authors. The calibration step reads history to tune weights, never to indict decisions that were
  locally correct.

## Where to start Monday

Step 0 is one page and forces the most valuable conversation on the open-questions list (do the
scale owners share an objective?). Step 1 is mostly merging work already done twice. Everything
after that inherits its legitimacy from those two.
