# Comfy — Personas & Org (from the Roles & Responsibilities chart)

> Working document. Rebuilt from the official **Comfy Roles & Responsibilities**
> chart. This captures *who and what the integration hub sits between* before we
> design any schema or connectors.
>
> Two things to keep straight:
> 1. **This chart is the STAFF ORG** — organized around *subsystems* (Nexus, Best
>    West, Guilds, Creator, Whitelisting, Economy, Dev, Moderation), not around the
>    member guilds (Slayer's / Rangers / Merchants) mentioned at kickoff. Those are a
>    **separate axis** the hub still needs. See §4.
> 2. Almost every role is defined by **a piece of data it processes.** That data set
>    is the hub's ingestion surface. Each role below is annotated with its
>    **▸ data touchpoint.**
>
> Stack: **Python**. Access: game-server files/DB + VPS. Reachable data today:
> existing bots + spreadsheets (+ game DB). No direct Discord bot yet.

---

## 1. Tiers (chart key)

| Tier | Meaning |
|---|---|
| **Admin** | Top-level oversight (Comfy Steward). |
| **Senior Staff** | Subsystem owners; each oversees a team of reps. |
| **Mid-Level** | Skilled workers (Creator, Creator Shop Rep, Mod Tester, Comfy Rep). |
| **Entry-Level** | Front-line reps (Nexus/Best West/Guild Rep, Whitelister). |
| **Non-Staff** | Members & volunteers the system serves. |

---

## 2. Staff hierarchy

### Comfy Steward — *Admin*
Keeps Comfy running smoothly; macroscopic view over everything.
▸ **Data touchpoint:** consumer of the whole cross-subsystem picture — the hub's #1 dashboard user.

### Senior Staff (subsystem owners) → their workers

- **Nexus Keeper** — oversees Nexus Reps & creative direction of the Nexus (mass portal hub).
  - **Nexus Rep** *(Entry)* — helps run the Nexus by processing **portal requests**.
  - ▸ portal request queue, portal/hub registry.

- **Best West Manager** — oversees Best West Reps & the staff-run newbie establishment, Best West.
  - **Best West Rep** *(Entry)* — processes **quest turn-ins, rewards**, provides temporary newbie housing.
  - ▸ quest turn-in log, reward payouts, newbie housing assignments.

- **Guild Master** — oversees Guild Reps & creative direction of the guild(s).
  - **Guild Rep** *(Entry)* — processes **turn-ins, rewards, rank-ups**, runs events.
  - ▸ guild rosters, rank-up ledger, turn-ins, event log. **(ties to §4)**

- **Creator Lead** — oversees Creators & the Creator Shop; manages Creator event policies & reward guidelines.
  - **Creator** *(Mid)* — creates unique **events (dungeons), auction lots, and builds**.
  - **Creator Shop Rep** *(Mid)* — runs the Creator Shop: **purchases and buybacks**.
  - ▸ creator event catalog, auction lots, shop transactions (purchases/buybacks), builds registry.

- **Coordinator** — marketing, organization, training resources, graphic design (server + social).
  - ▸ training/resource library, social/marketing assets. (Mostly content, not transactional data.)

- **Dev** — writes/breaks/distributes code; manages server stability & health; **approves new mods**.
  - **Mod Tester** *(Mid)* — assists Devs with **testing mods**.
  - ▸ mod approval list, server health/stability metrics, deploy/version history.

- **Balance Strategist** — reviews all balancing discussions incl. Guild, Best West, Creator, and **General Economy**.
  - ▸ *cross-cutting economy consumer* — needs aggregated data from every transactional subsystem. Strong hub beneficiary.

- **Moderator** — resolves **tickets**, moderates the playerbase.
  - ▸ ticket/moderation log.

- **Comfy Rep Manager** — oversees Comfy Reps & in-game resource regeneration.
  - **Comfy Rep** *(Mid)* — handles **in-game resource regeneration**.
  - ▸ resource-regen requests/log.

- **Whitelist Manager** — direction & oversight of the Whitelisting Team for a courteous, consistent new-player experience.
  - **Whitelister** *(Entry)* — handles **whitelisting** and brief intro to the server.
  - ▸ whitelist entries, new-player intake — the front door for the expected 1.0 wave.

---

## 3. Non-Staff personas (who the system serves)

- **Whitelisted Gamer** — the everyday player. The base unit of "member."
- **Patron** — donor of Comfy.
- **Guild Ambassador** — non-staff volunteer, answers guild-specific questions.
- **Mentor** — non-staff volunteer, answers general questions.

▸ These are the identities all the subsystem data ultimately attaches to. "Member" in the
canonical model = a person who may simultaneously be a Whitelisted Gamer, a Patron, hold a
staff role, and belong to one or more member-guilds.

---

## 4. Member guilds — **CONFIRMED (7)** *(source: New Player Guide)*

Seven official, staff-run guilds. A player may join any number; **max rank in 3+ guilds
earns an Odin Hood.** Membership = a self-assigned **Discord role** (react to an emote in
`#comfy-roles`). Each guild has its own news/info/chat/turn-in/requests channels.

| Guild | Charter | Member tag | Rep tag | Turn-in channel(s) |
|---|---|---|---|---|
| **Slayers** | heroic fighters/rescuers; combat skill | @Slayer | @SlayerRep | Contract Turn-In, Summon Turn-In |
| **Merchants** | trade; buy/sell, gold, shop mgmt | @Merchant | @MerchantRep | Token Turn-In |
| **Builders** | classes, builder races, commissions | @Builder | @BuilderRep | Point Tracker |
| **Rangers** | nature/field-service, mini-games | @Ranger | @RangerRep | Ranger Submissions |
| **Explorers** | territory discovery, stashes, races | @Explorer | @ExplorerRep | Explorer Turn-In, Stash-Creation |
| **Hobbits** | roleplay → earn a Hobbit Home | @Hobbit | @HobbitRep | Hobbit Turn-In |
| **Mages** | magic-themed tasks/events | @Mage | @MageRep | Mage Submissions |

- The staff chart's **Guild Master → Guild Rep** is the generic spine; each guild *also* has
  its own **@\<Guild\>Rep** staff and (per §6) its own submission **bot**.
- Guilds run **Hosted Events** (scheduled, on the Discord Event Calendar) and **World Events**
  (staff-designed dungeons; some tied to the Creator Team — Hobbits & Rangers — others solo —
  Mages & Slayers).
- **[still need]** Per-guild internal **rank ladders** (names/thresholds). Referenced everywhere
  ("rank-ups", "top rank") but not enumerated in these docs — likely in each guild's own sheet. (Ranks 1–3 now captured — see §5a.)
- **Known GMs / data sources:** Slayers → **Mikers** (also the source of most ingested data —
  Base Weapon Stats, rank ladders, weapon choices; data-fluent → natural first beachhead).
  Rangers → **Mistral** (the volunteer champion; player → Mage rep → Rangers GM). **Bruce** is a
  long-time Creator/OG from before the rules era. Open: role-count complexity — how many leaders sit
  across creator / creator-lead / creator-shop / guild-master, and *"what are they balancing?"*

---

## 5. Eras — **CONFIRMED** *(source: New Player Guide)*

> "We reset our seed periodically; a period on the same seed is referred to as an **Era**,"
> typically lasting **3–5 months.**

- **Currently Era 16**, launched **Nov 15, 2025**. Eras are sequentially numbered epochs.
- Canonical model: key all time-series/transactional data by **era number (+ world seed)**.
  Identity, roles, and guild membership are scoped within an era.
- New-era ramp is itself modeled: first 24h only Directional/Prestige/Best West portals are
  connected at Spawn; Creator Shop opens Week 3. Useful for time-aware views.

---

## 5a. Ranks, roles & the volunteer hierarchy — a distinct axis the hub must disentangle

Everything at Comfy is run by **volunteers**, and "rank/role" is not one field — it's at least
**five concepts that Discord flattens into a single role list** on each member:

1. **Staff position** (org chart §1–2): Comfy Steward → Senior Staff (Guild Master, Nexus Keeper,
   Creator Lead, Dev…) → Mid/Entry reps. A volunteer *responsibility* ladder.
2. **Guild membership** (§4): `@Slayer`, `@Merchant`… — which guild(s) you belong to.
3. **Guild rank** (per guild): the "rank-up → max rank" ladder. **Not in these docs** — line 149
   of the guide says rank ladders live as **graphics in each guild's own channels, at guild
   discretion, and drift out of sync.** Least-structured data we've found.
4. **Helper roles** outside the staff tree: `@Mentor`, Guild Ambassador — non-staff volunteers.
5. **Self-assigned notification roles**: `@Events`, `@News` — opt-in pings, *not rank at all*.

A single member's Discord roles encode all five at once. **The hub's job is to disentangle one
flat role list into distinct, era-scoped facts:** `StaffPosition`, `GuildMembership`, `GuildRank`,
`HelperRole`, `NotificationPref` — each with its own history.

**Docs coverage:**
- ✅ Role *tags* (the `@`-mentions) + self-assign mechanism (`#comfy-roles` emotes).
- ✅ Server staff *tiers* (org chart).
- ❌ Consolidated **Discord role/permission ordering** (Discord has a flat position+permission
   list; the *semantic* reporting tree lives only in the org chart).
- ❌ **Per-guild rank ladders** (names/thresholds) — deferred to guild-channel graphics.
- ❌ **Volunteer progression** (how one rises Rep → Senior Staff) — institutional knowledge that
   erodes across leadership changes & eras. *This is the hub's founding motivation.*

**Reconstructing "who holds what rank" requires joining three partial sources:** Discord roles
(mechanism) + org chart (staff semantics) + guild rank graphics (ladders). None is complete alone.
Preserving this join *across eras* is arguably the single most valuable thing the hub can do.

**[need]**
- Is **"Guild Master"** one server-wide role over all 7 guilds, or one **per guild**? Same for
  **"Steward"** — one person or a council? (Your plural phrasing suggests per-guild/multiple; the
  chart shows singular.)
- Behind the guild **rank graphics**, is there any structured source (a sheet, or the guild bot's
  DB), or is the image the only record of the ladder?

**Captured so far:** **ranks 1–3 for all 7 guilds** — transcribed from *user-made*
flowcharts (by a member who later became a Guild Master) into
`data/reference/guild-rank-ladders.yaml`. Confirms three things: (a) rank ladders are **real,
per-guild, and wildly heterogeneous** (contracts vs. wholesale vs. **real-life badges** vs.
"the Harrowing"); (b) the authoritative record is **user-authored and informal**, not a system
of record — the diagram had to be reverse-engineered by hand; (c) a "GuildRank" is a *workflow*
(ordered steps → rank, sometimes + bonus), era-scoped. Entry ranks: Slayer→Thrall,
Merchant→Peddler, Builder→Mason, Ranger→Scout, Explorer→Drifter, Hobbit→Traveller, Mage→Apprentice
and a per-tier **material tribute**. Ranks captured (ladders extend past 3):

| Guild | Rank 1 | Rank 2 | Rank 3 |
|---|---|---|---|
| Slayer | Thrall | Thegn | Jarl |
| Merchant | Peddler | Vendor | Exalted |
| Builder | Mason | Contractor | Architect |
| Ranger | Scout | Trailblazer | Warden |
| Explorer | Drifter | Wanderer | Strider |
| Hobbit | Traveller | Harvester | Dweller |
| Mage | Apprentice | Enchanter | Archmage |

---

## 6. What this buys us (integration surface)

Every ▸ above is a candidate **data source**. Grouped by how transactional they are:

- **Transactional ledgers** (highest hub value): Nexus portal requests, Best West quest
  turn-ins/rewards, Guild turn-ins/rank-ups, Creator Shop purchases/buybacks, auction lots,
  Comfy Rep resource-regen, whitelist intake, mod tickets.
- **Registries / rosters**: guild membership, portal/hub registry, mod approval list, builds.
- **Cross-cutting consumers** (want *aggregates*, best served by a hub): Comfy Steward (all),
  Balance Strategist (economy across subsystems).

### 6a. Where the data actually lives — **CONFIRMED** *(source: New Player Guide + BW sheet)*

**The bots are the ledgers.** Structured submissions flow through **Discord slash-command bots**
into bot databases:

- **Best West bot** — `/bestwest submit_quest quest_name:… quest_box: image:` and
  `/bestwest submit_contract …`. The BW quest sheet enumerates the full quest ladder + reward per
  quest (see `data/raw/new-player-sheet.csv`; a candidate to normalize like the weapons sheet).
- **Per-guild bots** — Slayers, Merchants, Rangers, Explorers, Hobbits, Mages each have a bot
  (`/help` lists commands; e.g. ComfyHobbit). Each guild also maintains a **sheet** of copy-paste
  command strings → those sheets are a secondary structured source.
- **Reaching bot data** is the key access question (§7): bot DB file on the VPS? export? Discord
  Interactions API? This decides which connectors are real now vs. stubbed.

**Economy / shops** (feed the Balance Strategist's cross-subsystem view):

| Shop | Run by | Currency | Notes |
|---|---|---|---|
| Comfy Trader | Merchants | gold | Haldor/Hildir/Bog Witch; metal delivery; opens each era at Merchant HQ |
| Creator Shop | Creator Leads | **blue mushrooms** (from Creator Events) | opens Week 3 |
| Builder Shop | Builders | — | stonecutter delivery, space islands/farms |
| Bees N' Trees | Rangers | items ↔ bees | vegetation services |

Plus the **weapons economy/balance** sheet already ingested (`data/processed/weapons-economy-balance.json`).

---

## 7. Open questions for Derek

1. ~~Guild axis~~ — **answered** (§4: 7 guilds). Remaining: per-guild **rank ladders**.
2. ~~Where does data live~~ — **largely answered** (§6a: bots + guild sheets). The sharp remaining
   question: **how do we read the bot databases?** (DB file on the VPS / export / Discord API?)
   That single answer promotes the first connector from stub to real.
3. **First beneficiary** — my read is the **Comfy Steward** or **Balance Strategist** get the most
   from a hub first, since both need cross-subsystem aggregates nobody can assemble by hand. Agree,
   or is there a more painful day-to-day (e.g. whitelisting for the 1.0 wave)?
