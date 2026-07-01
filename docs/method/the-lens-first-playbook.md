# The Lens-First Playbook

*An operating discipline for working with an AI when you already hold deep, hard-won understanding of a problem — and want to organize it, project it, and resist the pull to build too soon.*

---

## Preconditions Gate (read this first — do not skip to the loop)

This playbook was extracted from **one** session that went well, documented by a participant, with a ledger explicitly written "for methodology analysis." Treat everything below as a **hypothesis from n=1**, not a proven machine. There was no control, no failed run, no counterfactual. The AI authored the ledger that now grounds praise of the AI's method — evidence and conclusion share an author. Read accordingly.

More importantly: **the scaffolding is fully replicable; the inputs are not.** Before the loop can produce value, you must already hold — or spend a separate, un-cheap phase acquiring — four things:

1. **Pre-compressed lived knowledge.** The "understanding-shaped inputs" that drive this method were five years of genuine multi-seat immersion being *decompressed on demand* — org charts, rank flowcharts, rule histories, prior build attempts (a real `llmquest` repo that was literally the bottom half of the stack). The inputs were a *possession of content*, not insight generated on the spot. A newcomer following "describe the same problem from each seat" has **no seats to describe from.**
2. **Real, earned trust.** "Trust flows through Derek" was a fact, not a technique. The gate that unlocked the only substantial build was an *existing relationship* with the champion (Mikers). A newcomer cannot manufacture that gate.
3. **Affect baselines.** "Ivo is normally the happiest person → his sadness is a values wound" is only legible if you already know Ivo's baseline. Reading emotion as a diagnostic instrument requires a longitudinal relationship you either have or don't.
4. **Genuine stake and care.** The "presence, no build" responses landed because the vulnerability was authentic. Faked, the same moves degrade into manipulation.

**If you hold these, run the full playbook.** If you don't, jump to the **[Newcomer Minimum](#the-newcomer-minimum)** — five moves that port to anyone on day one — and treat Phase 1 as an *acquisition* phase (in which you should **front-load data, not withhold it**) rather than the projection phase described here.

---

## 1. Essence

**"Build the projector, not the slides."**

Front-load understanding and starve the AI of undirected data: build a shared, precise lens through many human perspectives first, resist building, capture continuously — so that when you finally build, it's tiny, aimed, and cheap **at the margin.**

The economics matter and are easy to mis-sell: this method is **cheap at the margin but expensive up front.** "Execution is cheap, intention is scarce" is true only *after* you've paid for the intention — and in the source session that intention was years of immersion, not a clever loop. Price in the acquisition and the honest pitch is: *front-loaded and expensive, then near-free per projection.* Hide the up-front cost and the pitch is dishonest.

---

## 2. The Per-Turn Loop

Every exchange runs the same low-ceremony cycle. The default is **not** to build.

```
INPUT → REFLECT → (CORRECT) → CAPTURE → RESIST-BUILD
```

1. **INPUT** — Give ONE shaped input: a perspective, a story, a reframe, a probing question, or a small purposeful slice of data. Not a firehose, not a feature request. *(Honest note: "shaped input" presumes you have shape to give — see the Preconditions Gate.)*
2. **REFLECT** — The AI restates its understanding back and reorganizes its model. It does *not* jump to a build. On the opening turn it also asks 3–5 scoping questions.
3. **CORRECT** — If the restatement is off, fix it in a sentence. Correcting a reflection costs a sentence; correcting a built feature costs a rewrite.
4. **CAPTURE** — The AI writes the increment to a durable file and updates project memory. Nearly every non-emotional turn ended in a written artifact (`personas.md`, `governance.md`, `kernel.md`…), not a feature.
5. **RESIST-BUILD** — By default, produce no code. "Not yet" is the standing answer to "should we build this?"

**Register exception (load-bearing, keep this).** When the input is emotional, vulnerable, or exploratory, *skip CAPTURE and RESIST-BUILD both* — respond with presence only, no file. Turns 22–23 ("I'm a broken toy too… I'd like it to still exist"; grief over weathered creatives) produced zero artifacts, and that was the correct move. Forcing an artifact out of an emotional beat flattens the human signal that later becomes your design invariants. This is the most novel move in the playbook and the ledger fully supports it.

