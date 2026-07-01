# Recipe: guild rank ladder

Turn a guild's rank chart — however it exists today (an image, a pinned message, a sheet) — into a
clean, versioned rank page and the copy-paste bot commands members use. This file tells an AI agent
exactly how. Follow it literally; don't be clever.

Read `../../framework/AGENTS.md` first if you haven't. Then:

## USE — run the recipe on a real guild

1. Read `example-input.md` (a real messy chart) and `example-output.json` (what it became). Copy that shape.
2. Take the guild leader's actual chart. Produce a file shaped exactly like `example-output.json`:
   - one entry in `ranks` per rung, lowest `tier` first;
   - copy the requirements **as written** — if something is unclear, put `[need: ...]` and ask the
     leader. Never invent a requirement.
   - put the guild's real submission command in `bot_command_template` and set
     `bot_command_is_placeholder` to `false`. If you don't have it yet, leave the placeholder.
3. Validate:  `python validate.py their-file.json`
   Fix every line marked `X`. Lines marked `!` are advice.
4. Render:  `python render.py their-file.json`
   You get a clean rank page (hand it over — it replaces the drifting image) and the copy-paste
   commands. Done.

## CREATE — make a recipe for a different system

Copy this folder; keep the six files. Then change:
- `schema.md` — describe the new thing (quests, portal requests, whatever).
- `example-input.md` / `example-output.json` — a real before/after.
- `validate.py` — check the new fields.
- `render.py` — emit what *that* community already uses.
Keep every file small and readable. If a weak local model can't follow it, it's too clever — simplify.

## REPAIR — when it breaks

- Plain Python, standard library only. No installs, ever.
- `validate.py` tells you what's wrong with the *data* — read its messages first.
- If `render.py` output looks off, open it; it's short, the templating is at the bottom.
- The data is just JSON. Open it and read it. Nothing is hidden.

## Rules
- Keep the leader's original chart untouched (save the image/sheet).
- Render back into THEIR look and THEIR command format — never a generic template.
- Flag uncertainty with `[need: ...]`; never guess.
- The goal is the leader's **self-sufficiency**: leave them able to run, change, and fix this
  without you or the original author.
