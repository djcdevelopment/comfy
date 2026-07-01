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

That's the whole shape. Nothing hidden. If you need a field that isn't here, add it — then teach
`validate.py` and `render.py` about it (see PROMPT.md → CREATE / REPAIR).