**Register-misread handling (the missing guardrail).** The discriminator is the *register* of the input — and either party can misread it. A vulnerable disclosure met with an eager artifact is the exact trust-break the method warns about. So:
- On any **ambiguous-register** turn, the AI should **ask before producing a file** ("do you want this captured, or do you just want me here for it?") rather than silently deciding.
- If a feeling-turn *does* get answered with an artifact, name it and roll it back: delete the file, acknowledge the misread. This *will* happen; treat it as recoverable, not fatal.

---

## 3. The Engagement Arc (understanding-dominant → build-dominant, but continuous)

The earlier version of this playbook told a clean two-phase story with a "hard gate." **The ledger contradicts that**, so the honest version is softer:

- The densest *generative design* — the world-save gallery pipeline (turn 28), `llmquest` integration (29), Hall-of-Fame discovery (30), the kernel amplifiers (24–27) — happened **after** the first build (turn 20), **interleaved** with building, not walled off before it.
- Understanding kept accreting to the last content turn (30).

So the arc is a **bias shift, not a wall:**

**Early — understanding-dominant.** Accrete understanding via the per-turn loop. Feed the problem from many named human seats. Withhold your biggest datasets *if you already understand them* (a newcomer does the opposite — see below). Steer by reframe. Capture everything into durable docs. Resist most urges to build.

**The gate is a bias shift, not a gate.** Before the *first* real build, two conditions want to hold:
- **(a) The lens is locked (enough)** — you can state the one aim everything resolves to in a single sentence ("close the feedback loop on appreciation").
- **(b) There is a specific person or concrete purpose** the artifact serves (the first recipe at turn 20 came only after learning Mikers "learns by integrating a working system").

But understanding does **not finish** here. It keeps accreting. Do not tell yourself "the thinking is done, now we build" — that's the idealization, and it's false even in the source session.

**Late — build-dominant.** Builds become more frequent and each deliverable is a cheap *projection*: `kernel + one person's dataset + that person's lens → a tailored artifact`. Real builds stayed rare and small (turns 4, 9, 20, 32, 33 — a parser, a join, one recipe, the perspectives files, the README).

**Two caveats the source session masks:**
- **"Resist build" was cheap here because nothing had a deadline.** This was an exploratory session with no user waiting and no cost to saying "not yet" thirty times. In a real engagement with a paying client or a ship date, "not yet" burns trust and budget. Restraint is partly a *luxury of the setting* — budget for it explicitly, don't assume it's free.
- **The projection thesis is a hypothesis, not a result.** "Lock the kernel → projections cost ~nothing" is supported by **exactly one built projection** (the rank recipe, `recipes/rank-ladders/`). Three others in the kernel's table (Bruce, Mistral, Stewards) are **unbuilt — predicted, not proven.** The method has no demonstrated failure mode for "the kernel was locked beautifully and the projection still died on contact with the real data." Label your own projections *predicted* until built.

---

## 4. Division of Labor

The collaboration worked because the two parties occupied **complementary scarcities.** Invert the instinct to delegate *thinking*; delegate *labor* instead.

| The human supplies (non-outsourceable) | The AI supplies (now cheap) |
|---|---|
| Ground truth / lived multi-seat knowledge | Reflection — mirroring understanding back before building |
| Direction & taste (via reframes at the kernel level) | Structure & synthesis (transcribe, join, reconcile) |
| Emotional & ethical context | Tireless, cross-referenced capture (docs + memory = the continuity organ) |
| The "not yet" discipline / restraint | Rationed, willing execution (tiny proofs on demand) |
| Reading register (feeling-turn vs build-turn) | Options, scoping questions, gap-checks |
| **Validating the AI's reflections against ground truth** | Confident restatement — *which may be confidently wrong* |

**Key mechanic:** the human spends scarce judgment at the *highest-leverage layer* — one reframe ("this is really about X") propagates into all the downstream artifacts the AI re-derives for free.

