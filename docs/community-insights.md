# Community & Retention Insights (from conversation notes)

> Synthesized from light raw notes (a conversation incl. **Ibo**, a current player). Qualitative —
> this is the *why* behind the hub and the human requirements, not data. Fragments organized into
> themes; tensions and open questions kept as-is rather than over-resolved.

## 1. The perception gap — "looks sweaty, plays comfy"

- Ibo still plays and wants to recommend Comfy to a friend, but hesitates: the **visible culture
  reads as "sweaty"** (competitive/tryhard), while **most people don't actually play that way.**
- Comfy's real strengths: a **great building server**, **low friction to start**, and you **don't
  need to enter any race/competition** to find a playstyle you enjoy (with room for the sweaty folks too).
- The problem is **discoverability + presentation**: casual/builder players can't easily find each
  other, and the server's public face misrepresents its welcoming reality. Open question: *do those
  players even want to be organized/findable, or is quiet self-selection fine?*
- **Hub implication:** the **guild system is already a playstyle-sorting mechanism** (Builders/
  Hobbits/Rangers ≈ creative/social; Slayers/Mages ≈ combat) — but its discoverability is poor. A
  hub could surface playstyle segments, improve "find your people," and reshape how Comfy presents itself.

## 2. Progression *is* the playstyle ("no one enjoys vanilla")

- The players who stay enjoy **going through the (enhanced) game** — progression itself is the play.
- Validates why the rank/economy/quest systems matter: they **are the product**, not scaffolding.
- **Hub implication:** making progression legible (guild ranks, Best West, events) directly serves
  the core value proposition, not just staff convenience.

## 3. Onboarding = the highest-leverage retention moment

- Recruit via **whitelist**; onboarding should teach **fundamentals** practically, plus *how to learn more*.
- The core respect heuristic, stated newbie-simple: **"Don't touch what isn't yours. Natural-looking
  area? Fine to use. Looks like someone built it? Leave it be."**
- Echoes the Creator-rules rewrite: **radically simplify the newbie-facing layer.**
- **Hub implication:** "make tribal knowledge legible" (personas Option A) + a clean onboarding surface.

## 4. Moderation *behavior* is a retention factor — and a blind spot

- Most players **never interact with GMs directly**; they learn what staff are like **secondhand,
  from other players.** So moderation *behavior/reputation* strongly drives retention.
- **"Who watches the watchers?"** — is there a **feedback loop** on staff/mod behavior, and on
  whether the rules still fit?
- Rules/behaviors may have been **"defined during times of plenty"** — may not fit leaner times or a
  1.0 influx.
- Staff is **perceived as one team even without structured coordination** — perception ≠ structure.
- **Hub implication (delicate):** a neutral shared record could support moderation **consistency**, a
  **feedback loop**, and periodic "do these rules still fit?" review. Sensitive / staff-political —
  handle with care.

## 5. Integrity: cheating & expectation-management

- **Managing expectations is fundamental to immersion**; Creator Events manage expectations at the
  world/instance level (see `governance.md`).
- **Cheating breaks the shared expectation.** "**Cheaters cheat early** if they're going to."
  Detection = look for **deltas / obvious differences** (anomaly detection on progression/resource data).
- **Hub implication:** a cheat-detector is a **sibling to the anti-farming detector** — both are
  *integrity via data* on the game DB. Early-game anomaly detection (impossible progression speed,
  resource/skill spikes) is tractable.

## 6. Bruce's story — the trust-vs-scale curve

- **Era 4:** small; everyone knew everyone.
- **Era 5:** a **great lag fix** → **player explosion** (this is the "10 → hundreds" moment).
- **Era 6:** rules started being **enforced to scale** → **trust nose-dived.** The loss of trust
  came from the growth itself + pressure to keep raising player count.
- In era 6, **in-person whitelisting still happened** — and the shift to a "reading process"
  (checklist) was so quiet that people didn't realize it had changed.
- **Core tension:** *every scale of efficiency removes personalization* → rigidity. "People
  interacting is what makes the community"; being less involved with the playerbase is bad, and a
  "timing structure" removed some of that involvement. There's a **leadership limitation** on how
  much personalization can survive scale.
