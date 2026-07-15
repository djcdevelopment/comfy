# I7 live W2 authoritative ZDO gate — ComfyNetworkSense 0.5.24

Date: 2026-07-14 PDT / 2026-07-15 UTC

Environment:

- GCP deployment: `comfy-lumberjacks-p7`
- Lumberjacks Gateway: `b9321ce`
- ComfyNetworkSense: `0.5.24`
- OMEN/GCP DLL SHA-256: `7012a973295b88cd5c7c96ea812d5d87fa15561cbb7d064eb19583ac7ef8bf2c`
- Enrollment/window: `i7-live-w2`
- Scope: one enrolled client; `FirTree_small`, `FirTree`, and `Pinetree_01`

## Result

PASS. During the fresh 90-second redirect window, Lumberjacks received 7,216
distinct server-to-client ZDO envelopes. The enrolled 0.5.24 client reconciled and
acknowledged every sequence through `RPC_ZDOData`; Gateway reported `complete=true`
for three consecutive observations at 06:02:10, 06:02:15, and 06:02:20 UTC.

| Gate | Observed |
|---|---:|
| receipts / distinct sequences | 7,216 / 7,216 |
| acknowledged | 7,216 |
| exact applies | 6,385 |
| superseded by strictly newer revision | 831 |
| exact + superseded | 7,216 |
| Gateway pending | 0 |
| consumer pending | 0 |
| missing sequence gaps | 0 |
| Gateway duplicates | 0 |
| terminal rejects | 0 |
| retries | 0 |
| active consumers at gate | 1 |

The server auto-disarmed redirect after 90 seconds; receipts stopped at 7,216 and
the native path resumed. The wider netcode probe then auto-stopped normally. OMEN
remained responsive throughout and exited normally only after the complete samples
were captured (`Game - OnApplicationQuit`, followed by `ZNet Shutdown`). The client
log contained zero authoritative retry/reject lines and zero exceptions for this
session.

## Superseded semantics

The preceding 0.5.23 diagnostic run isolated four permanently obsolete envelopes:
the same tree ZDOs were already at data revision 1 while the queued envelopes carried
revision 0. Reapplying them would roll state backward. Version 0.5.24 therefore treats
a matching ZDO at a strictly newer owner or data revision as safely superseded,
acknowledges the sequence, and reports it separately. Promotion requires
`applied + superseded == distinct_seq`; superseded work is never counted as an exact
apply or a rejection.

## Remaining boundary

This proves the bounded single-client, three-prefab authoritative server-to-client
window. It does not yet prove all-prefab throughput, client-to-server ZDO authority,
multi-client fan-out, or durable recovery of the in-memory Gateway queue across a
process crash. Those are the next widening gates; native fallback remains enabled.
