# Quest 9: The Control Surface

**Quest giver:** Derek
**For:** Mikers, Slayer GM (llmquest graduate — Quests 1–8 complete)
**Requires:** Valheim + BepInEx, any Python 3. No network. No bot token. No permission from anyone.

## The quest in one line

Take a Slayer rank proof from inside the game all the way to an accepted, copy-paste `/slayer`
command — entirely on your machine.

## What this thing is

A member presses `F7` in-game, picks **Slayers → Rank Proof → Thrall**, and a plugin writes a proof
package to a local outbox: a JSON payload (who, where, what rank), a screenshot as evidence, and a
trace of every step. You — the GM — run a small review inbox over that outbox: `list`, `show`,
`accept`, `export`. The export is the exact bot command string you already paste today, drafted
for you with the evidence attached.

The ranking grind — chasing screenshots, retyping commands, reconstructing who did what —
is the part this absorbs. The judgment call stays yours. Requirements remain human-reviewed.

**Design guarantees (hard rules, not marketing):**

- Everything is a plain file on your disk. No server, no webhook, no database, nothing hosted.
- It does not replace the Slayer bot — it *feeds* it the same commands you already use.
- Delete the folder and it never existed. It's yours: use it, fork it, fix it.

## Part 1 — The reviewer's desk (no game needed, ~5 minutes)

Unzip this package. From the unzipped folder:

```text
python bridge-consumer/bridge_consumer.py bridge-consumer/mikers-demo
python bridge-consumer/review_inbox.py bridge-consumer/mikers-demo list
python bridge-consumer/review_inbox.py bridge-consumer/mikers-demo show 20260701-210000-slayer-rank-thrall-demo
python bridge-consumer/review_inbox.py bridge-consumer/mikers-demo accept 20260701-210000-slayer-rank-thrall-demo
```

That's a demo Thrall proof arriving on your desk: player, world, biome, position, screenshot path,
and a drafted `/slayer submit` command. This is what every submission will look like.

## Part 2 — The full loop, in-game (~10 minutes)

1. Copy `ComfyControlSurface.dll` into `Valheim/BepInEx/plugins/`.
2. Copy `config/comfy-control/actions.json` into `Valheim/BepInEx/config/comfy-control/`
   (the plugin creates a default there on first launch if you skip this).
3. Enter any world. Press `F7` → **Slayers → Rank Proof → Thrall**.
   (Console alternative: `comfy_submit slayer_rank_thrall`.)
4. Look inside `Valheim/BepInEx/config/comfy-control/` — the outbox payload, the evidence
   screenshot, the trace, the receipt. That's the whole submission, as files.
5. Point the inbox at it:

```text
python bridge-consumer/bridge_consumer.py "<Valheim>/BepInEx/config/comfy-control"
python bridge-consumer/review_inbox.py "<Valheim>/BepInEx/config/comfy-control" list
```

Then `show`, `accept`, `export` — same as the demo, but it's your character, your world, your
screenshot.

## Part 3 — The turn-in: make the command real

The command template in this package is a **guess**: `/slayer submit rank:{rank} proof:{proof}`,
flagged `bot_command_is_placeholder: true`. Only you know the real string.

The actions file is *generated* from your rank ladder — one source of truth, never edited by hand:

1. Open `rank-ladder/slayer-ladder.json` (your ladder — Thrall/Thegn/Jarl, transcribed from your
   chart). Set `bot_command_template` to the real Slayer submission command and flip
   `bot_command_is_placeholder` to `false`.
2. Regenerate the actions:

```text
python generate-actions-from-rank-ladder.py rank-ladder/slayer-ladder.json "<Valheim>/BepInEx/config/comfy-control/actions.json"
```

3. In-game: `comfy_control_reload`, submit a proof, run the inbox, `export`.

**Quest complete when:** the exported command draft is a string you could paste into Discord
unchanged.

## If it breaks (repair)

- `support/diagnose.ps1` writes a full health report — install state, action load, latest traces,
  last error, package audit.
- Every submission writes a `traces/*.trace.jsonl`; any failure writes an event with `ok: false`
  and a `status/last-error.json`. There are no silent failures.
- `PROOF.md` is the complete checklist from build through deliberately breaking it.

## Make it another guild's (create)

`generate-actions-from-rank-ladder.py` doesn't know anything about Slayers — it reads a ladder
file. Write another guild's ladder in the same shape (`rank-ladder/slayer-ladder.json` is the
worked example) and their GM gets this exact surface, no code changes. That's the fork point.

**Reward:** the process stops eating the relationship.