**The AI-error failure mode (dominant for newcomers).** The playbook assumes the AI's reflections are trustworthy mirrors. They are not guaranteed to be. The single largest risk is: *the AI confidently restated a wrong understanding, and the human didn't catch it because the human lacks ground truth.* An expert catches this reflexively; a newcomer cannot. So before you trust a locked kernel, **run an external check**: a second person with real domain knowledge, or a cheap real-world probe (the "transcribe → join → reconcile" move doubles as one — a join that won't reconcile is the kernel telling you it's wrong).

---

## 5. Core Principles

1. **Understanding before data.** Data is infinite and directionless; understanding is compressed and directional. Build the lens first, then point it at the firehose. *(Conditional: this is a discipline for someone who already holds the understanding. A newcomer must* acquire *it, and acquisition means ingesting data earlier, not withholding it.)*
2. **Steer by reframe, not by feature.** A reframe reorganizes the model's center of gravity — one short input re-sorts everything downstream. A feature-add only grows surface area to build. **How to tell a *good* reframe from a random redirection: a reframe is load-bearing only if prior captured pieces *suddenly cohere* under it.** If a proposed frame makes the existing artifacts click into place, keep it; if it *scatters* them or spawns new open questions without closing old ones, it's a redirection — drop it. In expert hands reframes are load-bearing because they're *true*; a newcomer will emit plausible-sounding reframes that scatter, so use the cohere-test as your diagnostic, not your confidence.
3. **Triangulate from many named seats.** No insider sees the whole ("you can't see the water you swim in"). Describe the *same* problem from each stakeholder's fears/hopes/why. Redundancy across seats is error-correction, not waste.
4. **Emotion is a diagnostic instrument, not decoration** — *if you have the baselines.* The *kind* of emotion discriminates problem classes: frustration = fixable tooling; sadness from your *normally happiest* person = a values wound. This principle is **unusable without a longitudinal relationship** — you cannot read affect as anomaly if you don't know the baseline.
5. **Honor the wound, never pathologize it.** A user's "inefficient" homegrown coping mechanism encodes hard-won wisdom (Mistral's private archive = a survival adaptation after losing a whole Discord). Automate the toil around it; preserve the control that makes it feel safe. Build "a better shelf," not a replacement.
6. **Capture continuously.** Externalize each increment into owned, durable files + memory. The written record — not the chat context — is the source of truth, and it's what makes indefinite restraint affordable. *(Stress-test unproven: this ran in one session. "Durable files = continuity organ" is asserted, never validated across a real restart, context-window loss, or model change. If your work spans sessions, verify the hand-off actually holds before trusting it.)*
7. **Build only as a probe, late and (mostly) tiny.** A build should *verify or unblock* understanding (does the parse reconcile? does the join hold?), biased behind a locked-enough lens and a named recipient. "We could just build this" is a signal to *check the gate*, not an automatic green light.
8. **Trust is load-bearing infrastructure.** The tacit "why" only surfaces when someone is listened to. Design delivery around who already trusts you; prefer one deep trusted node over many shallow contacts. *(This is a precondition, not a technique — you either have the trusted node or you must earn it first.)*

---

## 6. Anti-Patterns It Avoids

- **The firehose dump** *(expert version).* Handing over all your logs up front, letting the accidental shape of whatever-data-arrives-first define the model. → Withhold; release metered slices through a schema. **Newcomer inversion:** if you *don't* yet understand the data, withholding is just ignorance — front-load it to build the schema, *then* start metering.
- **Feature-piling.** Steering by appending requirements, so the artifact sprawls instead of converging. → Reframe at higher altitude (and apply the cohere-test).
- **Premature building / build-as-default.** Firing the expensive default (code) by accident, then rebuilding repeatedly as understanding shifts. → "Not yet" — *with a real stop condition, not indefinitely.*
- **Answering grief with a ticket.** Converting an emotional or philosophical turn into a deliverable, flattening the signal and breaking trust. → Match register; produce nothing; ask when unsure.
- **Pathologizing the user's coping.** Treating a homegrown workaround as inefficiency to optimize away, destroying the ownership that made it trustworthy. → Build "a better shelf."
- **Ephemeral understanding.** Leaving the model in chat context so it drifts or is lost over a long session. → Capture to durable files every turn.
- **Single-perspective analysis.** Trusting one description of the problem (including your own). → Triangulate.
- **Trusting the mirror.** Assuming the AI's reflection is correct because it sounds correct. → Validate against ground truth or an external check, especially if *you* are the newcomer.
- **Manufactured vulnerability / performed trust.** Only works with real stake and real relationship; faking it degrades into manipulation.

