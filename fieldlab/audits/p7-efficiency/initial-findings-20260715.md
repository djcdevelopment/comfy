# Initial findings — 2026-07-15

Source manifest: `fieldlab/runs/audits/p7-efficiency/manifest-20260715T073420Z.json`.

These are observations from the provenance slice only. They are not runtime
pass/fail results.

| Finding | Evidence | Disposition |
|---|---|---|
| Lumberjacks source is clean at `a776fdf3` | manifest `lumberjacks.git` | usable audit anchor |
| Comfy/fieldlab source is dirty at `984f15ab` | manifest `comfy.git` and `fieldlab.git` | capture the diff before claiming reproducibility |
| P7 remote host is reachable and reports six running containers | manifest `remote.host` / `remote.containers` | baseline topology confirmed |
| `redirect.wal` is 58,237,720 bytes | remote WAL snapshot in manifest | measure growth rate, replay time and compaction before changing policy |
| IAP reports the NumPy tunnel-performance warning | raw remote collection output | benchmark tunnel throughput with and without the documented optimization |

The WAL size is a resource-efficiency signal, not evidence of corruption. The
next runtime slice must measure append rate, live sequence count, replay time,
and whether acknowledged records can be compacted safely.

## First live-window result

Source: `fieldlab/runs/audits/p7-efficiency/cutover-live-window-2-20260715T074045Z.json`.

During a 30-second OMEN-connected sample, 5,120 envelopes were applied and
acknowledged; pending fell from 38,476 to 33,356; retries and duplicates did
not increase; coverage remained 100%; and native-only remained zero.

The API nevertheless reported `state: stale` and retained an older
`last_seen` timestamp while counters were changing. This is a P1 observability
defect: the dashboard must distinguish “producer heartbeat stale” from “queue
consumer actively draining,” otherwise a healthy authoritative window appears
broken to an operator.

## Post-deploy verification

The Gateway-only fix was deployed after a timestamped remote backup and a
Gateway test pass (38/38). The Valheim container was not restarted. After one
client reconnect, the live API reported `consumer_active: true` and
`consumer_draining: true`; pending work fell from 23,334 to 17,047 while
applied work rose from 7,936 to 20,736. The post-deploy raw sample is:
`fieldlab/runs/audits/p7-efficiency/cutover-post-deploy-drain-20260715T075038Z.json`.

The dashboard now labels this condition as “consumer draining” instead of
returning early with “Cutover: stale.”

## Second live-window result

After the retained-counter deployment and client reconnect, the final
30-second sample recorded 5,120 additional applications/acknowledgements and
pending work falling from 11,709 to 6,589, with native-only still zero:
`fieldlab/runs/audits/p7-efficiency/cutover-retained-counters-live-20260715T075719Z.json`.

The single-client authoritative path is therefore live and convergent. The
remaining P1 work is durability efficiency: WAL compaction/checkpointing,
replay timing, and bounded growth under continued receipt production.

## WAL audit observation

The live `redirect.wal` reached 86,967,586 bytes by 07:58 UTC while Gateway
tick telemetry remained healthy (simulation p99 approximately 0.02 ms and zero
tick overruns). `ValheimZdoRedirectService` currently supports append, replay,
truncated-tail repair, and reset operations, but has no compaction/checkpoint
operation. This is a bounded-growth gap, not a correctness failure; compaction
must preserve receipt totals, duplicate accounting, pending envelopes, and
acknowledgement semantics before it is enabled in primary.

## Offline compaction result

An explicit `Compact()` implementation now writes a snapshot WAL to a
temporary file, flushes it, atomically replaces the active WAL, and supports
replay via a new `snapshot` operation. The equivalence test passes with 40/40
Gateway tests, including receipt/distinct/ack/pending/duplicate and
prefab/source-count comparisons. It remains staged-only: the live P7 WAL has
not been compacted.

Before production use, expose this as an operator action with a measured
threshold, record before/after bytes and duration, and run it once against a
copied P7 WAL followed by fresh replay and authoritative-window comparison.

## Copied-P7 WAL rehearsal

The live WAL was copied to `fieldlab/runs/audits/p7-efficiency/wal-rehearsal/`
and compacted offline. The [rehearsal report](/C:/work/comfy/fieldlab/runs/audits/p7-efficiency/wal-rehearsal/redirect.wal.report.json)
records 86,967,586 bytes reduced to 1,691,724 bytes (98.05%) in 1.18 seconds;
two windows replayed healthy and their core counters matched before/after.
The production WAL was not modified.

## Live compaction result

The guarded operator endpoint was deployed and invoked through the private OMEN
tunnel after client reconnect. The first live invocation reduced the WAL from
89,451,822 to 2,424,743 bytes (97.29%) in 46.9 ms. The client remained active,
the consumer stayed draining, and native-only traffic remained zero. The
archived API report is [live-compaction-20260715T080806Z.json](/C:/work/comfy/fieldlab/runs/audits/p7-efficiency/live-compaction-20260715T080806Z.json).

The follow-up invocation also completed safely while new receipts were being
produced, reducing 7,351,672 to 6,113,280 bytes in 55.4 ms. Compaction is now
an available operator action; automatic threshold scheduling remains deferred
until a longer growth/soak window establishes the right trigger.

## Fault/recovery checkpoint

The post-change Gateway suite passes 41/41. A live private-tunnel check with no
active consumer reports `mode: lumberjacks-primary`, `persistence_healthy: true`,
zero native-only traffic, and zero rejected records while pending work remains
queued. This is the intended fail-closed behavior: the Gateway does not falsely
acknowledge or silently route authoritative state through native Valheim when the
client consumer is absent.

## Final single-client acceptance

After the local OMEN redeploy and final client reconnect, the P7 window reached
`complete: true` at 2026-07-15 12:34:03 UTC. At the gate: pending `0`, receipts
`611,088`, acknowledged `611,088`, persistence healthy, active consumer,
rejected `0`, and native-only `0`. Distinct sequences were `480,562`; the
difference is expected at-least-once duplicate delivery and is tracked by the
duplicate counter rather than treated as data loss.
