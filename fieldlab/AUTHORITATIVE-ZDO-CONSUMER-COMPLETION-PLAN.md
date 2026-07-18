# Authoritative ZDO consumer completion plan

> **COMPLETE (2026-07-15).** Every gate below passed and the endpoint landed: the Gateway
> promoted the live heartbeat to `lumberjacks-primary` with a permanent explicit all-prefab
> redirect - 100% coverage, native-only 0, 18,705/18,705 receipts/acknowledgements, 0
> pending/gaps/duplicates (ComfyNetworkSense 0.5.27; evidence
> `fieldlab/evidence/p7-primary-v1-authoritative-zdo-20260715-v0527.md`). Kept for the record;
> the active program moved to M-series strict admission in
> `C:\work\Lumberjacks\docs\plan-m1-strict-admission.md` and the living roadmap
> (`C:\work\Lumberjacks\docs\roadmap\`).

## Objective

Promote the existing ZDO redirect path from receipt-only mirroring to an ordered,
verified apply/ack path through Valheim's `RPC_ZDOData` receive funnel. Native
replication remains enabled until every gate below passes.

## Current evidence

- Gateway pending/ack queue is live for `i7-live-w2`.
- GCP and OMEN load ComfyNetworkSense 0.5.19.
- The GCP process loads plugins from `/opt/valheim/bepinex/BepInEx/plugins`.
- Consumer startup is visible and reports `enabled=true`.
- Raw TCP reaches the Gateway; the remaining failure is envelope parsing.

## Gates

1. Capture bounded response diagnostics: status, headers, body length, chunk count,
   prefix/suffix, and SHA-256. Never log the complete `body_b64` values.
2. Replace Unity `JsonUtility` with a bounded parser tested against a captured live
   response fixture.
3. Require `schema_version=1` and validate all numeric ranges and body sizes.
4. Add `off`, `poll-only`, and `apply` modes. `poll-only` must show zero parse errors,
   gaps, and retries before apply can arm.
5. Reconstruct and replay-read each `ZPackage`; compare UID, owner, revisions,
   position, prefab, body length, and body hash.
6. Apply exactly one sequence through a connected peer's `ZRpc`, verify ZDO
   readback, acknowledge it, and auto-stop.
7. Exercise malformed JSON/base64, stale revisions, duplicates, missing peer,
   timeouts, and restart-before-ack.
8. Run the three-prefab live window. Required result: applied > 0, rejected = 0,
   sequence gaps = 0, acknowledged = applied, pending = 0 after drain.
9. Persist deployment to the actual server plugin path and verify matching hashes on
   GCP and OMEN before every window.
10. Only then widen ZDO scope and enable the `lumberjacks-primary` promotion gate.

## Rollback

Any parse, reconstruction, apply, acknowledgement, timeout, sequence, or queue
overflow error returns the consumer to `poll-only` and leaves the server in
`mirrored` mode.