- **Automation as an ally, done right (Bruce):** full mod integration "prevents players squabbling
  over what piece of loot to give out" — automating friction *frees* humans for connection. Why not
  full mod integration? → to keep the **best level of integration and player experience.**
- **This is the design constraint for any tool** (see `tool-proposal.md`): a tool must **buy back
  the human element** by absorbing mechanical load — not add more efficiency-driven rigidity.

## 7. Safety gap (surfaced via whitelisting)

- A **younger kid reportedly got whitelisted** → "is that a loophole? kids shouldn't be on Discord."
- Uncertainty whether **Comfy is 18+** and what the **"after dark" ruleset** is.
- The whitelisting process is *supposed* to be a human gate that reads who's joining (and captures
  intent, e.g. **PvP opt-in = "if you have it on, you want it"**). When it silently became a
  checklist, that safety read weakened.
- **Implication:** any onboarding/whitelist tooling must treat **age/consent as a first-class gate**
  and preserve the *human read*, not just a form.

## 8. Sources (attribution)

- **Bruce** — long-time **Creator & OG from *before* process/rules.** Culture/trust conscience.
  Motivated by **precision building & creative "shenanigans"** (color-every-pixel, angle/degree
  control, the Obliterator, harpoon + feather-cap, the "skillet method"). His return-to-game hook is
  creative expression.
- **Mikers** — **Slayer GM**; **source of much of the structured data** we ingested (Base Weapon
  Stats, rank ladders, weapon choices). Data-fluent and clearly invested.
- **Mistral** — the **volunteer**, now **Rangers GM** (journey below).

## 9. Mistral's journey (player → rep → GM) & the volunteer's core motivation

- OG Valheim player; asked "what else is there?" (the game hints at more) → found **Comfy** via a
  public server ("comfy#1"). Started **era 6**; *nerded out on the whitelist rules*; went straight
  for guild content.
- Went hard on ranking/guild content **era 6–9** with an active crew; first guild **Slayers (era 6)**
  — close-knit; the small ecosystem meant *the same people every run*.
- **Era 9:** split off, went solo; **bought a Hobbit home at auction** — captivated by the attention
  to detail, and by *seeing gold earned convert into things you use (and things you couldn't make
  yourself)*. **The economy made meaning.**
- Pulled into **Mages** as an early rep for the new content ("we must do the magic stuff").
- Now hosts many events for **Rangers/Explorers** — "empathy with the player perspective; build the
  community you want to be part of."
- **The volunteer's core motivation (important):** *"When you can create anything, having things
  tastes like sand — the joy is in providing the experience."* Less perfectionism, more chilling;
  "not about min-maxing; it's *how can I give back and create an experience.*" Being a GM **mirrors
  the self**; good friends let them be "a version of themselves they liked" — expression + a
  "feedback loop of feedback." Then **process/rules collided with the creative vision.**
- **Implication:** the champion persona is intrinsically driven by **giving others experiences**, not
  accumulation. The tool must *free them to create experiences* — remove bookkeeping, protect
  creative expression. (Also surfaced: confusion about **how many leaders sit in which roles**
  — creator / creator-lead / creator-shop / guild-master — and *"what are they balancing?"*)

## 10. The server's current state — sobering, and it raises the stakes

- **Population is low now; the formula is stale** — *"everything locked in its final shape at
  era 5."* Peak population was **era 8–9**. AFK inflates engagement numbers. **Stewards hold the metrics.**
- **Staff are burning out and leaving** — and *staff define how people engage with Comfy*, so
  **retaining staff is existential.** In their words, the tooling **"needs to be an extension"** of
  the staff.
- **"Ranking — the process is so heavy it comes at the cost of building the relationship."** The
  rank-processing toil is literally crowding out the human connection that is the point. **← direct
  validation of labor-first, from the GMs themselves.**
- **Drift to solo play** ("it's gone to a solo player game") makes community-building harder
  (connects to the anti-farming solo caps).
