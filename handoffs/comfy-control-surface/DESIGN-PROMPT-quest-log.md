# Design prompt — in-game Quest Log panel (Valheim mod)

Copy-paste everything below the line into the design tool.

---

Design the in-game **Quest Log panel** for a Valheim mod. This is NOT a web page — it
renders inside the game with Unity UI, over live gameplay. Read the constraints first;
a beautiful design that violates them is unusable to me.

## What this thing is

Players of a modded Valheim community server pick guild quests on an out-of-game web
page, which produces a local file. In-game, pressing F7 opens a small overlay panel:
Home → **Quest Log** shows the quests they picked. Each quest can capture screenshot
proof: some quests capture **automatically** the moment the player performs the deed
(e.g. "punch a tree unarmed" fires the camera on the punch); the rest have a manual
**Capture** button. Submissions are reviewed later by a human guild master — the panel
is only: *see my quests, read what they require, capture proof, get a receipt.*

## Hard rendering constraints (Unity uGUI + Jötunn, Valheim's mod UI stack)

- **No HTML, no CSS, no web fonts.** Available primitives: rectangles/panels (flat
  color or a wood/parchment 9-slice texture, adjustable opacity), borders, text,
  buttons, checkboxes, scroll views, simple sprites.
- **Typography:** one Norse-style serif family (the game's own — think "AveriaSerifLibre"),
  usable at roughly 3–4 sizes (12–22px at 1080p), bold available. Rich text color tags
  work (per-word coloring is fine). No letter-spacing tricks, no font mixing.
- **NO EMOJI.** The game font has none. Evidence/status markers must be plain text
  tags, single ASCII glyphs, or tiny geometric shapes (dots, diamonds, squares) in
  flat colors — those are implementable as sprites.
- **Effects:** flat colors and opacity only. No gradients, no blur/glassmorphism, no
  drop shadows beyond a simple 1px dark edge, no animations beyond instant hover/press
  tint. Rounded corners only if subtle (comes from the 9-slice texture).
- **It's an overlay over gameplay.** Semi-opaque dark panel, readable over snow, night,
  and fire. Draggable window, NOT fullscreen: target ~420×560px at 1080p, min 360×420.
  The player is standing in the world while using it — respect their view.
- **Input:** mouse (cursor is freed while open), hover states available, click targets
  ≥ 28px tall, mouse-wheel scrolling. No hover-only information (controller support
  later). Esc/Close button closes.
- **Aesthetic:** match Valheim's vanilla UI — dark wood/leather panels, parchment-tan
  text (#e8ddc8-ish), muted gold accents, restrained. Look at the vanilla skills or
  trophy screens for tone. It should feel like the game shipped it, not like a website
  landed in it.

## The data each quest row has (all of it real, from guild sheets)

```json
{
  "name": "Air Drop",
  "guild": "Slayers",            // or "Rangers" — 2 guilds now, up to 7 later
  "category": "General summons",
  "requirements": "Kill a Deathsquito with a thrown Spear\n(2 screenshots: holding the spear, then the kill)",
  "reward": "1 Queen Bee",        // often null
  "evidence": { "screenshots": 2, "video_alternative": true, "link": false, "group_turnin": false },
  "evidence_note": "Screenshot of finished display",   // often null
  "trigger": { "event": "hit" },  // non-null = AUTO-CAPTURE quest
  "venue": "in_game",             // or "irl" — real-life badge, cannot capture in game
  "auto_checked": false           // true = no submission needed at all
}
```

Volume: typically 3–15 tracked quests, requirement text up to ~300 chars, multiline.

## Screens & states to design

1. **Quest Log list** — rows grouped by guild. Per row: name, category, evidence
   summary (e.g. 2 screenshots needed), and the capture affordance. Three row kinds:
   - **auto-capture** quests (show that the game is watching — this is the magic;
     make it feel armed, not busy),
   - **manual capture** quests (Capture button),
   - **display-only** (IRL badges / auto-checked — visible but not capturable).
2. **Expanded row** — full requirements text (verbatim, multiline), reward, evidence
   note. One row expanded at a time.
3. **Empty state** — no quest file installed yet: short instruction telling the player
   to use the picker page and where to drop the file.
4. **Error state** — quest file failed to load: one-line reason + "reload" affordance.
5. **Post-capture feedback** — a submission was just saved (auto or manual): the
   player needs a moment of "got it, receipt saved" without leaving the world. Also
   consider: auto-capture just fired while the panel was CLOSED — what minimal toast
   tells them it worked? (The game gives us a one-line message strip top-center; we
   can also design a small custom toast.)
6. **Home** — the panel's root: buttons for each guild's workflows (e.g. "Slayers →
   Rank Proof") plus "Quest Log (n)". Keep it dead simple, it's a hallway.

## What I want back

- Static mockups of screens 1–6 at ~420×560 (1080p scale), using only the primitives
  above. Dark-wood Valheim tone.
- A small token sheet: the flat colors used (bg, panel, line, text, dim, accent,
  per-guild accents for Slayers/Rangers), text sizes, row heights, paddings.
- The evidence/status marker system WITHOUT emoji: how you denote screenshots-needed
  count, video-alternative, link, group, auto-capture armed, IRL, auto-checked.
- States for a row: default, hover, expanded, just-captured, cooling-down (auto-capture
  has a 60s cooldown after firing).
- Two distinct directions are welcome (e.g. dense ledger vs. spacious cards), but both
  must fit the constraints. Bias toward density — this is a utility read mid-game.

## Do not

- Do not use emoji, gradients, blur, photos, or more than one font family.
- Do not design a fullscreen journal — it's a compact overlay.
- Do not invent data fields (difficulty stars, XP, progress %, map pins). Only what's
  in the JSON above exists. If a field would make the design better, list it at the
  end as a "data ask" instead of drawing it in.
- Do not add navigation depth — Home and Quest Log are one click apart, everything
  else is inline expansion.
