# Proposal: a lightweight, open-source **Community Systems Registry**

> Answers: "what lightweight tool would help guilds/stewards build systems and maintain the
> interaction — and be open-sourceable for any community?"

## The design constraint (from Bruce's story)

Comfy's trust nose-dived (era 6) because **scaling traded personalization for efficiency**, and
trust lived in the personalization. In-person whitelisting silently became a checklist; rules got
rigid. **So a tool that only adds efficiency makes this worse.** The only tool worth building has
one job:

> **Absorb the mechanical/bookkeeping load that scale imposes, so a volunteer steward's scarce
> attention goes back to people.** Automate the rote (Bruce's "stop players squabbling over loot")
> precisely to free humans for the relational work that actually builds trust.

## Delivery model — an agent-leveraged framework, NOT an app (per Derek)

Hard constraint: **zero additional lift for community leaders.** No new bots to run, docs to
rewrite, or workflows to change. Derek personally engages willing stewards, learns their workflow,
and collects their *existing* artifacts as-is.

So we don't ship an app they must adopt. We ship an **open-source, forkable framework that an AI
agent uses on their behalf** — runnable by anyone with a **12–16GB-VRAM local model (Ollama)** or a
**$20 web AI account.** We provide **structure + worked examples + validators + copy-paste prompts**;
the volunteer points their agent at it, and the agent does the mechanical work and renders value
back in the formats they already use.

**The agent is our real user; the volunteer is the beneficiary.** Consequences for how we build:
- **Agent-legibility is the #1 criterion.** Small, self-contained recipes; explicit step-by-step
  prompts (a weak local model can't infer cleverly — spell it out).
- **Validators are guardrails, not niceties** — they let a weak agent check & fix its own output.
- **Small context.** One recipe at a time; never require loading the whole repo.
- **No heavy deps / no keys / no services.** Plain text + stdlib-first Python. The AI is the
  volunteer's own.
- **The flywheel:** each steward Derek helps adds a real example → the framework gets richer → the
  next community's agent does better → more adoption → more demonstrated value.

## The framework

A **git-backed, schema-driven registry** for the *systems* a volunteer community keeps
re-deriving and losing: **guilds/groups, ranks & rank-up paths, quests, rules, roles, onboarding.**

The core loop — **define once → validate → render → version:**

1. **Define once.** A steward writes a system in a simple human-writable file (YAML), e.g. the
   `guild-rank-ladders.yaml` we already built — instead of a rank *graphic* that drifts.
2. **Validate.** Schema + consistency checks catch drift and errors (the same idea as the
   `base == Σ damage split` check that caught 3 bad rows; missing fields; broken cross-references).
3. **Render.** Emits the artifacts the community *already uses*, so it fits existing workflow
   rather than replacing it: a clean rank/quest page (replaces the drifting image), the exact
   **copy-paste bot command strings** players use, an onboarding checklist, a rules doc.
4. **Version.** It's just files in git → free history, diffs, and — crucially — a place to record
   the **why** ("this rank cost changed in era 6 because…"). That's the institutional memory that
   erodes across leadership turnover. It also makes systems **era-scoped** by construction.

### Why this is the right shape
- **Kills the tribal-knowledge tax.** New stewards *read the registry* instead of reverse-
  engineering seven guilds from images and pins (the "became a Guild Master by decoding it" story).
- **Protects the human element.** By owning the bookkeeping (rank tracking, drift-checking, command
  generation), it hands stewards their time back — the opposite of rigid.
- **Preserves context/why**, not just rules — directly countering "rules defined during times of
  plenty" with no memory of intent.

## v1 = the first **recipe** (genuinely lightweight)

A **recipe** is a self-contained folder an agent can be pointed at in isolation:

```
recipes/rank-ladders/
  PROMPT.md          # copy-paste instructions that orient ANY agent (local or cloud)
  example-input.md   # a real messy artifact (e.g. the transcribed rank flowchart)
  example-output.yaml# the structured result (our guild-rank-ladders.yaml)
  schema.md          # the shape, in plain language
  validate.py        # stdlib-only checks — the agent's guardrail
  render.py          # emits the human page + copy-paste bot strings
```

First recipe: **rank-ladders** (schema already exists in `data/reference/guild-rank-ladders.yaml`;
validator/renderer are small). It runs on a 12–16GB local model or a $20 cloud account, needs no
keys, and immediately ends "rank graphics drift / newcomers reverse-engineer everything." Nothing
bigger is needed to prove the model.

The keystone artifact — the thing you actually hand someone — is the agent orientation guide:
**`framework/AGENTS.md`**.

## Natural extensions (roadmap — NOT v1; resist scope creep, per Bruce's rigidity warning)

- **Rules module:** define rules once; auto-tag the *countable* ones; export the newbie doc **and**
  feed the anti-farming detector (see `creator-events-rules-analysis.md`).
- **Onboarding/whitelist module:** structured-but-human intake that captures the **human read**
  (how they interpret a rule, PvP opt-in) **and a first-class age/consent safety gate** — the exact
  gap Bruce flagged.
- **Integrity detectors:** anti-farming + anti-cheat consume the structured rules + game-DB deltas.

## Open-source / generalizable

Every volunteer-run game community (Discord + a game server) has this same problem: systems locked
in images/pins/heads, drifting, context lost at every leadership change. The schema is generic —
groups / progression / tasks / rules / onboarding. **Comfy is a rich testbed; the tool serves any
community.**

## The kicker

**We've already been building this tool's skeleton all session.** The structured YAML models, the
versioned rule files, the validator/normalizer, the cross-dataset reconciliation — that *is* the
registry's engine, prototyped against real Comfy data. v1 is mostly packaging what's here.
