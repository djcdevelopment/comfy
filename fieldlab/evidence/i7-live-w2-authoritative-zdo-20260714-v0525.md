# I7 live W2 authoritative ZDO gate — ComfyNetworkSense 0.5.25

Date: 2026-07-14 PDT / 2026-07-15 UTC

Environment:

- GCP deployment: `comfy-lumberjacks-p7`
- Lumberjacks Gateway: `3a91592`
- ComfyNetworkSense: `0.5.25`
- OMEN/GCP DLL SHA-256: `e70ee607ac9709c201f722324f3cc2fcf7dc04a5273b6e1f28700f10c90d14b9`
- Enrollment/window: `i7-live-w2`
- Scope: one enrolled client; `FirTree_small`, `FirTree`, and `Pinetree_01`

## Result

PASS. The 0.5.25 recovery/throughput boundary applied and acknowledged all 3,401
redirected envelopes through `RPC_ZDOData`. Four consecutive observations from
06:31:55 through 06:32:10 UTC reported `complete=true` with a stable receipt count.
The server's 150-second probe then auto-stopped normally at 06:33:15 UTC.

| Gate | Observed |
|---|---:|
| receipts / distinct sequences | 3,401 / 3,401 |
| acknowledged | 3,401 |
| exact applies | 3,401 |
| superseded | 0 |
| Gateway pending / consumer pending | 0 / 0 |
| missing sequence gaps / duplicates | 0 / 0 |
| terminal rejects / retries | 0 / 0 |
| active consumers | 1 |
| durable queue / persistence healthy | true / true |

The Gateway WAL was 819,039 bytes after the window. Gateway TCP 4000 was reachable
only through the OMEN SSH/IAP tunnel at `127.0.0.1:14000`; a direct connection to the
GCP public IP on TCP 4000 failed while Valheim's public UDP gameplay ports remained
available.

## Recovery rehearsal

Before this live window, a synthetic pending sequence was written to the persistent
queue and the Gateway was restarted. The sequence remained pending. It was then
acknowledged and the Gateway restarted again; acknowledged=1 and pending=0 survived.
After resetting the smoke window and restarting a third time, no smoke window was
restored. `durable_queue=true` and `persistence_healthy=true` held throughout.

## Promotion boundary

This revalidates the bounded three-prefab window after adding the durable queue and
raising the client poll batch to 256. The next gate may widen the same single-client
path to the explicit all-prefab (`*`) scope. Native fallback remains available until
that widening gate drains cleanly.
