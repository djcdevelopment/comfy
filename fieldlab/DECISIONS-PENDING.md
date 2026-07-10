# Decisions pending — netcode-replacement program

The single place to look when batching decisions. Append open items as
`- [ ] <date> — <decision> (source: <link>)`; check off with a link to where it was resolved.
Bounded: touch only lines you created or resolved.

## Open

*(none)*

## Resolved

- [x] 2026-07-10 — **Disarm the pin after the I2 gate** → yes; disarmed on am4
  (`ownershipPinEnabled=false`, commit `1f337c7`), back to observe-only baseline for P4.
- [x] 2026-07-10 — **I2 repeatability:** do one more clean join → **yes** (Derek's blessing,
  evening session): window A of the P4 gate session. Pin re-armed + save-integrity snapshot
  taken + server restarted (staged via `scripts/run-redirect-window.ps1 -Stage arm-pin`);
  **execution pending the join** — the gate itself is not marked until its artifact exists.
- [x] 2026-07-10 — **Idle-restart vs timed gates:** practice adopted = the arm stage restarts
  the container itself and the join follows immediately, so the 150s window sits at the start
  of a fresh ~30-min `UPDATE_IF_IDLE` cycle (encoded in `run-redirect-window.ps1`; the arm
  output says JOIN NOW). Revisit only if a window clips again.
- [x] 2026-07-10 — **Next phase:** **P4** with window A (I2 repeat) folded into the same game
  session, per Derek (two-window shape confirmed via AskUserQuestion, then blessed). Headless
  runway complete + committed (`ed18c55`, `5d088e9`; Lumberjacks `129677f`); one launch + two
  joins runs the gates. Note: window A runs on 0.5.11 (pin code carried unchanged from 0.5.10;
  redirect flag off/inert) — mechanism-across-builds repeatability, recorded honestly.
