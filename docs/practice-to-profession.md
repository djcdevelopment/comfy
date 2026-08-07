# Practice → Profession — the vocabulary already in the room

> Comfy staff have been doing release engineering, ops runbook authoring, and specification
> writing for years. What they don't have is the **words** for it. This file is the translation
> layer: what the community already does, what the industry calls it, and where it goes.
>
> It exists because the gap between a senior Comfy volunteer and a paid technical program
> manager is mostly **legibility, not skill** — and legibility is a much smaller thing to close.

## Why this matters now

The half of software work that is eroding fastest is **implementation** — turning a clear
specification into working code. The half that is getting *scarcer* is producing the clear
specification: writing down intent so precisely that an executor with no shared context can act
on it correctly, including when things go wrong.

Comfy runs on people who do that second thing as a default setting, without ever being taught
it and without a word for what they're doing. That is the asset. This document names it.

## Sources, and the evidence standard

Everything in the tables below is cited to **two community-authored documents, donated 6 Aug 2026**.
No term is a metaphor: where an industry word appears, it is the word the industry actually uses
for that exact thing.

| Ref | Document | Extent | What it is |
|---|---|---|---|
| **[RS]** | `Comfy Reset Schedule (Template)` | 3 pages, no images | Calendar spreads for E15, E16, E17, each with the same 8 milestones |
| **[HG]** | `Hobbit Home Placement Guide` | 2 pages, 13 embedded screenshots | GM procedure for placing a Hobbit Home reward build; p1 = Rewind basics, p2 = 7 numbered placement steps |

**Evidence tiers used below.** Claims are marked where they are not direct reads:

- **Observed** — stated verbatim in [RS] or [HG]. Quoted, with location.
- **Derived** — arithmetic on [RS] dates. Reproducible; see the generator.
- **Inferred** — a reading, not a reported fact. Flagged inline. Part 1 (the cognitive pattern) is
  inferred throughout and should be read as a hypothesis consistent with the artifacts, not a
  finding.

**Key derivation, and its check.** The [RS] milestone offsets were reverse-engineered from all
three calendars and agree exactly from T-49 onward.
[`../tools/era_release_train.py`](../tools/era_release_train.py) regenerates **all eight E17 dates**
(17 Jan, 24 Jan, 31 Jan, 7 Feb, 28 Feb, 3 Mar, 10 Mar, 14 Mar 2026) from the era start date alone.
That round-trip is the evidence that [RS] is a template rather than a record.