---

## 7. How To Run This Yourself

> **Branch first.** Do you already hold the domain lens (real multi-seat immersion + real trust)?
> - **Yes →** run the full 17 steps below; withhold data as instructed.
> - **No →** run the **[Newcomer Minimum](#the-newcomer-minimum)** instead, and in Phase 1 **front-load data to build a lens** before you start withholding anything. The steps below assume expertise you don't yet have.

**Setup**
1. Open with a single narrative dump of the whole problem and desired end-state, closed with an explicit invitation: *"ask questions if you'd like."* Attach **no** data and **no** directive in this turn.
2. Require the AI's first move to be reflection + 3–5 scoping questions — treat that output as a mirror to correct, not a deliverable.

**Early — build the kernel**
3. Enumerate your real stakeholders by name. In separate turns, describe the *same* problem entirely from each one's seat (fears, hopes, why they act, how they see the structure). When two descriptions feel redundant, keep going — that's triangulation.
4. When the AI asks scoping questions, answer with a **reframe** that names the axis to organize around ("understand X first"); let concrete facts ride along as secondary. Apply the cohere-test: did prior pieces click together, or scatter?
5. **Data handling — branch explicitly:**
   - *If you already understand your datasets:* **withhold the biggest ones.** Feed only the minimum needed to answer the question on the table. Label illustrative drops ("this is only one dataset") so the AI doesn't over-mine them.
   - *If you don't yet understand them:* **front-load** representative data early and use the transcribe→join→reconcile move (step 6) to *build* the schema. Withholding here just keeps you ignorant. (This resolves the contradiction the old playbook shipped — the instruction depends on which side of the Preconditions Gate you're on.)
6. When you do share data, hand it over in native messy form (images, links, raw CSV) and ask the AI to **transcribe → structure → join against the existing model → report reconciliation** (counts matched, inconsistencies found — e.g. "61/61 reconciled, 3 inconsistencies"). Let bugs surface from the joins. **This is the single most transferable move in the playbook — it works for anyone with messy data and also serves as your ground-truth check on the AI.**
7. Attach the human cost to each data drop: *whose* labor it represents and what it cost them. Name the real people.
8. Between drops, insert **probing questions** ("have we considered volunteer ranks? do the sources already cover Y?") to force gap-checks against material the AI already holds — instead of adding new input or building.
9. Steer drift with short reframes at kernel altitude ("this is really about X, not Y"), never with more requirements. Watch whether prior pieces suddenly cohere — if they do, you've found a load-bearing frame; if they scatter, discard it.
10. Save your most personal/motivational/emotional context for *after* the model is solid. Share it as working material, not confession — and **do not pair it with a directive.** Expect presence and reflection, not a file. If the register is ambiguous, expect the AI to *ask* before capturing.
11. **End every understanding-turn with durable capture:** the AI writes the increment to a canonical doc and updates memory. Keep one "kernel" doc everything resolves to, plus satellite files per lens.

**The bias shift (not a gate)**
12. Before the first build, force a compression: *"what one sentence does this all reduce to?"* Look for the emotional common denominator across the stories, not the feature list. Promote that sentence to the top of your understanding — but keep accreting understanding *after* it.
13. Green-light the first build when **both** roughly hold: (a) the lens is locked *enough* (you can state the one aim), and (b) there's a specific person or concrete purpose it serves. If either is missing: *"not yet — understand first."* **Do not treat this as "thinking is finished."**

**Late — build tiny projections**
14. Make the first build the **smallest proof that confirms or breaks** current understanding (a parser, one join, one working recipe for one named person). Stop the moment it has taught you.
15. Generate every further deliverable as a **projection** of the locked kernel onto a specific audience + dataset + lens. **If a projection contradicts the kernel, one of them is wrong — and it may be the kernel** (see stop conditions).