- **Cross-guild collaboration was never incentivized** — a real gap (and the *founding vision* named
  cross-guild collaboration).
- **Systemic coupling:** "regen affects the global economy → hard to change the rules that define
  them." Rigid, entangled systems.
- **Active-player requirement:** "if you're not an active player, retire — it's easy to know what
  players think by being a player." Staff empathy depends on staying a player (echoes Bruce).

## Stakes (updated)

This is no longer only "get GMs excited." It's **revitalization.** The root causes the GMs named —
**burnout, a stale formula frozen at era 5, and heavy process crowding out relationships** — are
*exactly* what a zero-lift, "extension-of-self" tool addresses, and the **1.0 wave is the window.**

## 11. Mistral's private Discord — the manual MVP (and the product spec)

Mistral couldn't trust the general docs — they kept **drifting** — so they built their **own private
Discord** as a personal source of truth: copied docs when they saw them, kept their own quest notes,
**sorted it their own way so they could always search and find it.**

This is not a workaround. **It is the product spec, written by a user, by hand.** Two precise lessons:

1. **People trust their *own* organized capture, not a central doc.** The central doc fails not only
   because it drifts, but because it **isn't theirs.** So what we build must feel **owned** (the way
   Mistral's channel is), not a mandated central truth. (Confirms *owner-controlled / standardize the
   plumbing not the content* — from a real user's instinct.)
2. **The labor is the enemy, not the method.** Mistral's method is right; the cost is hand-copying
   every changed doc forever. **Keep the method — their organization, control, searchable truth — and
   automate the collection.** Take the brilliance, remove the toil.

**The human note:** Derek gently observed this was "a behavior trained outside the game"; Mistral:
"yeah, I'm fun at parties." It's a **survival adaptation** — someone let down by unreliable sources
who decided *never again, I'll keep my own.* The tool must **honor** that, never pathologize it: make
the coping lighter, and turn a solitary act of self-protection into something that can help the next
person too — **without ever removing the control that makes it feel safe.** We're not fixing broken
toys; we're building them better shelves for what they've learned to protect.

## 12. The basement-bot chokepoint — why we build *no bot*

The bots that actually run Comfy and hold **ultimate access to all the data live in the basements of
~2 long-term stewards.** Every change must be requested and approved by them. Mistral hinted this is
**"the real blocker of getting anything done"** — the ecosystem's power structure made *infrastructural*.

This decodes Mistral's "I don't trust [an AI-built bot]": **a bot is a basement waiting to happen.**
Building "a bot to fix it" reproduces the exact chokepoint. So:

- **We build no bot. We have no basement. No one holds ultimate access.** Decentralized, locally-run,
  plain owned files. We **interoperate** with the existing guild bots (emit the paste-strings members
  use) without **becoming** one.
