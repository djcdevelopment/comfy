# Rules as Decision Records — a rule is a resolved conflict with its history stripped off

> A fourth reading of the policy axis, alongside [`governance.md`](governance.md) (policy is a
> distinct axis) and [`creator-events-rules-analysis.md`](creator-events-rules-analysis.md) (what the
> current rules enforce). Those two ask *what the rules say*. This one asks **where a rule came from,
> and what was lost on the way.** Source: a live conversation with two guild masters, 2026-08-01.

## The claim

Every standing rule in Comfy was once a conflict. Someone fought over something, the fight was
resolved, and the resolution was written down as a rule. The rule is therefore not a commandment —
it is the **output of a decision**, and the conflict was the **input**:

```
conflict  →  resolved head-on  →  a decision  →  a rule
                                                  └── + the conversation that forced it = a decision record
```

That last step is the one Comfy never took. The rule survives; the conversation that produced it does
not. What remains in the pinned message is the *conclusion* of an argument nobody can read anymore.

This is the same artifact software teams call an **ADR** (architecture decision record): context,
the decision, consequences, and a status that can become *superseded*. The value of an ADR is not the
decision — it is the **context**, because context is the only thing that lets a later reader tell a
still-good decision from an expired one.

## Why it matters here

**1. The rulebook already works this way; it just doesn't record it.**
[`governance.md`](governance.md) states the mechanism plainly without naming it: the old Creator Event
rules were "constructed in response to **people fighting over the opportunity to run events**." That
is a conflict resolved into policy. Every rule with a number in it — ≤2×/week, solo ≤3×/era, ≥50%
new-to-event — is the scar of a specific incident that nobody documented.

**2. Institutional amnesia is a named, recurring cost.** The Slayer GM spends real effort
reverse-engineering the origin and intent of rules he wasn't present for. Creators self-censor
because **many of the limits are unstated** — they are reading the negative space of past enforcement
and guessing. That is the tribal-knowledge tax ([`kernel.md`](kernel.md), Root problem) applied to
policy instead of process.

**3. Without context, a rule can only be obeyed or resented — never revised.**
[`community-insights.md`](community-insights.md) §4 already flags that rules may have been "defined
during times of plenty" and may not fit leaner times or a 1.0 influx. But you cannot responsibly
re-open a rule whose reason is unknown; the safe move is always to leave it, so rules accumulate and
never retire. Attach the context and a rule becomes **re-openable**: *this was decided under
conditions X; conditions X no longer hold.*

**4. It explains rule bloat without blaming anyone.** Nobody wrote too many rules. Each one was a
locally correct response to a real fight. Bloat is what you get when a decision log has no
supersede step — which is a structural property, not a failure of judgment. (Framing invariant:
*never a verdict on the past.*)

## The escape hatch — the other way a conflict ends

Not every conflict resolves. The alternative to head-on is the **escape hatch**: the conflict is
avoided, so no decision is made, so nothing is written down and nothing moves. Two consequences,
both observed:

- The unresolved thing **resurfaces as politics** rather than as a decision — friction that is
  political in character, not technical, and that costs the participants far more than the original
  argument would have.
- The absence of a rule is **not** the absence of a constraint. It becomes an *unstated* limit that
  creators learn by bumping into it. An avoided conflict produces the worst artifact of all: a rule
  that exists socially but not textually, and so can never be found, cited, or revised.

Corollary for the tool: taking conflict head-on is what produces forward progress, and a decision
record is what makes taking it head-on **cheap** — you argue once, and the argument is banked.

## The corollary — many balance scales, one missing objective

The same conversation produced a second, related finding. Comfy does not have *a* balance; it has
several balance scales, each maintained by a different person with their own tools:

| Scale | Held by | Typical instrument |
|---|---|---|
| **Gameplay balance** | guild / balance seats | DPS baselines, hand-built stat CSVs |
| **Creator balance** (what a creator may hand out) | creator-side seats | reward registries, caps |
| **Supply / access** (how easily materials are obtained) | economy / regen seats | economy sheets |
| **Grind rate** (how hard you must work for them) | emergent | nobody's, explicitly |

