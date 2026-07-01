# Changelog

## 0.2.0

The first end-to-end vertical slice: mod integration through publishing a Slayer rank proof.

- Replaces the generic `submit_proof` action with the three Slayer rank-proof actions
  (Thrall/Thegn/Jarl), each carrying its guild/category/rank workflow context and file bridge target.
- Actions are now rendered from the rank-ladder recipe output by
  `generate-actions-from-rank-ladder.py` — the recipe stays the single source of truth; never edit
  `actions.json` by hand.
- Adds the in-game control surface panel (`F7`).
- Adds `support/diagnose.ps1` (install health, action-load status, traces, package audit).
- Adds the Mikers demo (`bridge-consumer/mikers-demo/`): the reviewer's side of the loop, runnable
  with no game installed.
- Ships the bridge consumer (validate + review inbox) and the quest brief (`QUEST.md`) inside the
  package zip so the handoff is one self-contained file.
- The Slayer `bot_command_template` is still a **placeholder** — swapping in the real command is
  deliberately left as the final step of `QUEST.md`.

## 0.1.0

- Initial vertical-slice scaffold.
- Adds BepInEx plugin, hotkey, console commands, action loading, local trace/status/outbox files, and screenshot evidence.
