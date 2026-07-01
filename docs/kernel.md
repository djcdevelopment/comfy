# The Kernel — our locked-in understanding of the problem & approach

> DRAFT to ratify. Everything else in this repo compresses into this. A **projection** — a tailored
> artifact for one specific person, pointed at their dataset, in their language — is generated *from
> this*. Lock the kernel once → projections cost ~nothing. If a projection ever contradicts the
> kernel, one of them is wrong.

## Core aim — close the feedback loop on appreciation

Creatives need almost nothing *material* (the "starving artist" needs money least) — they need their
creation **seen and valued.** When the loop **action → creation → appreciation → (renewed action)**
closes, the community becomes **self-sustaining**, and people **choose their own adventure** — a closed
loop needs no manager; it feeds itself. **Every part of the approach below serves this one loop.** The
disease is the loop torn open (creation vanishing into silence, or into an unaccountable "no"); the
cure is closing it. *Build the loop, not the control.*

## The problem (precise, and tiered)

**Root — structural, not personal:** in a 100% organic, volunteer, modded-game community, **the skill
that gets you promoted (creativity, passion, play) is not the skill the role then requires
(maintenance, systems, administration).** At scale that mismatch produces, predictably:

- **tribal knowledge** locked in heads → dies at every leadership turnover;
- **drift** — rank charts, rules, quests live as images/pins/sheets that go stale;
- **heavy manual process** that crowds out the relationships that were the point;
- **burnout** → *caring becomes too expensive, so people stop paying*;
- **reintroduced artificial scarcity / gatekeeping** — the exact thing survival-game players reject.

**Tiered:** the problem looks different from each seat — player, rep, GM, OG/creator, steward — and
**no one inside can see or design the whole** (you can't see the water you swim in; the meta-skill
isn't the one that got promoted). → an **outside builder + AI** is the right shape — different
vantage, not superiority.

**Structural amplifiers (see `community-insights.md` §14–15):**
- **The officer paradox.** The magic is *humans curating the layer below them — managing expectations
  above immersion* (a DM for players; a creative lead for creators; a GM for members). It breaks at
  the top: **no one curates the curators**, so leadership stops being a game and becomes a job. That's
  the *mechanism* of burnout — you lose the very thing that made it magic, right as you start
  providing it to everyone else.
- **Condensation forced omniscience.** Once there were separate pillars — a creative sector and guild
  GMs — different recruitment/rewards, collaborating, so you could **lead without knowing everything.**
  Standardization condensed them into one hierarchy → every leader must now know everything → the
  tribal-knowledge tax and burnout, at once. (The absorption engine is the antidote: knowledge in an
  owned searchable source of truth makes it **safe to specialize again** — it gives back the pillars.)
- **Unaccountable rejection breaks trust — the *anti-appreciation*.** The community can return
  **arbitrary bans** (no documentation, no evidence, no recourse) but not accountable appreciation.
  *"If nothing's hidden and the bans are justified, why isn't the evidence posted?"* One unproven story
  poisons trust for everyone. And it **kills the healthiest growth vector:** you cannot *vouch* for a
  place to a friend if its authority is unaccountable — invite them, they get banned with no backup,
  and you've broken the handshake bond of friendship. (This is why **Ivo — the happiest person — was
  *sad*, not frustrated:** frustration = friction/tooling; sadness = a moral wound about the integrity
  of the place.) Accountability — documented reasons, posted evidence, real recourse — is the loop made
  trustworthy. *(Note: the most politically charged area — it directly challenges unaccountable top
  power; frame as "if there's nothing to hide…," additive, the community's own ask.)*
- **The vanity-metric trap = a broken feedback loop.** The proxy leaders optimize — "active" players
  online, max-skill achievements — *became the target*, so it stopped being a measure (Goodhart). It's
  **AFK-inflated** (someone parked by an auto-farm counts as active), so it **masks the decline** — no
  alarm fires. Ground truth exists (players *know*) but has **no channel upward**; only the hollow
  number reaches the abstracted top, so good ideas die when they dent it (spinning out a world to kill
  lag = better experience, but "costs player count"). The higher you abstract (player → creator → GM →
  steward), the more you trust the number and the further you get from the felt experience —
  **inevitably.** This is the unifying disease beneath the officer paradox and the perception gap.

**Urgency:** the community is in decline; **Valheim 1.0 (~2 months out) is the last-chance revival window.**

## The approach (how we work out of it)

**The core build is an absorption engine.** Seamless **auto-collection → consolidation → compression**
of the scattered existing content (docs, images, sheets, Discord posts, personal notes) into a
**trusted, searchable, self-organized source of truth.** Everything else — recipes, projections, rank
pages — is *downstream rendering* from what the engine absorbs. (This whole session is the manual
proof: content dropped in → absorbed → structured → rendered. The build streamlines that loop.)

**The output is a *personal, owned* source of truth, not a central doc.** Central docs drift and
aren't yours; Mistral's private-Discord archive works because it's owned and self-organized (see
`community-insights.md` §11). Keep the person's method and control; automate the collection; remove
the toil.