- **No approval bottleneck:** you change your own tools without asking a gatekeeper.
- **Portable & owned:** Mistral **lost their whole archive when they lost Discord access** and rebuilt
  it by hand. The source of truth cannot live inside a platform (or a gatekeeper's bot) you can be cut
  off from. Plain owned files survive access loss — and a recipe regenerates them in minutes. *That* is
  the real answer to "I had to rebuild it all again," not a bot.
- **Adoption bonus:** no basement = no gatekeeper blessing needed to adopt or change → Mistral/Mikers
  can start without the basement stewards' approval. The design *is* the go-to-market.
- Framed structurally, not as blame: the basement bots likely began as generosity and *became* a
  chokepoint — the same *skill-that-got-promoted ≠ skill-to-maintain* physics.

## 13. Bruce's vision — let people build their own mods/integrations

Asked what would get him back, Bruce: the old "no mods" rule existed to grow the playerbase (mods
scared people off); but **mods are prolific now**, so — *why not let people build their own?* Guilds
would have their **own user-built Valheim integrations/tools**, the community would be more engaged,
and everyone would have better tools. **That is our thesis in Bruce's own words** — decentralized,
user-owned tooling. Bruce isn't someone to convince; he already described the un-basemented world. His
projection just has to show it made real.

## 14. The officer paradox, the pillars, and "the tool holds the world, the human holds the story"

**The officer paradox.** Comfy's magic is *humans curating the experience of the layer below them —
managing expectations above immersion* (a DM for players, a creative lead for creators, a GM for
members). It works up the stack and **breaks at the top: no one curates the curators.** The moment
you're an officer, the invisible hand that kept it a game for you lets go → it becomes a job. This is
the **mechanism** of burnout: you lose the exact thing that made it magic, right as you start
providing it to everyone below.

**Condensation of the pillars = the worst thing that happened.** There used to be separate pillars —
a **creative sector** and **guild GMs** — with different recruitment, hierarchy, and reward
structures, that *collaborated*. Crucially, this let you **be a leader without knowing everything**
(not all leaders needed to know everything). Standardization **condensed** them into one hierarchy →
forced omniscience → the tribal-knowledge tax + burnout. **The absorption engine is the antidote:**
knowledge in an owned, searchable source of truth makes it **safe to specialize again** — you can be
a creative lead who doesn't carry guild minutiae because it's *captured*, not memorized. It gives back
the pillars.

**Capturing the creative essence — without automating it.** The tension: let creative players express
(home worlds, any mods, throw lightning like Thor) *without* breaking the coherent, managed world the
vanilla player relies on (no chaos where nobody knows "what rule system exists"). Derek floated a
"judgment tool" (validate a creation is runnable) then correctly caught himself — the **best**
experiences are **player-run events where an invisible human is a god/DM**: spawning creatures,
weaving a storyline, managing challenges live (D&D at game level, with a playerbase that would never
normally do that). **Resolution — the tool holds the world; the human holds the story:**
- **Human (sacred, never automated):** the live storytelling / god-mode event.
- **Tool (the friction around it):** a **coherence gate** (a creation fits the tier/rules/balance →
  runnable → the managed ecosystem stays coherent); **scaffolding** to run it; and **memory** — the
  absorption engine captures the storyline/encounter/lore so the creativity is preserved, appreciable
  by others, and repeatable without being flattened into automation.

This is essentially the **revitalization + democratization of the Creator pillar**, and it's the same
dream as Bruce's "let people build their own" (§13). Candidate recipes it implies: a *coherence/
judgment* recipe and an *event-capture* recipe. (Now a kernel invariant: "never automate the human
magic.")

## 15. The vanity-metric trap — why good ideas died, and the broken feedback loop

- **Good fixes died because they dented the count.** Example: spinning out another world (or splitting
  by timezone) obviously cuts lag and improves experience — but leadership resisted: *"you're taking
  away from the player count."* The metric was protected over the experience.
- **Goodhart:** "active players online" and "max-skill achievements" *became the target*, so they
  stopped being a measure. And they're **AFK-inflated** — someone parked next to an auto-farm counts
  as "active" — so the number stays healthy while real engagement rots. The decline is real; the
  dashboard hides it. No alarm fires.
- **Ground truth exists but can't get up.** Players already know the real state; there's no channel
  carrying that to the abstracted deciders. Only the hollow number flows upward.
- **The abstraction ladder (inevitable).** You get good at systems/leadership and rise — player →
  creator → GM → steward, each "a DM for the layer below" — abstracting **up, up, up, further from
  being a player, forgetting what it's like.** Not a failure; the cost of rising. It's why the top
  trusts numbers over felt sense.
- **Diagnosis = a broken feedback loop** — the unifying disease under the officer paradox (§14), the
  perception gap (§1), and "if you're not a player, retire" (§10). Bruce earlier asked *"is there even
  a feedback loop for the structure?"* — the answer is **no**, and the vanity metric is what broke it.
- **Design implication:** the steward/leadership **projection** is a *restored feedback loop* (carries
  real engagement up) — the **most politically delicate** artifact: **additive, never a gotcha**
  (respect "never a verdict on the past"). Strong **systems-dynamics content for Bruce's projection**:
  a reinforcing loop where optimizing an AFK-inflated proxy degrades real health while the proxy holds
  flat, and ground truth has no arrow pointing up.

## 16. Celebrate the people, not just the roles — a celebratory feedback loop

Prompted by Derek retelling **who the early players *were as people*** — five years on he still
remembers what they did, what he learned from them, what their passion inspired him to build. It
visibly landed, and Mistral: *"we need to celebrate — not just the roles in the guild, but the other
people and their passion and how they contribute."*

- **Beyond roles.** Rank/role systems can't see the passion and informal contribution that actually
  make the place. Celebration honors what the org chart misses — deeply aligned with the
  broken-toys / belonging ethos (§ throughline).
- **Prior attempts don't fit** (guild awards like "the birds" / "storytellers"). The instinct: a
  **community nomination**, with an **underdog perspective** (a brand-new player can be celebrated).
- **The clever twist — a feedback mechanism.** Publicly everyone votes, all equal. **Behind the
  scenes**, read votes against **voter tenure** — as *patterns, never individuals*:
  - celebrated across all tenures → a **unifying culture-carrier**;
  - a newcomer celebrated by veterans → a **rising star the old guard already sees**;
  - newcomers vs. veterans celebrating different people → the **perception gap made visible**.
- **The inversion (ties to §15):** the opposite of the vanity metric. Player-count = hollow, top-down,
  masks the truth, resented/gamed. Community celebration = a **rich human signal, bottom-up, that
  reveals the truth and is trusted/joyful.** → **Design stance (now in kernel): restore the broken
  feedback loop through *celebration*, not just measurement.**
- **Absorption of human legacy.** Derek *is* the memory of who mattered — precious, and hostage to one
  person (Mistral's private-Discord problem at the scale of the community's soul). The mechanism lets
  the **whole community carry the memory**, so passion is honored even by people who weren't there.
  The absorption engine applied to *people*, not just systems.
- **Alignment & caution:** community holds the story (who to celebrate); the tool holds the mechanism +
  the gentle read. **Public = egalitarian celebration; private tenure read = aggregate patterns only —
  never whose-vote-was-what, never a ranking of people, never deciding the winner** (owner-controlled,
  never surveillance). It informs; it must never weigh one voice over another out loud.
- **Candidate recipe:** *community celebration / nomination* — capture nominations + votes → a public
  celebration artifact + a private tenure-cohort feedback read.

## 17. Unaccountable bans, and the core aim: close the appreciation loop

Asked "what would bring you back / make you recommend Comfy?", the unexpected answer was **the bans.**
Everyone has a story; the powers-that-be can just ban, "it is what it is," **no recourse, subjective,
no documentation.** The pointed question: *"if nothing's hidden and the bans are justified, why isn't
the evidence posted?"* One unproven story poisons trust for everyone.

- **Frustration vs. sadness (the diagnostic).** Others' complaints were *frustration* — bureaucratic
  friction ("a thousand hours building this, then I put the wrong tag in the bot and lost the reward").
  Friction is tooling; it's fixable. But **Ivo — a very happy guy, "the best of humanity" — was *sad*.**
  That's a different signal: not "this is annoying," but "this place isn't who I thought it was." A
  moral wound, not a UX bug. *(Sadness from the happiest person = the deepest alarm.)*
- **Unaccountable bans kill recruitment.** Inviting a friend is **vouching**; you cannot vouch for an
  authority you can't trust to be accountable. Invite a friend → they get banned with no backup → you
  **broke the handshake bond** ("how could I look at them as a friend and say I invited them here?").
  So honest people stop recruiting → the **healthiest growth vector (friends vouching for friends) dies.**
  Accountability = documented reasons + posted evidence + real recourse. *(Most politically charged
  area — challenges unaccountable top power; frame additively, "if there's nothing to hide…".)*

**The crystallization (Derek's deepest sentence):** *"Artists need almost nothing, as long as there's a
feedback mechanism so their art can be appreciated. We need to **close the feedback loop on
appreciation** — then a lot of these problems go away, because they're self-fulfilling: action →
creation → appreciation → choose your own adventure."*

- This is **the whole project in one line** — and has been since the celebration idea (§16). The
  starving artist starves for *being seen*, not money. Close **action → creation → appreciation →
  action** and it self-sustains (appreciation is the only fuel a creator runs on).
- **Everything we built serves this loop:** absorption preserves creation *so it can be appreciated at
  all*; celebration *is* the appreciation loop; ban-accountability removes the *anti-appreciation* (the
  arbitrary "no"); no-basement/owned keeps appreciation from being hoarded or blocked.
- **Reframe: build the loop, not the control.** A closed loop needs no manager — it regenerates itself
  → "choose your own adventure." Ivo's sadness and Mistral's celebration are the same discovery from
  opposite ends: the loop torn open vs. the loop snapping shut. *(Now the kernel's Core aim.)*

## 18. The world-save art gallery — the metaphor becomes a spec (flagship of the Core aim)

**Key correction:** the art was NOT wiped. **Every era's world save is preserved, public, and
loadable** on a private server → build/run your own tools, break no rules (decentralized/owned; cf.
Bruce's "own world" §13). Derek has **already reverse-engineered the save DB with AI agents**
(structure + positions of everything; since the mods are position-driven, custom objects are deducible
by placement). So "a gallery for art that never had one" (§ the grief thread) is **literal and
buildable** — a data pipeline he's most of the way through.

**Why it's the flagship of the Core aim (close the appreciation loop):** it closes the loop for **every
builder across 5 years at once, retroactively, permanently.** The direct answer to the grief ("art
weathered & wiped") — *it wasn't wiped; un-wipe it.* The purest "only gives" artifact: can't hurt
anyone, celebrates everyone, and is genuinely **beautiful** — and beauty is how you get a room of tired
people to look up.

**Pipeline:**
1. **Decode** per-era save → structures/pieces/entities + positions *(done)*.
2. **Highlight detection** = heat-map / clustering on *effort* signals: piece density, build
   volume/height, piece **variety**, unusual geometry, distance from spawn → auto-rank the greatest hits.
3. **Cinematography** = load a save into a private Valheim instance, automated camera flythroughs of top
   regions → highlight reels + stills.
4. **Gallery** = permanent/public, browse by era / biome / builder.

**Make-it-sing question — attribution.** Can a build be tied to a *person* (ward ownership? base-position
cross-ref? any records)? → then appreciation lands on a **name** ("Mikers's cathedral, Era 12") = the
loop closing to the individual.

**Proof-of-concept (don't need all 5 years):** one era, one decoded save, one heat-map, one flythrough
of the single most impressive build = a reel that fires the appreciation loop **on sight**. Candidate
recipe: **world-save gallery**. (This machine has the RAM; needs the save files + decoder moved here.)

## 19. llmquest — the delivery model already exists (the bottom half of the stack)

Derek's prior repo **`github.com/djcdevelopment/llmquest`** is the *bottom half of the stack we designed
tonight, already shipped.* A **gamified WoW-style questline** (8 quests) that teaches ex-gamers to run a
**local LLM (Ollama)** and bind a **personal Discord bot** ("the Kid") they run on their own machine,
fed their own data — offline and free.

- **Thesis, verbatim:** *"the same loop — data in, engine runs, data out — except this time you own the
  engine."* = own-the-engine / decentralized / no-basement, written before we had the words.
- It already embodies: local-LLM + **Discord as control surface** + free/offline; **$20/web fallback**
  ("whisper to Claude if stuck"); **meet-them-where-they-are** (gamers' native progression loop);
  **use/create/repair** (Quest 8 = "deploy and maintain"); a **learning appreciation loop** (completion
  badges / Trophy Wall).
- **The stack is now whole:** **llmquest = the platform** (get an owned local LLM + Discord control
  surface); **our recipes = the applications** (rank ladder, world-save gallery); the **local LLM the
  person sets up = the agent that drives the recipes.** The framework isn't a new project — it's
  **"Quest 9, 10, 11"** of a questline already released.
- **Refines "no bot":** the line is **basement, not bot.** "The Kid" is a bot — but owned, local,
  self-hosted, LLM-driven = a control surface (good). The anti-pattern is the centralized ultimate-
  access basement bot (§12). *(Now in kernel invariants.)*
- **The Mikers reframe:** "only one person followed it" is **not** weak adoption — the one was **Mikers**,
  who came out with the two foundational skills (Discord-as-control-surface, local-LLM cheap/free) and
  "will run tutorials." So the rank recipe is the **next quest for a graduate already attuned** (he can
  run *and build*). **The flywheel already turned once, for real, before it was designed.** n=1, and the
  1 is exactly the right soil. Validates the whole adoption strategy (§ adoption): deep germination in
  the right champion > broad shallow reach.

## 20. The appreciation loop already exists — "Hall of Fame" + Raevyxn's master sheet

While browsing the Comfy Discord ("massive massive amounts of content"), Derek stumbled on gold. Raw
landed: `data/raw/discord-found-sheet.csv` (+ two Google Forms, read below).

- **"Hall of Fame Era 16 - Voting" (Google Form) = THE APPRECIATION LOOP, ALREADY RUNNING.** The
  community *already* gathers, visits each other's builds in a world, and **votes their top-3 favorites.**
  We never needed to *introduce* the celebration/gallery/appreciation loop — **it exists as a live
  practice with buy-in.** It just doesn't *close* (votes go in, get tallied, then evaporate each era).
- **The flagship gallery is now assembly, not invention.** Pieces already exist:
  - **era-16 save file** (Derek found it) → the builds, frozen, loadable;
  - **Hall of Fame votes** → the community *already curated the highlights by hand* (partly solves
    "highlight detection" — real human taste, not just a heat-map);
  - **the voting form** (Discord names + ranked votes) → **Mistral's tenure-enrichment target, ready-made**
    ("do newcomers and veterans agree?" on real data).
  → Un-wipe era-16 builds, showcase the Hall of Fame winners *with names*, close the loop the votes
  were reaching for. Not a moonshot — connecting four things that already exist.
- **Raevyxn's Era 16 master sheet = a THIRD Mistral** (after Mistral's Discord, Mikers's ladders): another
  volunteer who built their own trusted source of truth because content drifts + scatters. The pattern is
  an **epidemic of personal rafts with no harbor.** And it's rich — it revealed our rank model is only the
  *skeleton*: **initiation gates** (Mage's "Offering to Goddess Freyja," Slayer's Training Course), a whole
  **reward dimension** (private quarters that grow with rank, boss stones, 10x crafting stations, named
  achievements like "Runemaster"/"Ring Bearer"), and **more ranks** (Explorer Nomad, Pathfinder). We had the
  *requirements* to climb; Raevyxn had the *reasons.* (Captured in `data/reference/guild-rank-ladders.yaml`
  → `enrichment`.) Each guild also links its own **quest/rank tracker** = more absorption targets.
- **Second form = "Claim your portal in the UP portal hub"** — the Nexus/portal subsystem as a **rep-toil
  workflow** (pick a portal number, custom HTML sign, "a volunteer will implement changes after submission").
  Prime candidate for streamlining.
- **The meta-point (the absorption engine's whole justification):** *"massive amounts of content… I stumbled
  across these."* The treasure isn't missing — it's **buried, and found only by luck.** How many Raevyxn
  sheets will *never* be stumbled across? The tool turns **stumbling into searching.**

## Throughline (broadened)

Earlier framing "make fairness measurable" widens to **"protect a shared, fair, immersive
experience"** — spanning the hard side (balance, anti-farming, anti-cheat) *and* the soft side
(welcoming culture, good moderation, well-matched playstyles).

## New axes this adds to the model

- **Playstyle axis** (casual/builder ↔ competitive) — distinct from guild membership, though correlated.
- **Retention/experience** as an explicit design concern (onboarding, moderation quality, feedback loops).
- **Integrity / anti-cheat** as a hub capability (sibling to anti-farming).

## Open questions

1. Do casual/builder players **want** to be organized & discoverable, or is self-selection fine?
2. Is there appetite for a **moderation feedback loop / staff-consistency** aid? (sensitive)
3. What **game-DB signals** exist for early cheating deltas (progression speed, resource/skill spikes)?
