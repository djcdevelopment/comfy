# I2 repeatability — window A of the P4 gate session (2026-07-10)

**Verdict: PASS — 2nd authoritative ownership-pin window.** P3's one soft spot (window 1 was a
corroborating floor cut short by the idle-restart) is closed: the pin mechanism reproduced
cleanly on a fresh join, uninterrupted, with the live negative control and save-integrity intact.

## Window

- Armed via `scripts/run-redirect-window.ps1 -Stage arm-pin` (ROOT cfg; pin on, redirect off,
  probe autostop 150s), save-integrity snapshot taken, container restarted — the join landed at
  the start of a fresh ~30-min `UPDATE_IF_IDLE` cycle (the adopted clock practice). No clipping.
- Peer connect 05:41:20 PDT (SteamID 76561198088711642, wary.fool/OMEN, client 0.5.11).
- All three seams in lockstep 05:41:50 → 05:44:20 (exactly 150s, clean auto-stop):
  netcode probe + ownership observe + ownership **pin**.

## Gate readings (via `valheim_ownership_pin_status`, authoritative stop row)

| Reading | Value |
|---|---|
| gate | **held_with_negative_control** |
| counters_are_authoritative | **true** (clean auto-stop; window 2 of P3 lacked this only for window 1) |
| pinned / captured | 25 / 25 (cap; any prefab) |
| holds | **232** — 222 via `SetOwner` (ReleaseNearbyZDOS funnel) + 10 via `SetOwnerInternal` (RPC_ZDOData remote-apply, caveat #2) |
| pass_through (live negative control) | **280** |
| save-integrity (during window) | pass — exact baseline match |
| save-integrity (after disarm restart = save→reload) | **pass** — portals 4472 / spawned 85439 / targets 20255 / locations 18004 exact; ZDOS 9,155,594 delta 0 |

Both funnels held again — including the revision-silent `SetOwnerInternal` path whose direct
guard was ADR 0001's load-bearing call. Compare P3's authoritative window: 25 pinned, 55 holds
(34/21), 262 pass-through. Different churn mix (this walk skewed release-funnel), same mechanism,
same clean save.

## Build note (recorded honestly)

This window ran on **mod 0.5.11**, not the byte-identical 0.5.10 DLL that passed P3: the pin
code is carried unchanged (no OwnershipPin* file touched between versions) and the new redirect
patch was present-but-inert (`zdoRedirectEnabled=false`). That makes this a
*mechanism-across-builds* repeatability claim — arguably stronger than same-binary repetition —
but it is not a same-binary rerun. Derek blessed the two-window shape knowing this.

## Files

- `ownership-pin.jsonl` — sha256 `b375d9ec…`, 175,894 B (pin_start / 232 hold rows / pin_stop)
- `ownership-churn.jsonl` — sha256 `d08fa974…`, 489,472 B (observe seam, the paired negative-control detail)

Post-window state: pin AND redirect disarmed (`-Stage disarm`), server restarted, observe-only
baseline confirmed by cfg readback. Window B (I3 redirect) had NOT run as of this archive —
staged and pending one join.
