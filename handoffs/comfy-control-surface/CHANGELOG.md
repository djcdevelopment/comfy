# Changelog

## 0.6.0

The Ledger panel: the quest-log design pass, implemented in the live overlay.

- Applies the design token sheet (`PanelTheme`): the flat palette, geometric marker
  system (hollow amber diamond = armed, faint diamond = cooling down, gold square =
  manual capture, dim ring = IRL, filled green diamond = verified), guild-accented
  section headers (Slayers crimson, Rangers green), and the game's own serif when it
  can be found. No emoji anywhere in the panel.
- Quest rows now show live trigger state: WATCHING while armed, "Re-arms Ns" during the
  60s cooldown (exposed from the trigger service), and a green "Proof saved · N shots ·
  awaiting guild-master review" receipt strip for two minutes after a submission.
- Expanded rows show requirements, reward, evidence note, and a Test capture button on
  auto-capture quests.
- Adds the designed empty state (where to get quest-view.json, Reload) and error state
  (load error text, Reload, Open folder).
- Panel is now 420×560, Esc closes it, and the footer hints at the controls.

## 0.5.0

Kill sequences: the 📸📸 grammar of the real quest sheets, captured automatically.

- Adds the `kill` trigger event (guarded `Character.RPC_Damage` hook): creature-type,
  weapon-skill, and projectile filters, attributed to the local player's blow.
- Adds two-shot sequences: `"shots": ["on_first_hit", "on_death"]` arms on the first
  matching hit (shot 1), binds to that creature, and completes on its death (shot 2).
  One-blow kills capture both shots at the kill. Sequences expire after 180s with a
  status message if the kill never lands.
- Payloads now carry `evidence.screenshots` (a list) alongside the existing
  `evidence.screenshot` (first shot, back-compat).
- Known limit: kill confirmation relies on the local client processing the damage —
  solid solo/local-world; in multiplayer, kills simulated by another peer may not
  confirm. Manual capture remains the fallback.
- Adds the `Neck Romancer` smoke-test quest: kill a Neck with your bare fists —
  first punch and death are captured as a two-shot submission.

## 0.4.0

Auto-capture: quest evidence fires off the game event itself, not a button.

- Adds `QuestTriggerService` + guarded damage-path hooks (`TreeBase`/`TreeLog`/
  `Destructible`). A tracked quest with a `trigger` spec — e.g.
  `{ "event": "hit", "target": "tree_or_bush", "weapon_skill": "Unarmed" }` — submits
  proof automatically the moment the local player's matching hit lands, so the action
  itself is in frame. 60s per-quest cooldown; attribution via `HitData.GetAttacker()`.
- Trigger quests show `[auto-capture]` in the Quest Log; manual Capture still works.
- The `Punchwood` smoke-test quest now carries the trigger: punch a bush or tree
  unarmed and the submission appears with no UI interaction at all.
- Reserved for later: `kill`/`projectile` events and multi-shot sequences
  (`on_first_hit` → `on_death` → aftermath).

## 0.3.0

The player quest log: the first inbound data path (curated quest data flowing *into* the game).

- Adds the Quest Log to the `F7` panel: it displays `quest-view.json` — the per-player quest
  view saved from the quest picker page — grouped by guild, with expandable requirement text,
  reward, and evidence notes.
- Each capturable quest has a Capture button that reuses the existing submission pipeline
  (screenshot → outbox payload → trace → receipt) with `submission_type: quest_proof` and the
  quest's real turn-in command carried in the workflow. IRL and auto-checked quests display
  but do not capture.
- Adds `QuestViewLoader` (same strict-parse + status-file discipline as actions:
  `status/quest-view-status.json`, no silent failures) and the `comfy_quest_reload` console
  command.
- Adds `Submit(ControlAction)` so quest entries can submit without registering in
  `actions.json`.
- The panel now frees the mouse cursor while open and blocks player attack/movement
  input, so it can be clicked directly (no more opening the inventory first). Patched
  defensively: if a game update breaks the hooks, the plugin logs it and still loads.
- Adds `comfy_quest_submit <quest_id>` for keyboard-only capture, and ships a
  `Punchwood` smoke-test quest in `fixtures/quest-view.json` (punch a bush or tree,
  unarmed) that can be proven on an empty world.
- Quest views are produced by the new quest-catalog recipe (`recipes/quest-catalogs/`):
  harvest real guild sources → canonical catalogs + anomaly reports → picker page →
  `quest-view.json`. Slayers (103 quests) and Rangers (85 quests) both harvest clean.

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
