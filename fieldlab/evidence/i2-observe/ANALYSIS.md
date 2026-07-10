# I2 ownership-churn observe capture — 2026-07-10 09:30:09Z

**Observe-only run** (mod 0.5.9, `ownershipObserveEnabled=true`, server-side am4). Zero gameplay
change: postfix reads only, `nothing is modified` logged on start and stop. First data-grounded
look at the ZDO ownership funnel before any I2 pin (behaviour-changing) code.

- **Session:** `20260710-091847-35528bf8` · window `09:30:09Z → 09:32:39Z` (150s autostop)
- **Trigger:** wary.fool/OMEN joined am4 (peer connect 09:29:44Z) → netcode probe + ownership
  observe auto-started together (coupling worked) → hands-free teleport-route auto-rehearsal walk.
- **Evidence:** `ownership-churn.jsonl` (170,952 B, sha256 `cad7301f…0bed0e72`), `summary.json`.
  Authoritative counters (lifecycle stop row present), no errors, no row-cap hit.

## What churned

- **529 real ownership changes** (60,764 no-op `SetOwner` calls correctly filtered out),
  201 distinct ZDOs across 22 sectors — genuine zone-entry churn from the teleport route.
- All 529 rows `is_server=true` (server-side only, as designed — flag off on OMEN).

## Caveats settled (the point of observe-first)

1. **The pin seam is reachable + revision-bumping is real.** `via=SetOwner` fired **140×** during
   the walk, and **every one bumped `OwnerRevision` ≥1** (dist `{2:105, 1:35}`, none at 0). So a
   Harmony patch on the `ReleaseNearbyZDOS → SetOwner` funnel **does** intercept live churn and the
   revision-bump mechanism works. **The #1 risk (SetOwner inlined / patch never fires on the churn
   funnel) is dead** — the pin can rely on this seam.

2. **Caveat #2 confirmed and quantified — the pin must cover `SetOwnerInternal`.** `via=SetOwnerInternal`
   fired **389×** (73% of all churn), **169 of them at `OwnerRevision=0`** (revision-silent remote
   applies via `RPC_ZDOData`). A `SetOwner`-only guard would miss the majority of ownership changes.
   The `via` tag made this visible directly. Design consequence: the pin's guard/observe must include
   the `SetOwnerInternal` path, **or** rely on the server keeping the pinned ZDO's `OwnerRevision`
   highest so `RPC_ZDOData` rejects inbound claims (revision-gated at ZDOMan:828) *before* it reaches
   `SetOwnerInternal`. The observed remote applies came in at low revisions (0/1), consistent with
   that rejection strategy holding for a server-owned, high-revision pinned ZDO.

## Pin-scenario refinement (feeds P3 step 8)

During this walk the server **released** ownership (105× `SetOwner(new_owner=0)`) and reassigned to
the moving peer (35×); it never seized to *itself* (`server_seize_to_self=0`, expected — a headless
server has no player ref position of its own). So the "ownership transfer" a pin must resist is the
**release/reassign** as the player moves away, not a server self-seize. That matches the map's pin
design (skip both the release at ZDOMan:640 and the reseize at :645). The negative control
("unpinned transfers normally") should assert a normal release-to-0 / reassign still happens.

## Verdict

Observe-first delivered: patch-reachability de-risked, caveat #2 made actionable, revision mechanism
validated — all with zero gameplay risk and zero human walking. Ready to design the behaviour-changing
pin against real data.
