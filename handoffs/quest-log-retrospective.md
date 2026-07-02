# Retrospective — the player quest log slice (v0.2.0 → v0.6.0)

One session. Start state: a proven rank-proof loop (F7 → screenshot → outbox → review
inbox → copy-paste command) and a repo full of understanding. End state: a player picks
from 188 real guild quests on a local page, sees them in an in-game quest log, and the
game itself captures the proof — first punch and killing blow — into the same reviewed,
exported, human-judged pipeline. Nothing hosted. Every artifact a file on someone's disk.

## What got built, in order

1. **Landed the real sources.** The Slayer guild's operational tracker (49 tabs, eras
   2–17), the Ranger tracker (13 tabs), and the guild handbook — pulled from the live
   sheets, untouched, with provenance (`data/raw/SOURCES.md`).
2. **The quest-catalog recipe** (`recipes/quest-catalogs/`): a schema, a configurator
   (`sources.json`), adapters per source shape, a validator, and an **anomalies report**
   per harvest. Slayers: 103 quests. Rangers: 85, including real-life badges.
3. **The picker** — one self-contained HTML page, both catalogs embedded, works from
   file://. A design pass ("Faceted Codex") gave it a filter rail, evidence facets, and
   save gating. Output: `quest-view.json`, the per-player dataset.
4. **The mod, four increments:**
   - v0.3.0 — quest view loads in-game; Quest Log in the F7 panel; per-quest capture
     through the existing submission pipeline; panel frees the cursor and blocks
     attack input (the Tab-dance died here).
   - v0.4.0 — **auto-capture**: a trigger spec per quest; guarded hooks on the damage
     paths; punch a bush and the evidence captures itself.
   - v0.5.0 — **kill sequences**: creature/skill/projectile filters, two-shot
     `on_first_hit → on_death` capture bound to the specific creature, multi-image
     payloads, bridge export listing attachment order.
   - v0.6.0 — **the Ledger panel**: a second design pass (this one handed constraints
     first — no emoji, flat colors, one serif) translated into design tokens, a
     geometric marker language, live trigger states, receipt strips, empty/error states.
5. **Bridge extensions** that stayed backward compatible throughout: `quest_proof`
   submissions, verbatim turn-in command export, multi-image attachment lists. Old
   rank-proof payloads pass every regression untouched.

## What the method did

**Real data first paid immediately.** The harvester's first pass over the live Slayer
sheet found bugs the guild presumably doesn't know it has: turn-in commands that credit
the wrong quest (Rare Killer → Misty Meat, Full House → Death from Above, three Build
quests → "Dedication"), a misspelled command, and two quests whose commands still carry
their pre-rename names. The anomaly report — *flag, never fix* — turned ingestion into a
gift for the GMs on day one. The tool's pitch made itself.

**The fork test was honest because reality was messy.** The Rangers didn't hand us a
filled template; they handed us a differently-shaped sheet (sectioned badges, a `shared`
marker, narrative quests with rewards folded into cells, an IRL section). The schema
survived with three additive fields and one raised limit. Everything downstream of the
adapter seam — validator, picker, mod — needed zero changes. That was the architectural
bet, and it held.

**Increment by testable deed.** Punchwood ("punch a bush, unarmed") existed so a human
could prove the trigger machinery on an empty world in thirty seconds. Neck Romancer
exists to prove kill sequences the same way. Each real capability got a smoke-test quest
sized to the capability, and the flagship (Air Drop — thrown-spear Deathsquito kill,
two shots) is now a one-line trigger spec away, testable via `devcommands spawn`.

**Constraints-first design prompts work.** The first design pass (picker) invented data
we don't have — zones, effort tiers, typed rewards — because nothing told it not to.
The second prompt led with the rendering constraints and the real JSON, and demanded
unbuildable wishes come back as explicit "data asks" instead of drawings. The result
translated to code in one sitting, and the data asks became an honest backlog.

**The human stayed where the human belongs.** Auto-capture collects evidence; it never
submits judgment. Review, acceptance, and the paste into Discord remain a person. The
39 staff-event/link quests and 14 IRL badges will *never* auto-capture — by design,
not by limitation.

## What surprised us

- **The guilds' power users had already normalized the data.** The "Summons list for
  bot" tab was five clean columns — better than anything we'd have asked them to fill
  out. The absorption engine's job is often just to *find* the structure people already
  built and give it consequences.
- **The evidence emoji were a grammar.** 📸📸/🎞️/🔗/🤜🤛 parsed into a machine-readable
  evidence spec that now drives the picker facets, the panel markers, and the multi-shot
  capture design. The guilds encoded requirements more precisely than they knew.
- **The mouse was the hardest part of Valheim.** The entire trigger system went in
  smoothly; the thing that actually blocked a human was the game's cursor capture.
  User-tests on real hands find these instantly; code review never would have.

## Debts and risks, plainly

- **Kill confirmation is client-simulation-bound.** Solid solo/local; a group kill
  simulated by another peer may not confirm the sequence. Known, documented, manual
  capture as fallback. The fix (watching death via ZDO state) is understood but not built.
- **The panel is IMGUI wearing uGUI's design.** Semantics and tokens match the design;
  the chrome is still Unity-default. The Jötunn port is now a pure reskin.
- **Review status doesn't round-trip.** The player sees "awaiting review" forever; the
  GM's accept/reject lives on the GM's disk. The file-shaped fix (an exported status
  file the player drops in) fits the ethos and is queued.
- **Trigger authoring is by hand.** No harvester emits triggers; each is authored
  per-quest. Fine at this scale; a real catalog of trigger specs is GM-collaboration
  work, not code work.
- **The anomaly rulings are still open.** 21 Slayer + 1 Ranger flags await a GM's
  verdict. The report is only a gift if someone unwraps it.

## Next, in likely order

1. Air Drop's real trigger — the flagship demo, zero new machinery.
2. Anomaly rulings + the contracts/bounties tabs from Mikers; a Ranger pass with Mistral.
3. Receipt counting ("2 captured this era") from local receipts — cheap, real.
4. Review-status round-trip (file-shaped, no server).
5. Jötunn uGUI reskin of the Ledger panel.
6. New trigger events by bucket value: damage thresholds, item-stand mounts, position.

## The principles, kept

Local files first. No bot, no basement. Interoperate with the existing bots by emitting
their own commands verbatim. Standardize the plumbing, never the content — every quest
name, requirement, and typo passed through untouched, and the typos were *reported*,
not repaired. The tool holds the world; the human holds the story.
