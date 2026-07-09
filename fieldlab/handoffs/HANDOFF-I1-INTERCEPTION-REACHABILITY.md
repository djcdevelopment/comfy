# Handoff — Rung I1: Interception Reachability (+ I6 cheap win)

Next session's starting point for `VALHEIM-NETCODE-REPLACEMENT-WORKLOG.md`.
I0 is complete — the map is `../NETCODE-MAP.md` (repo: `fieldlab/NETCODE-MAP.md`).
Build mapped: `assembly_valheim.dll` @ 2026-07-01, network protocol version **36**.

---

## The one invariant to prove (I1)

A ComfyNetworkSense Harmony patch **fires on the live ZDO send and receive funnels**
and can **read the ZDO payload** passing through — observe only, change nothing.
This proves the I0 hook points are real and reachable at runtime, decoupled from any
redirect/authority logic.

## Hook targets (from NETCODE-MAP.md — use these exact methods)

| Direction | Target | Signature | Inlining exposure |
|---|---|---|---|
| Receive (apply) | `ZDOMan.RPC_ZDOData` | `private void RPC_ZDOData(ZRpc rpc, ZPackage pkg)` | **None** — delegate-registered (`Register<ZPackage>("ZDOData", RPC_ZDOData)`), JIT cannot inline. Easy win, patch this first. |
| Send | `ZDOMan.SendZDOs` | `private bool SendZDOs(ZDOPeer peer, bool flush)` | **The real test** — private helper, multi-callsite. If a prefix here never fires, it was inlined. Fallback: postfix `CreateSyncList(ZDOPeer, List<ZDO>)` or hook the `"ZDOData"` invoke one frame up. |

The ZDO wire fields to log for legibility (present in both funnels): `ZDOID m_uid`,
`ushort OwnerRevision`, `uint DataRevision`, `long GetOwner()`, `Vector3 GetPosition()`.

## What to build (mirror the priority-manifest slice)

1. New console command in ComfyNetworkSense: `network_sense_lumberjacks_netcode_probe [start|stop|status]`.
2. One runner that installs two Harmony patches (postfix `RPC_ZDOData`, prefix `SendZDOs`),
   each incrementing a counter and writing one line per observed ZDO to
   `BepInEx/config/comfy-network-sense/netcode-probe.jsonl` (uid, owner, ownerRev, dataRev, dir).
3. Auto-installs to the live plugins folder on build (existing harness behavior).
4. A fieldlab verifier that confirms the counts are plausible against the play window.

**Offload split:** local_generate drafts the runner boilerplate + verifier scaffold
(proven this program). Frontier writes the two Harmony patches + reads the ZDO struct.

## Operator steps (~2 min in-game — Derek)

1. Build installs the DLL. Launch Valheim, load a world (Era16 or any).
2. `network_sense_lumberjacks_netcode_probe start`
3. Move around ~60–90s so ZDOs sync (walk, spawn/despawn objects, cross a zone edge).
4. `network_sense_lumberjacks_netcode_probe stop`
5. Report the on-screen counts; I read `netcode-probe.jsonl` and gate it.

## Pass gate

Nonzero observed **sends AND receives** during normal play, with `uid`/`owner` fields
legible. If receives fire but sends stay at zero → `SendZDOs` was inlined; switch to the
`CreateSyncList` postfix fallback and re-run (this is a discovery, not a kill — a
reachable seam still exists one frame up).

## Bundle the cheap win: I6 (Steam-only) in the same session

I6 is nearly free and shrinks every later rung. Recipe:
- Copy BetterNetworking's toggle: `CW_Jesse.BetterNetworking/Patches/BN_Patch_ForceCrossplay.cs`
  (in `scratchpad/netcode-src/` this session; re-fetch via the confirmed fleet lane or clone).
- The I0 handshake map confirms Steam-only skips the entire PlayFab auth branch in
  `RPC_PeerInfo` (the `m_onlineBackend == OnlineBackendType.PlayFab` block, ZNet:889-911),
  so forcing Steam leaves `ZSteamSocket` as the single transport.
- Gate is binary: assert crossplay off, verify no PlayFab relay path active. No operator
  step beyond a restart.

## Standing risks still open (from worklog)

- Inlining: **bounded** by I0 — the receive/handshake/routed-RPC handler layer is
  delegate-based and inlining-proof; only the send-side helpers carry residual risk, which
  I1 directly tests here.
- Save corruption: not yet in play (I1 is observe-only). Becomes a hard gate at I2/I4.
- Legal/ToS: unresolved; not a blocker to local feasibility, hard gate before any public release.

---
*Predecessor handoff: `HANDOFF-PERF-TEST-AB-CHECKLIST.md` (priority-manifest perf slice).*
