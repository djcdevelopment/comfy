# NETCODE-OWNERSHIP-MAP — the ZDO ownership machinery (I2 grounding)

Companion to `NETCODE-MAP.md` (which mapped the I0/I1 ZDO send/recv funnels). This maps the
**ownership** machinery so the P3/I2 "ownership seizure" pin is designed against verified source,
not guessed. Primary source: decompiled `assembly_valheim.dll` (see
[[valheim-decompile-toolchain]]); line numbers below are from that decompile (ZDO / ZDOMan types).
Grounded 2026-07-10 before any I2 code (satisfies TEST-PROGRAM P3 step 4 "I2 design recorded
before code" as pre-work). Per [[post-i0-distrust-rule]], anything here is source-grounded; the two
implementation caveats at the end are flagged as confirm-at-implementation.

## The one thing that matters

**ZDO ownership is 100% server-authoritative and churns through a single funnel.**
`ZDOMan.Update(dt)` calls `ReleaseZDOS(dt)` **only** `if (ZNet.instance.IsServer())` (ZDOMan:537-540).
`ReleaseZDOS` fires every **2 s** (`m_releaseZDOTimer > 2f`, ZDOMan:594-606) and calls
`ReleaseNearbyZDOS` once for the server's own ref position and once for **each connected peer's** ref
position. Clients never run this path. So the I2 pin is a **server-side (am4) patch at one seam**.

## Ownership storage & API (ZDO type)

- **Storage**: ownership lives in the `ZDOExtraData` side-table keyed by `m_uid`
  (`ZDO.GetOwner()` -> `ZDOExtraData.GetOwner(m_uid)`, ZDO:1491-1497), plus a per-ZDO cached
  `Owner` bool flag (`m_dataFlags & Owner`, "do I, this session, own it") and a `ushort OwnerRevision`
  (ZDO:203).
- **`ZDO.SetOwner(long uid)`** (ZDO:1510-1517): the **authoritative** setter. If the owner actually
  changes it calls `SetOwnerInternal(uid)` **and `IncreaseOwnerRevision()`** — the revision bump is
  what makes the change replicate.
- **`ZDO.SetOwnerInternal(long uid)`** (ZDO:1519-1533): applies the owner **without** bumping the
  revision. Sets the ExtraData owner and recomputes the local `Owner` flag
  (`Owner = uid == ZDOMan.GetSessionID()`). Used to **apply a remote** owner change.
- `IsOwner()` (do I own it), `HasOwner()`, `GetOwner()` (the owning peer's uid, `0` = unowned).

## The reassignment funnel — `ZDOMan.ReleaseNearbyZDOS(refPos, uid)` (ZDOMan:623-648)

For every persistent ZDO in the active area around `refPos`:
1. **Release** — `if (GetOwner() == uid)` and the ZDO's sector is no longer in the active area
   -> `SetOwner(0L)` (line 636-640). You abandon ownership of what you moved away from.
2. **Seize** — `else if ((!HasOwner() || owner not in its active area) && sector is in your active area)`
   -> `SetOwner(uid)` (line 643-645). You claim any unowned/orphaned ZDO that entered your area.

This is the "zone-entry ownership transfer" that TEST-PROGRAM P3 step 8 triggers: a moving player
(or the server on the player's behalf) releases what it left and seizes what it approached. A single
client is enough to exercise it — no second peer needed (a second peer only adds *contention*, which
is beyond-I7 density work).

## Replication of ownership (rides the I1 funnel)

Owner + `OwnerRevision` are written in the send funnel (`ZDOMan` send, OwnerRevision at ~773,
owner at ~775) and applied on receive in `RPC_ZDOData` (ZDOMan:792-846): if the incoming
`ownerRevision > local OwnerRevision`, it `SetOwnerInternal(owner)` and adopts the revision
(lines 828-844). So **ownership is reconciled by the same revision-gated send/recv already mapped for
I1** — highest OwnerRevision wins. A server that keeps bumping the revision keeps authority.

## Other server-side SetOwner call sites (secondary funnels to guard)

- Abandoned non-persistent reclaim: `SetOwner(m_sessionID)` (ZDOMan:1115-1119).
- Dead-ZDO reclaim in RPC_ZDOData, server-only: `SetOwner(m_sessionID)` (ZDOMan:852-854).
- Load/convert paths (portals, ships, rods, seed): `SetOwner(GetSessionID())` /
  `SetOwnerInternal(m_sessionID)` (ZDOMan:415, 1305-1554). Creator owns on create.

## I2 pin design (proposed, for approval before code)

- **Primary seam — Harmony-patch `ReleaseNearbyZDOS` (server/am4 only).** For a **pinned** ZDO, skip
  BOTH the release (line 640) and the reseize (line 645) so it never transfers on zone entry. This is
  the minimal, surgical pin: it neutralizes the only funnel that churns ownership.
- **Guard seam — prefix `ZDO.SetOwner(uid)`.** Block owner changes on pinned ZDOs from the secondary
  call sites (abandoned/dead reclaim). Keep the pinned authority owning it and keep OwnerRevision
  bumped so the pin wins the revision race and replicates to clients.
- **Observe seam (build FIRST, observe-only) — postfix `ZDO.SetOwner` + `SetOwnerInternal`.** Log
  `{uid, old_owner, new_owner, OwnerRevision, sector, is_server}`. This is the measurement surface for
  the P3 gates "owner stays pinned across trigger" and "unpinned transfers normally." Add it to the
  netcode probe + an MCP read in the same slice ([[kvm-elimination-guardrail]]) — measurement before
  modification.
- **Rollback flag**: config-gate the pin (like the other `[Netcode]`/`[Automation]` flags) so it can
  be toggled off mid-session (P3 step 5's rollback requirement).
- **Save-integrity**: owners + revisions persist in the save. Pinning mutates owners, so every P3+ gate
  needs the save-integrity check — motivates the pre-P3 save-integrity verifier.

## Confirm-at-implementation caveats

1. **`m_sessionID = Utils.GenerateUID()` (ZDOMan:77) is random per server session** — NOT stable across
   restarts. Do not pin to a literal session id you expect to survive a reload; pin to a sentinel/tag
   scheme (or re-assert the pin on load). Matters for the P3 save->reload hard gate.
2. **`RPC_ZDOData` applies remote owners via `SetOwnerInternal` (no revision bump)** — a guard on
   `SetOwner` alone does NOT cover that path. On the server this is inbound client claims; the pin holds
   as long as the server's OwnerRevision stays highest. Verify the revision race holds under the pin
   before trusting the "owner stays pinned" gate.

See `TEST-PROGRAM.md` P3, `GROUND-TRUTH.md`. Related: [[netcode-program-dashboard]],
[[post-i0-distrust-rule]], [[kvm-elimination-guardrail]].