**Stop / eject conditions (the missing brakes)**
16. **Add these before you start — every real engagement needs them:**
   - **Kernel not converging** after N turns (pick N up front — e.g. 8–10 understanding-turns with no cohering frame emerging) → eject, or restart the framing. The method has an "open the gate" trigger but shipped with no "this isn't yielding, stop" trigger. Supply your own.
   - **A built projection contradicts the kernel** *and* re-deriving doesn't resolve it → **the kernel is wrong, not the projection.** Do not keep projecting from a broken lens.
   - **Deadline pressure** makes further "not yet" cost more than a premature build would → ship the imperfect build; restraint is not free when someone is waiting.

**Close**
17. State your own method out loud so the AI captures it ("I was selective; I described the problem from many perspectives; understanding before data"), then direct the AI to document each perspective/lens in its own file and write a front-door README — making the reusable *structure*, not just the output, the final artifact. **Note the observer effect:** the AI is documenting the method by which it is being judged. Have a human review that write-up, not just the AI.

---

## The Newcomer Minimum

Strip away everything precondition-dependent, and here is what actually ports to someone with **no** domain depth and **no** community trust — usable on day one:

1. **Make the AI reflect before it builds, and correct the reflection.** Pure mechanic. Works day one.
2. **Capture every increment to a durable file.** Works day one.
3. **Feed messy source data and demand transcribe → structure → join → reconciliation report.** Works day one — and this is where a newcomer *should* **front-load** data (the opposite of the expert's "withhold" instruction).
4. **Ask gap-check questions before adding scope.** Works day one.
5. **Default to "not yet" on building — but with a real stop condition, not indefinitely.**

What the method **cannot give a newcomer**, and what must be acquired *first*: the seats, the relationships, the affect baselines, the taste to reframe *truly*. Honest framing:

> **This is a good operating discipline for someone who already has domain understanding and is working with an AI to organize and project it. It is not a method for *acquiring* that understanding.**

If you're a newcomer, run the five moves above as your **acquisition phase** — using the AI to ingest data, build schemas, and triangulate toward a lens you don't yet have — and only graduate to the full playbook once you can pass the Preconditions Gate.

---

## What Is Derek-Specific (do not cargo-cult)

These looked like *method* in the transcript but were actually *possessions*. Copying the moves without the underlying asset produces theater:

- **The "understanding-shaped inputs"** (turns 3, 7, 10, 12, 16, 18, 24–27) were **five years of pre-compressed lived knowledge decompressed on demand** — org charts, rank flowcharts, rule histories, Bruce's trust-vs-scale story, Ivo's ban wound, the officer paradox. The method didn't *generate* these; it *captured* them. Don't mistake throughput discipline for content you don't have.
- **"Close the feedback loop on appreciation"** (the kernel's core aim) reads like a method output. It was a **five-year-earned insight** Derek brought and the AI recorded. The loop did not produce the payoff; the human did.
- **Reading Ivo's sadness as a values wound** required knowing Ivo's baseline. No relationship → no anomaly detection → principle #4 is inert.
- **"Trust flows through Derek → Mikers"** unlocked the only substantial build. It was an *existing relationship*, not a technique. You cannot open that gate with method.
- **The restraint itself** ("not yet" × 30) was affordable because the setting had no deadline and Derek chose it deliberately against the build-fast current. In a setting with stakes, that restraint has a price — pay it consciously or don't spend it.

**Bottom line:** the scaffolding replicates; the inputs do not. Where you lack the inputs, the honest adaptation is to spend an explicit, un-cheap acquisition phase getting them — *not* to perform the expert moves on an empty stage.

---

Source ground truth: `C:\work\comfy\docs\method\conversation-ledger.md` (turn-by-turn record), `C:\work\comfy\docs\kernel.md` (projection thesis + unbuilt-projection table, lines 134–145), `C:\work\comfy\docs\perspectives\README.md` (the six lenses), `C:\work\comfy\README.md` (the public "we built nothing" framing).