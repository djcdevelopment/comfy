# Decisions pending — netcode-replacement program

The single place to look when batching decisions. Append open items as
`- [ ] <date> — <decision> (source: <link>)`; check off with a link to where it was resolved.
Bounded: touch only lines you created or resolved.

## Open

- [ ] 2026-07-10 — **I2 repeatability:** accept the one authoritative gate window as sufficient, or
  do one more clean player-join for a 2nd authoritative repeatability window? (window 1 was a
  corroborating floor, cut short by the idle-restart.) Available on demand.
  (source: [retro L-2026-07-10-4 / step 12](retro/SESSION-RETRO-2026-07-10.md))
- [ ] 2026-07-10 — **Idle-restart vs timed gates:** how to keep am4's ~30-min `UPDATE_IF_IDLE`
  save+restart from clipping a 150s gate window — schedule joins clear of the boundary, pause the
  updater for the window, or lengthen/segment the window? (~8% overlap risk per run.)
  (source: [retro L-2026-07-10-4](retro/SESSION-RETRO-2026-07-10.md))
- [ ] 2026-07-10 — **Next phase:** P4 (I3 outbound redirect → Lumberjacks) next, or a 2nd I2
  repeatability run / other work first? P4 does not strictly require I2.
  (source: [TEST-PROGRAM.md P4](TEST-PROGRAM.md))

## Resolved

- [x] 2026-07-10 — **Disarm the pin after the I2 gate** → yes; disarmed on am4
  (`ownershipPinEnabled=false`, commit `1f337c7`), back to observe-only baseline for P4.