These are not four topics. They are **one coupled loop**:

```
supply loosens → reward value falls → creators must give bigger rewards
      ↑                                             ↓
tighten supply / grind harder ← gameplay balance breaks ← power creep
```

Turning any one dial moves all the others, which is the entangled-systems problem already recorded in
[`community-insights.md`](community-insights.md) §10 ("regen affects the global economy → hard to
change the rules that define them").

**Why there are so many scales:** everyone is solving the problem themselves, with their own tools.
This is the "epidemic of personal rafts" (§20) one layer deeper than we found it — the rafts are not
only scattered *knowledge*, they are **competing calibrations of the same economy**, each tuned
against a private objective.

**The open question, stated as it was asked:** *how does everyone understand the underlying
objectives that drive them?* This is the second independent arrival at that question — the Rangers GM
asked the same thing from the experience seat ("what are they balancing?", §9). Two seats, two
routes, same gap. The kernel's answer is "protect a shared, fair, immersive experience"
([`kernel.md`](kernel.md) throughline), but that answer has never been written where the people
holding the scales can see it, so each scale is calibrated in isolation.

**The through-line to the rest of this document:** a balance number is also a resolved conflict. The
same decision record that explains a rule explains why a coefficient is what it is — and a
coefficient without its reason is exactly as unrevisable as a rule without its reason.

## What this implies we build

Small, additive, and non-political — it changes no rule and judges no past decision.

1. **A rule record.** For each standing rule, the minimum viable context:
   ```
   rule_record {
     rule_id
     text                # the rule as currently stated
     era_introduced
     precipitating_conflict   # what happened that made this necessary
     decision                 # what was chosen, and what was chosen against
     conditions_assumed       # what had to be true for this to be the right call
     status                   # active | superseded_by(rule_id) | dormant
   }
   ```
   `conditions_assumed` is the load-bearing field. It is what turns a rule into something a future
   guild master can evaluate rather than merely inherit.

2. **Recover, don't author.** Most of this history exists — in staff threads, in the memories of
   people still present, in the diff between the old and new rule sets already captured in
   [`creator-events-rules-analysis.md`](creator-events-rules-analysis.md). This is an **absorption**
   job, the engine pointed at the policy layer: pull the conversation that produced each rule out of
   the thread it is buried in and attach it to the rule. Same move as the rest of the repo — the
   treasure is not missing, it is unfindable.

3. **A supersede step.** The one process addition: when a rule changes, the old record is not
   deleted, it is marked superseded and points at its replacement. That single habit is what stops
   the log from becoming another sheet that drifts.

4. **Objective headers on the scales.** For each balance scale, one line stating what it is trying to
   protect. Cheap to write, and it is the only thing that lets four privately-calibrated models be
   compared at all.

## What this is not

- **Not new governance.** No approval step, no authority, no bot. A record of decisions already made,
  owned by whoever keeps it — the same *no basement* constraint as everything else
  ([`community-insights.md`](community-insights.md) §12).
- **Not a verdict on the past.** Every rule in the log was a correct local response. The log exists so
  the *next* decision is cheaper, not so an old one can be indicted.
- **Not surveillance.** It records decisions, not people. The precipitating conflict is described
  structurally ("contention over event slots"), never as a named incident with a culprit.

## Open questions

1. **How far back is the history recoverable?** Which rules still have a living witness, and which are
   already orphaned? The orphaned ones are the argument for starting now.
2. **Who would own the log?** It cannot be central (it drifts, and it isn't yours) — so is it
   per-seat, with each rule owner keeping the records for their own domain?
3. **Does the supersede step survive a leadership turnover?** That is the actual test: the log is
   only worth building if the habit outlives the person who started it.
4. **Do the balance-scale owners agree on an objective when asked directly?** Worth finding out
   before proposing any shared model — if they already agree, the problem is only visibility; if they
   don't, that disagreement is the most valuable unrecorded decision in the community.
