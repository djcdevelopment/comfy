# I7 single-client authoritative ZDO window — 2026-07-14

## Result

Pass. The GCP dedicated server redirected the three-prefab bounded window through
Lumberjacks, and the enrolled OMEN client applied, read back, and acknowledged the
complete queue through Valheim's `RPC_ZDOData` receive funnel.

## Deployment identity

- ComfyNetworkSense: `0.5.21`
- DLL SHA-256 on GCP and OMEN:
  `f48df0af0a1fb77b175a1e45bac65d1e01b49ddcc471bf7e0bd58f63b25dde19`
- Enrollment/window: `i7-live-w2`
- Server instance: `20260715-045034-0ff52518`
- Cutover mode: `mirrored`

## Gate evidence

- Connected peers: 1; handshake accepted: 1; rejected: 0.
- Server suppressed and posted: 1,039 / 1,039.
- Gateway receipts and distinct sequences: 1,039 / 1,039.
- Sequence range: 1–1,039; missing: 0; duplicates: 0; empty bodies: 0.
- Prefab counts: `888684615=303`, `1185163063=258`, `797319082=478`.
- Client consumer drained the pending queue to zero while Valheim remained responsive.
- Client apply/readback failures: 0.
- One acknowledgment connection was reset by the Gateway at 04:57:35Z; the retry
  path recovered and the queue still drained to zero.
- Server redirect posted failures: 0; requeued: 0; dropped: 0.
- Redirect auto-stopped at 04:58:29Z after the 90-second bounded window, restoring
  native delivery for the allowlisted prefabs.

## Deployment defect found and fixed

A config copied through the OS Login account inherited UID `1256959016`. Valheim
runs as UID `1000`, so BepInEx raised `UnauthorizedAccessException` in
`ConfigFile.Bind`, aborting the plugin and allowing the 15,133-portal vanilla loop
to pin the Unity main thread. The host bind source is now `1000:1000` mode `0664`.
`infra/gcp/p7/scripts/deploy-network-sense.ps1` enforces this invariant and refuses
deployment if the startup exception or a DLL hash mismatch is observed.
