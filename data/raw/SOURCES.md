# Raw source provenance

Landed untouched, per the kernel: data is pulled *through* a schema by the harvest layer,
never edited here. If a source has a bug (and they do), the harvester flags it and the
guild rules on it.

## slayer-guild-tracker.xlsx

- Source: https://docs.google.com/spreadsheets/d/1Xij6i1JIUT8iAdVgMDuwy9JzZGvMaU0xv85pSJZmElM
- Retrieved: 2026-07-01 (xlsx export, all 49 tabs)
- What it is: the Slayer guild's live operational tracker, eras 2-17.
- Tabs that matter first:
  - `Summons list for bot` - normalized quest list (103 quests): Name, Coopable?,
    Category, Turn-in Requirements (evidence emoji grammar), Bot Template. Primary
    harvest target.
  - `Slayer Summons E17` - current-era wide-grid summons sheet (cross-check source).
  - `Slayer Summons Tracker` - per-player completion matrix (one boolean column per
    summons, plus contract/bounty counts pulled from `Bounties - Contracts`).
  - `Player Ledger` - player name -> Discord user id mapping.
  - `Rank Requirements`, `Slayer Ranks E*` - per-era rank ladders.
- Known anomalies spotted on first read (for GM ruling, not silent fixes):
  - `Summons list for bot` row "Rare Killer" carries Misty Meat's bot template.
  - Wide grid Build-column commands reuse `summons_type:Dedication` for Fight Club /
    Training Grounds / Shrine of Smoke; one command reads `Flawless VIctory`.

## ranger-guild-tracker.xlsx

- Source: https://docs.google.com/spreadsheets/d/1iRH4C7ml1sJIiX_O175pBhP0m78sWjBM9-i37DWtCdc
- Retrieved: 2026-07-01 (xlsx export, all 13 tabs)
- What it is: the Ranger guild's live tracker (era 17).
- Tabs that matter first:
  - `Badges` - sectioned badge list (Nature / Adventure / Archery / Project / Spirit /
    IRL), with a `shared` group marker, per-badge turn-in commands (`/ranger badge`),
    and a free-text "Required Screenshots" column. The IRL section is real-life badges
    ("Required Photos").
  - `Quests` - narrative quests; name + reward folded into one cell; turn-ins reuse the
    badge command.
  - `Tracker`, `Ledger`, `UserNames` - per-player completion state and identity mapping.
- Known anomalies on first read: "Put a Bow On It" (Spirit) asks for a screenshot in its
  evidence note but its turn-in command has no image slot.

## slayer-guild-handbook.txt

- Source: https://docs.google.com/document/d/1xB4ZY78uTsTKaDd5LDFHKmIKkbazTEhixCXOy_nfwgA
- Retrieved: 2026-07-01 (txt export)
- What it is: the Slayer guild handbook ("E13 Slayers Guild", updated with Era 16
  changes). Rank-up requirements & rewards, contract/bounty definitions and rules,
  duel rules, submission workflow (`/slayer summons`, `/slayer_contract`,
  `/slayer_player_info`), weapon choices, events.
- Known drift (expected; the disease the kernel names): its rank requirements do not
  exactly match `recipes/rank-ladders/example-output.json` (era 16 transcription) or
  the tracker's per-era rank tabs. The harvester surfaces the conflict; a human rules.

## creator-events-tracker.xlsx

- Source: Etheiry (Luna)'s "Creator Events Tracker, Guidelines & Schedule" drop
  (archived in comfy-etheiry-analysis/CreatorStuff/), 28 tabs spanning eras 4-18.
- Retrieved: 2026-08-01
- What it is: the creator-events program's live tracker — one `Events (E#)` tab per
  era plus schedule, reward guidelines, loot spread, and allowlist tabs.
- Harvested: `Events (E18)` via the `creator-events-xlsx` adapter (126 events).
  Historical era tabs are deliberately not harvested yet.

## hobbit-reqs-rewards-reset.xlsx

- Source: Luna's "Hobbit Reqs & Rewards + Reset Checklist" copy, shared on Discord
  2026-08-07 (also archived in comfy-etheiry-analysis/CreatorStuff/).
- Retrieved: 2026-08-07
- What it is: the Hobbit guild's era-reset workbook, 6 tabs.
- Harvested: `E17 Reqs & Rewards` via the `hobbit-ladder-xlsx` adapter (kind:
  rank-ladder) — 4 ranks, 12 achievements, 3 village achievements; rewards from the
  "Proposed E17 Rewards" column, E16 diffs surfaced as anomalies.
- Deliberately not harvested:
  - `(In-Game)/(Other) Reset Checklist` — ops runbook (locations, coords, wards,
    placement commands). Operational, not player-facing.
  - `Completion Data` — per-quest completion counts; demand data worth a future
    telemetry cross-check.
  - `Archived`, `(In-Game) Reset Checklist Old` — history.