**What is deliberately not cited here.** A separate private message corpus exists under
`comfy-etheiry-analysis/` (gitignored, not distributable per that directory's README). It
independently corroborates parts of this document — including that the E17→E18 cadence broke and
an unscheduled interstitial era was inserted. **Those findings are recorded as operational facts
only; the supporting quotations stay in the private analysis and must not be copied into tracked
files.** Anything in this document that would require that corpus to defend has been left out.

**Known gap.** The 13 screenshots in [HG] have been extracted but not yet reviewed. Several are
referenced by the procedure itself ("see screenshot to the right"). Any claim here about [HG]'s
*completeness* — most importantly gap #1 in Part 6 — is therefore unverified against roughly a
third of the document, and should not be asserted aloud until someone has looked.

---

## Part 1 — The underlying pattern: position *is* process

Some people navigate work by **memorized position** rather than re-derived reasoning. You don't
re-solve "how do I do this" each time; you remember *where* you start, *where* you go next, and
what the screen looks like when you're in the right spot. As long as the environment holds still,
the thinking is nearly free.

The names for this are old and scattered across fields: **method of loci** in rhetoric,
**spatial constancy** and **muscle memory** in HCI, **chunking** in cognitive psychology,
**cognitive offloading** and **distributed cognition** in the Hutchins/Kirsh line — using the
environment itself as storage rather than holding state in the head.

**Here is why it matters, and it is not the obvious reason.**

Most expertise *compiles*. The expert practises until the steps fuse into a single intuition, and
then genuinely cannot take it apart again. Ask them to write the runbook and you get something
with holes — not from laziness, but because the intermediate steps no longer exist separately to
be reported. This is the knowledge-elicitation problem, and it is the reason most corporate
knowledge management failed.

**Position-anchored expertise never compiles.** Each step stays tied to a *place*, and places are
inherently separable. So the practitioner doesn't have to introspect or reconstruct — they walk
the route and write down where they went. Transcription instead of translation, with no loss.

That is the whole advantage. Someone who works this way is not learning a new skill when they
write a spec; they are **reading out a data structure they already maintain**. A memorized route
is an ordered sequence of discrete, unambiguous states — which is exactly the shape a workflow
definition, an SOP, a runbook, and a prompt all need.

It also explains why "just write down what you do" produces a usable procedure from some people
and mush from others. The instruction is identical. The internal representation isn't.

### What that looks like in the source documents

The Placement Guide reads like a route because it *is* one: go here, mine this out, if you can't
find a working angle do this instead, then go to the back corner beside the oven. The landmark is
load-bearing — "beside the oven" is not decoration, it's the address. The guide never explains
*why* the ward goes there, because the author doesn't hold a rule about ward placement. She holds
a location.

That's not a weakness in the document. It's the reason the document is executable.

---

## Part 2 — The map

### From the reset schedule — all rows cite **[RS]**

| What the document does | Industry term | The evidence (observed unless marked) |
|---|---|---|
| Milestones fixed at offsets from a launch date | **Release train** / T-minus scheduling | Every beat from T-49 onward is identical across E15/E16/E17 |
| Senior Staff → Creators → All Staff → Players | **Staged comms cascade**, tiered disclosure | Four distinct audiences on four distinct dates |
| Prep Server Online (T-42) → Closed (T-4) | **Staging environment lifecycle** | A named, bounded pre-production window |
| Era number keying assets (`HobbitHomeE16`) | **Release versioning**, versioned artifacts | "File name changes each era" |
| EoE / Threat kit window, then freeze | **Deprecation window + change freeze** | Kits open T-11, close T-4, era starts T-0 |
| E15 → E16 revisions | **Retro-driven runbook revision** | Proposals beat merged; Prep Server close moved T-11 → T-4; fuzzy "~1-2 July" replaced with a firm date |
| Publishing it as a **template**, not a log | **Process abstraction / parameterization** | The title says "(Template)"; the offsets prove it |

The last row is the important one. Extracting the invariant from three instances — rather than
keeping a fresh calendar per reset forever — is the move most organizations never make.

**Consequence:** the schedule is a pure function of one input. See
[`../tools/era_release_train.py`](../tools/era_release_train.py), which regenerates all eight E17
dates exactly from the era start date alone.

### From the placement guide — all rows cite **[HG]**

| What the document does | Industry term | The evidence (observed unless marked) |
|---|---|---|
| The document itself | **Runbook** (not documentation — an executable procedure) | Numbered steps with commands, in execution order |
| Named mod dependencies at point of use | **Toolchain / prerequisite declaration** | Rewind, Prefabulous, Casper, GottaGoFast, Eraser, Gizmo, Passward |
| Private world → screenshots → GM review → live | **Pre-production validation with a change-approval gate** | "Practice in a private world and send screenshots to a Hobbit GM for review before placing on live server" |
| `/undolb` → relog → `/del` → Ward Train | **Triage ladder / fallback strategy** | Four ordered remedies, each for a named failure mode |
| "NEVER use increments larger than 5" | **Blast radius limit** | Literally the industry term for capping the reach of a destructive operation |
| `--ig=LocationProxy` on space islands | **Exclusion filter against collateral damage** | "to avoid deleting land" |
| All 32 valid rotations printed out | **Paved road / golden path** | Makes the correct option the low-effort option |
| Ward + tracker + DM + `/hobbitrep` | **Manual reconciliation across systems of record** | One fulfillment, four places |
| The confidential PassWards tracker | **Credential system of record, least privilege** | Access grants, documented, restricted |
| `/hobbitrep hobbit_home_owner` | **Audit event / append-only log** | Marks the reward fulfilled |
| "Never used Rewind before? … Can't find the folder? …" | **Onboarding path, zero-context authoring** | Anticipates the new operator's failure points |

### The rarest item

Printing all 32 valid rotations instead of writing "use multiples of 11.25" is not thoroughness.
It is **knowing which ambiguity will be expensive** and pre-resolving that one, while leaving the
cheap ambiguities alone. That judgment is the scarce input to both AI-assisted work and
organizational scaling. It does not automate.

---

## Part 3 — The design bridge

These instincts did not come from software. They came from a discipline that hit the same problems
earlier, for the same reason: **production steps that are expensive and irreversible.** A print run
and a live-server placement punish vagueness identically.

| Design practice | The same thing, in software | Where it shows up |
|---|---|---|
| **Master page / template** — build the master, instance it per issue | Process parameterization; config-as-data | The reset schedule is a master page for era resets |
| **Design tokens / swatch palette / modular scale** — constrain a continuous space to an approved discrete set | Enumerated valid values; making illegal states unrepresentable | The 32 rotation values. 11.25° = 360/32 — she documented the game's snap grid as a token set |
| **Pre-flight / press proof** — proof before you go to press | Staging + change-approval gate | Private world → screenshots → GM review → live |
| **Asset naming conventions** — the discipline earned from `final_FINAL_v3.psd` | Artifact versioning | `HobbitHomeE16` |
| **Grid system** | Layout constraints, spatial contract | Rotation multiples; "front of home is on a rotation of 0" |
| **Design → dev handoff / redlines** | Specification authoring | The entire Placement Guide |

That last row is the one worth sitting with. **A graphic designer's core professional interface is
handing a specification to an executor who will implement it literally, without judgment, and get
it wrong exactly where the spec was vague.** That executor used to be a press operator, then a
front-end developer. The job of writing for that executor has not changed. Only the executor has.

People in this discipline have been prompting for their entire careers. The word is new; the
practice is not.

---

## Part 4 — This was enterprise before it was AI

The ability to hold work as a stable, repeatable, positional route — and then state it — was
valuable for decades before any of this. An entire industry exists because **most people can't**:

- **Business analyst** — a job title whose whole content is watching how work is done and writing
  it down as a process.
- **BPMN** — a standardized notation for drawing workflows as spatial diagrams. Boxes and arrows,
  because that's how the knowledge is actually held.
- **SOP authoring** — regulated industries (pharma, aviation, food safety) run on it and audit it.
- **Workflow engines** — Airflow DAGs, Temporal, Camunda, ServiceNow. Every one of them is a
  product for encoding "where you go next."
- **RPA** — UiPath, Blue Prism: *record where the human clicks, then replay it.* Position-memory,
  productized, as a multi-billion-dollar category.
- **Process mining** — Celonis and friends: infer the workflow from event logs, **because asking
  people didn't work.**
- **Value stream mapping** — the Lean/Toyota version of the same instinct.

Read that list as one sentence: the industry built increasingly expensive machinery to extract
process knowledge from people who could not articulate it. RPA exists because writing the spec was
too hard, so vendors recorded clicks instead. Process mining exists because interviews produced
fiction.

**AI did not create the value of being able to state your own process. It collapsed the cost of
acting on it.** Before: you stated it, then funded a team for two quarters to implement it. Now:
you state it and it runs. The scarce input is unchanged — it's still someone who can say exactly
what should happen, in order, including the failure branches. Everything downstream of that got
cheap, which makes the input *more* valuable, not less.

So the pitch isn't "this skill is newly useful because of AI." It's: **this was always the
bottleneck, the industry spent thirty years and enormous money routing around people who lacked
it, and you have it natively.**

---

## Part 5 — Where it goes

| Role | Fit | What already transfers |
|---|---|---|
| **Technical Program Manager** | strongest | Release trains, comms cascades, cross-team milestone tracking, retro-driven process revision |
| **Release / Launch Manager** | strong | The reset schedule *is* this job |
| **Design Ops** | strong, and unusually well-matched | Design discipline plus process authoring — the exact intersection, and a role that is growing |
| **Business / Process Analyst** | strong | Eliciting and documenting workflows; the profession built for this cognitive style |
| **Platform / Developer Experience Engineer** | strong | Paved roads, onboarding docs, toolchain curation |
| **Product Operations** | strong | Process design, reconciliation, systems of record |
| **Site Reliability Engineer** | partial | Runbooks, blast radius, triage ladders — missing the systems/coding half |
| **Solutions Architect** | partial | Requires more implementation depth |

**Honest caveat.** Enterprise hiring for these roles is credential-heavy and filters on prior
industry experience, so none of this is a short move. But the gap is vocabulary and portfolio
framing — mechanical work — not capability. In solo, small-team, and AI-native work the credential
gate mostly isn't there, and this profile pays off immediately.

---

## Part 6 — The questions this work opens

Documents this good stop generating corrections and start generating *questions* — the ones a
senior practitioner asks about their own procedure once the basics are long settled. Five are
sitting right on the surface here.

Each is also, deliberately, a good task to hand an AI: a mechanical, exhaustive sweep over a
document, where the judgment about what to do with the answer stays human.

**1. "For every step here, what's the reversal — and what does it cost?"**

The load path already carries a proper escalation ladder — `/undolb`, then relog, then `/del` with
a capped radius, then the Ward Train. That is more failure-handling than most production runbooks
carry. The same question hasn't yet been put to the later steps: terrain, ward, sign, mark-off.

*Where AI helps:* give it the procedure and ask it to walk every step and name the undo for each.
It is exhaustive, and it doesn't lose interest by step 6.

**2. "If these four records disagree, what tells me?"**

One placement writes to four places — the PassWard, the tracker, the player DM, and `/hobbitrep`.
Each can be missed independently, and nothing currently compares them.

*Where AI helps:* describe the four records and ask what a reconciliation check would look like —
what to compare, how often, and what a mismatch actually means.

**3. "Where am I still asking for a judgment call I could pre-resolve?"**

The 32-row rotation table *is* the answer to this question, already applied to rotations. "Adjust
the era # accordingly" is the same class of thing, still unresolved.

*Where AI helps:* scan the document for every point where the reader has to compute, look up, or
decide, and list them. Which ones are worth pre-resolving stays the human call — that's the
judgment named in Part 2, and it doesn't automate.

**4. "What does this depend on that someone else controls?"**

The sign font lives behind a link. The mod versions move. The folder path "may vary from computer
to computer." Each is a place the procedure can break with no warning and no owner.

*Where AI helps:* enumerate every external dependency in the procedure and rank them by what
happens when one disappears.

**5. "Which of these are invariants, and which are just habits?"**

Three eras of data are already in hand. Everything from T-49 down holds exactly; the announce beat
drifts across T-54/55/56 and is the one milestone not pinned to a weekday. Knowing which is which
is the difference between a template and a routine.

*Where AI helps:* hand it the three calendars and ask which offsets are constant. Arithmetic it
won't get wrong, over data that already exists.

### What connects them

Four of the five sit at a point where **something isn't pinned to a fixed position** — the era
number floats, the font is at an address someone else owns, the announce beat has no weekday, and
the four records can drift because nothing compares them.

That's the characteristic edge of a position-anchored method, and the direct cost of its strength:
superb wherever the environment holds still, thinner exactly where the environment can move
underneath it. The compensation is already happening by hand — *"this folder path may vary from
computer to computer"*, *"sometimes the game shows you prefabs that are not actually there
anymore."* The whole triage ladder exists because Rewind's displayed state drifts from its real
state.

**Which makes it one move rather than five:** pin what can drift. Each of those converts a manual
compensation into a fixed position — the thing this method is best at consuming.

---

## How to use this document

**It is meant to be shared.** Parts 2–5 are a positive mapping — what the work already is, in the
terms the industry already uses. Part 6 is deliberately written as *questions*, not corrections:
the open problems this quality of work naturally raises, each paired with the kind of task an AI is
genuinely good at. Nobody is being told what they got wrong. They're being handed the next set of
questions and something that helps answer them.

Two things make it land as information rather than flattery:

**Every term is externally verifiable.** "Release train," "blast radius," "paved road," "runbook" —
none of it requires taking our word. That's the whole point, and it's what separates this from
praise.

**The vocabulary works best as the normal register.** Call the reset schedule the release train.
Call the placement guide the runbook. Let the generator emit a *staging window* and a *comms
cascade*. People look up what they don't recognize, on their own, and the discovery stays theirs.

What still doesn't belong in a handoff is a read on a *person* — how someone thinks, what it's
costing them, what they should do about their career. Part 1 is explicitly marked as an inferred
hypothesis for that reason. That material, where it exists, stays in the private analysis
directories and out of this repository.

## Related

- [`governance.md`](governance.md) — the policy axis; reaches the same "everything reduces to a
  per-run log" conclusion from the Creator Events rules.
- [`community-insights.md`](community-insights.md) — "an epidemic of personal rafts." The four-place
  bookkeeping above is a live instance.
- [`perspectives/README.md`](perspectives/README.md) — the human lenses the kernel was built from.
- [`../tools/era_release_train.py`](../tools/era_release_train.py) — the reset schedule, executable.
