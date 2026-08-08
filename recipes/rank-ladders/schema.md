# Schema — a guild rank ladder

One JSON file describes one guild's rank ladder for one era. Plain shape, on purpose.

Top level:
- `guild` — text. The guild's name, e.g. `"Slayers"`.
- `era` — number. Which era these requirements are for.
- `source` — text, optional. Where this came from (e.g. "Mikers's rank chart").
- `bot_command_template` — text. The command a member/rep pastes to submit. Use `{rank}` and
  `{proof}` as fill-ins; the renderer swaps them in.
- `bot_command_is_placeholder` — true/false. Set to `false` once you put the guild's real command in.
- `ranks` — a list of the rungs, lowest tier first.

Each entry in `ranks`:
- `tier` — number. `0` = starting rank (before any rank-up), `1` = first rank-up, then `2`, `3`, …
- `name` — text. The rank's name, e.g. `"Thrall"`.
- `requirements` — list of text. What you must do to reach this rank. Copy them as written.
- `reward` — optional. `{ "rank": text, "bonus": text }`.

Optional blocks a ladder may carry (harvested ladders do):
- `achievements` / `village_achievements` — lists of `{ name, requirements, rewards,
  entry_id, source_row }`: parallel goals that aren't rank rungs. `render.py` prints
  them after the ranks; `validate.py` checks them at advice level.

That's the whole shape. Nothing hidden. If you need a field that isn't here, add it — then teach
`validate.py` and `render.py` about it (see PROMPT.md → CREATE / REPAIR).

## Where ladders come from

Two lanes produce this file:
1. **Hand transcription** (the original lane) — PROMPT.md walks a helper through it;
   unknowns become `[need: ...]` questions for the leader.
2. **Harvested** — `../quest-catalogs/harvest.py` sources with `"kind": "rank-ladder"`
   (first: `hobbits-ladder`, from Luna's workbook) emit this shape directly, plus an
   anomalies report and a provenance sidecar that powers the leader-facing receipt
   page (`data/processed/provenance-<source-id>.html`).
