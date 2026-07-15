# P7 primary V1 authoritative ZDO cutover — ComfyNetworkSense 0.5.27

Date: 2026-07-15 UTC

Environment:

- GCP deployment: `comfy-lumberjacks-p7`
- Lumberjacks Gateway: `3a91592`
- ComfyNetworkSense: `0.5.27`
- OMEN/GCP/cold-start DLL SHA-256: `cde0d458f2c74bc9b3dba3f73ba5bdce5e4df602bf635c42110bd24b8630d72c`
- Enrollment/window: `p7-primary-v1`
- Scope: one enrolled client; permanent explicit all-prefab (`*`) redirect

## Result

PASS. The password-free launcher started the private SSH/IAP tunnel and Valheim.
The server admitted the client with a Lumberjacks-decided handshake at 07:09:51 UTC
and reported `password_present=False`. The authoritative redirect armed at 07:10:16
UTC with no active-window cap.

At 07:11:47 UTC Gateway promoted the live heartbeat to `lumberjacks-primary`:

| Gate | Observed |
|---|---:|
| coverage | 100% |
| native-only traffic | 0 |
| receipts / acknowledgements | 18,705 / 18,705 |
| exact applies | 18,520 |
| safely superseded | 185 |
| pending / gaps / duplicates | 0 / 0 / 0 |
| terminal rejects / retries | 0 / 0 |
| active consumers | 1 |
| durable queue / persistence healthy | true / true |

## Persistent-primary boundary

The finite diagnostic probe stopped at 07:12:47 UTC. Version 0.5.27 explicitly
logged `ZDO redirect remains armed after probe stop: lumberjacks-primary owns the
live path.` No redirect auto-stop followed. A post-boundary envelope increased the
window to 18,706 receipts and was applied and acknowledged with zero pending or
errors. The cutover endpoint remained `state=lumberjacks-primary`, `coverage=100`,
`native_only=0`, and `complete=true`.

## Password-free and cold-start proof

The pinned Valheim image omits `-password` when `SERVER_PASS` is empty. The live
process command line contained no `-password` argument. Both the runtime DLL and
`/mnt/comfy-p7/valheim/config/bepinex/plugins/ComfyNetworkSense.dll` cold-start copy
matched the 0.5.27 hash, and a container recreate loaded `ComfyNetworkSense 0.5.27`
directly. Future sessions use:

```powershell
& C:\work\comfy\infra\gcp\p7\scripts\start-primary-session.ps1
```

Gateway HTTP remains private on GCP loopback and OMEN `127.0.0.1:14000`; the GCP
public TCP 4000 endpoint is closed. Native Valheim/Steam remains available only as
the explicitly permitted compatibility/fallback transport.

## Empty-server dashboard state

After the client exited, Gateway `a776fdf` was deployed with the zero-peer primary
heartbeat rule (38/38 Gateway tests passed). The live cutover surface remained fresh
with `state=lumberjacks-primary`, `stale=false`, `mod_version=0.5.27`, 100% coverage,
native-only 0, durable/persistence healthy, zero queue pending, and zero active
consumers. `complete=false` is intentional when no authoritative consumer is online;
the server mode and deployment heartbeat no longer become falsely stale merely
because the server is empty.