**Delivery (v1): a hands-on consulting experiment with Derek as the trusted human-in-the-loop.** Trust
flows through Derek; the tacit *why* only surfaces when someone is listened to. Each person he sits
with seeds another real example → which is what eventually lets it run without him
(consulting → recipes → self-sufficiency).

- **Absorb the mechanical load so humans get their time back for people and creation.** Never a fix
  imposed from above.
- **Craftable, open, repairable "recipes"** driven by the person's *own* AI agent — zero lift for
  leadership; grassroots value; runs on a 12–16GB local model or a $20 account.
- **Design invariants:** standardize the plumbing, never the content · owner-controlled, never
  surveillance · adoptable in isolation · center the author · self-sufficiency is the goal · teach
  **use / create / repair** · show the homework (open-source the *how*, not just the code).
- **No bot, no basement.** The tool must NOT be a centralized bot/service holding privileged access
  that everyone routes through — that just builds a third basement (the real Comfy blocker: ultimate-
  access bots live in ~2 stewards' basements, every change needs their approval; see
  `community-insights.md` §12). Decentralized, locally-run, no privileged host. **Interoperate** with
  existing bots (emit the paste-strings) without **becoming** one. **No approval bottleneck** — you
  change your own tools without asking a gatekeeper. **The line is *basement*, not *bot*:** an
  **owned, local, self-hosted control surface driven by your own LLM** is exactly right (see Derek's
  `llmquest` — "the Kid," a Discord bot you run on your own machine, fed your own data); a
  **centralized ultimate-access basement bot** is the anti-pattern.
- **Never automate the human magic.** The live creative/relational act — a person running a dynamic
  event as an invisible "god"/DM, the storytelling, the mentoring, managing challenges in real time —
  is **sacred and human.** Automate the *friction around it* (a coherence gate that says a creation
  fits the tier/rules/balance and is runnable; scaffolding; and **memory** — capturing the storyline/
  encounter/lore so it's preserved, appreciable, repeatable). **The tool holds the world; the human
  holds the story.** Automating the act itself would kill the thing worth doing.
- **Restore feedback loops through *celebration*, not just measurement.** The trusted, bottom-up form
  of a restored loop is a **community celebration** (nomination, enriched by voter-tenure *patterns*),
  not a top-down metric — measurement gets resented and gamed; celebration gets embraced. Same signal,
  opposite reception. (The inverse of the vanity-metric trap; see `community-insights.md` §16.)
- **Portable & owned.** The source of truth is **plain files the person owns** — survives losing any
  platform/account (Mistral lost their whole Discord archive and rebuilt by hand), and a recipe
  regenerates it in minutes. Never hostage to a platform or a gatekeeper's bot.
- **Framing invariants:** never a verdict on the past · **return, not repair** · lead with
  1.0/newcomers, not decline · make it **cheaper to care**.
- **Why open:** survival-game values — anti-manufactured-scarcity, anti-rent. Open-source is
  *restorative*: it hands the means of production back.

## The projection mechanic (why this is cheap)

*Method that built this kernel — **understanding before data.** Derek deliberately fed the problem from
every perspective (users' fears/hopes, why they play, the structure from each seat) and **withheld the
data firehose** (saves, sheets, 5 yrs of Discord) so the outcome stayed focused. Data is infinite and
directionless; understanding is compressed and directional — **build the lens first, then point it at the
firehose.** This is also how the absorption engine must ingest: data pulled *through* a schema/lens, never
dumped. The lens is now built → the data can flow (the world-save gallery is the first act of it).*

Do the expensive thing — this kernel — **once**. Then:

> **projection = kernel  +  a person's dataset  +  that person's lens  →  a tailored artifact**

Only the lens and the data change. The audience are brilliant systems-builders, so **every projection
must be rigorous and true in their native language** — never dumbed down.

| Person | Lens | Their dataset | Projection |
|---|---|---|---|
| **Mikers** (Slayer GM) | data / systems | Slayer ranks, Base Weapon Stats | living data view + working rank recipe — **done** (`recipes/rank-ladders/`) |
| **Bruce** (OG creator) | equations / systems dynamics | trust↔scale, regen↔economy, burnout | a **formal systems model** — stocks, flows, feedback loops; the trust-vs-scale curve as math |
| **Mistral** (Rangers GM) | experience / empathy | events, player journeys | an **experience / journey** projection |
| **Stewards / leadership** | metrics / retention | population, AFK-adjusted engagement, staff attrition | a **retention & staff-sustainability** projection |

**The steward/leadership projection is the most delicate:** it is a *restored feedback loop* —
carrying ground-truth engagement (what players actually feel) back up to people who've been deciding
by an AFK-inflated number. It must be **additive, never a gotcha** ("here's a richer read," not "your
metrics lie"). Respect *never a verdict on the past*: the abstraction-away is inevitable, not a
failure. (Bruce's projection can draw the same thing as a systems loop; see `community-insights.md` §15.)

Lock the kernel → point it at any dataset → generate the projection. That is the leverage: the
thinking is paid for once; every conversation after gets a near-free, native, rigorous artifact.
