# I2 ownership PIN gate capture — 2026-07-10 (mod 0.5.10)

**Behaviour-changing run** (mod 0.5.10, `ownershipPinEnabled=true` + `ownershipObserveEnabled=true`,
server-side am4). The first rung that *changes* ownership behaviour: on auto-captured ZDOs the pin
skips the vanilla ownership transfer so the owner does not move on zone entry, while uncaptured ZDOs
transfer normally (built-in negative control). Grounded on the live decompiled seams and the I2
observe capture (see `NETCODE-OWNERSHIP-MAP.md`, `../i2-observe/ANALYSIS.md`).

- **Authoritative window:** pin_start/pin_stop `2026-07-10T10:52:45Z -> 10:55:15Z` (150s autostop),
  from wary.fool/OMEN's join at 10:52:20Z (probe + observe + pin auto-armed together, coupled walk).
- **Evidence:** `ownership-pin.jsonl` (sha256 `ebeefeb6...79145e`), `ownership-churn.jsonl`
  (sha256 `816d7630...2cb3bd`). Both carry a lifecycle stop row (authoritative counters, not a floor).
- **First window** (pin_start `10:43:11Z`) was cut short ~71s in by the server's routine
  UPDATE_IF_IDLE save+restart (clean `World save writing started` -> `Shutdown complete`, not a crash);
  it still held 234 changes before the cut — a corroborating engagement, but not counted as the gate
  (no clean stop row). The idle-restart is the reason for the re-join.

## The gate — held with a live negative control (P3 steps 9 + 10, one window)

| Signal | Value | Gate |
|---|---|---|
| ZDOs pinned (auto-capture cap 25) | **25** (3 prefabs, 7 sectors, 2 held owners) | step 9 |
| Ownership changes HELD on pinned ZDOs | **55** (34 via `SetOwner`, 21 via `SetOwnerInternal`) | step 9 |
| Transfers ALLOWED on uncaptured ZDOs (pin pass-through) | **262** | step 10 |
| Observe seam transitions on unpinned ZDOs (independent) | **262 `via_internal` + 1 `via_setowner`** | step 10 cross-check |

`gate = held_with_negative_control`, `counters_are_authoritative = true`. The pin held **both**
funnels — the server churn funnel (`ReleaseNearbyZDOS` -> `SetOwner`, 34 holds) and the
revision-silent remote-apply funnel (`RPC_ZDOData` -> `SetOwnerInternal`, 21 holds). The 21 internal
holds are the concrete proof that guarding `SetOwnerInternal` directly was necessary: the
"keep OwnerRevision highest" strategy alone would have leaked them (see the map's
RPC_ZDOData:842-844 hole correction). The 262 pass-through transfers, independently mirrored by the
observe seam's 262 `via_internal` transitions on *different* ZDOs, are the live negative control:
vanilla ownership transfer still works for everything the pin did not capture.

## Save integrity (P3 step 11 — HARD GATE)

`valheim_save_integrity check` vs the clean pre-pin baseline: **status = pass**. A full world
save + reload happened *while the pin held 25 ZDOs* (the mid-run idle-restart at 10:44), and the
reloaded world matched the baseline exactly on every structural count (portals 4472, spawned 85439,
targets 20255, locations 18004) with ZDOS within tolerance (9,155,594 -> 9,155,59x, delta a handful
of session-transient ZDOs). This is the expected result and confirms the source finding that
**ZDO ownership is runtime-only** (`ZDO.Load` resets owner=0, `ZDO.Save` never writes it): the pin
writes nothing that persists, so it cannot corrupt the save. See
[[valheim-zdo-ownership-runtime-only]].

## Repeatability (P3 step 12)

Two independent joins both engaged the pin and held ownership: window 1 (`10:43:11Z`, 234 holds,
cut short by the idle-restart -> floor, not authoritative) and window 2 (`10:52:45Z`, 55 holds,
authoritative PASS). The mechanism reproduced across both. A second *clean* authoritative run is
available on demand (one launch+join into a window that does not straddle the ~30-min idle-restart
boundary).

## Verdict

The first behaviour-changing rung works: pinned ownership held on both funnels, uncaptured ownership
transferred normally (live negative control), and the save survived a reload with the pin engaged —
all hands-free, server-side, rollback-gated (`ownershipPinEnabled=false`), touching <=25 of 9.15M
ZDOs. I2/P3 ownership-seizure: **PASS.**
