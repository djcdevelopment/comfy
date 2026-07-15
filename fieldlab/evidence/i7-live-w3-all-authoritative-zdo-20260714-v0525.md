# I7 live W3 all-prefab authoritative ZDO gate — ComfyNetworkSense 0.5.25

Date: 2026-07-14 PDT / 2026-07-15 UTC

Environment:

- GCP deployment: `comfy-lumberjacks-p7`
- Lumberjacks Gateway: `3a91592`
- ComfyNetworkSense: `0.5.25`
- OMEN/GCP DLL SHA-256: `e70ee607ac9709c201f722324f3cc2fcf7dc04a5273b6e1f28700f10c90d14b9`
- Enrollment/window: `i7-live-w3-all-v0525`
- Scope: one enrolled client; explicit all-prefab (`*`) server redirect

## Result

PASS. The redirect armed after the enrolled peer joined at 06:39:04 UTC and emitted
43,355 contiguous envelopes across 435 prefab hashes. Receipts stopped at 06:40:06
UTC. The 0.5.25 consumer drained the durable queue by 06:42:09 UTC.

| Gate | Observed |
|---|---:|
| receipts / distinct sequences | 43,355 / 43,355 |
| acknowledged | 43,355 |
| exact applies | 43,306 |
| safely superseded | 49 |
| exact + superseded | 43,355 |
| Gateway pending / consumer pending | 0 / 0 |
| missing sequence gaps / duplicates | 0 / 0 |
| terminal rejects / retries | 0 / 0 |
| active consumers | 1 |
| distinct prefab hashes | 435 |

The client remained connected and responsive through the window. Native fallback
resumed when the bounded 90-second redirect ended.

## Live restart proof

After the queue drained, Gateway was force-recreated while the client and Valheim
server remained live. The persistent WAL replay restored exactly 43,355 receipts,
43,355 acknowledgements, zero pending, zero gaps, and zero duplicates. Gateway
reported `durable_queue=true`, `persistence_healthy=true`, and a 12,796,930-byte WAL.
The OMEN SSH/IAP tunnel recovered automatically across the recreate.

## Promotion decision

The required single-client all-prefab widening boundary passed after the bounded
three-prefab 0.5.25 gate. A fresh window may now be declared
`lumberjacks-primary` with all-prefab redirect left active. A new window id is
required so the server's sequence restart cannot collide with client duplicate
suppression from this completed window.
