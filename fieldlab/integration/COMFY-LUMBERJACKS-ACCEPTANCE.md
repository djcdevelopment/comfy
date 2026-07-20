# Comfy to Lumberjacks integration acceptance

**Accepted implementation:** Comfy `dd7806185e88735be032161860a72c0a59b801a1` with
Lumberjacks `e7cef6e9819f4d5f4d462f6d74860611fddb046a` (Gateway code in
`fb55441f562ee3410087287d33b609dc05ba1fea`).

**Accepted runtime window:** `comfy-lj-integration-20260719-172149`.

**Verdict:** ACCEPTED for the local, one-producer, one-recipient vertical slice defined below.
This is not a production deployment acceptance.

This document is the single acceptance record. Its compact evidence set is under
[`evidence/20260719-172149`](evidence/20260719-172149/); the provenance and SHA-256 inventory is
[`evidence-manifest.json`](evidence/20260719-172149/evidence-manifest.json). The larger source run
under `fieldlab/runs/` is intentionally generated and Git-ignored. The manifest retains hashes for
those generated sources so a surviving local copy can be checked without making private or bulky
runtime logs part of Git.
Evidence JSON, JSONL, and text line endings are pinned to LF by the evidence directory's
`.gitattributes`, so the recorded SHA-256 values survive Windows checkouts.

Architecture views derived from the accepted seam and repository-owned operations are indexed in
[`diagrams/README.md`](diagrams/README.md): the
[`runtime DFD`](diagrams/runtime-data-flow.svg),
[`hardware and technology topology`](diagrams/hardware-tech-stack.svg), and
[`contracts, jobs, pipelines, and harnesses`](diagrams/contracts-jobs-pipelines.svg).

## Problem statement

Comfy and Lumberjacks each had working pieces, but they did not present one explicit, observable
contract for real game work. Acceptance required a real dedicated-server ZDO that survived Comfy's
Importance decision to cross the existing Gateway boundary, pass authentication and release
admission, reach the intended authoritative Valheim consumer, execute through `RPC_ZDOData`, and
produce a correlated result on both sides. A curl or serializer-only test was insufficient.

## Original failure mode and root cause

The pre-integration redirect body was the legacy schema-1 shape. It did not carry an artifact-backed
mod release, correlation ID, operation, source instance, Importance class, or idempotency key.
Importance classification existed as telemetry, not as the final network allow/drop boundary. The
Gateway receipt ingress accepted the legacy shape but could neither enforce the baked release nor
trace one item through its consumer result.

Consumer telemetry had a second seam defect: the heartbeat endpoint derived its recipient only from
an enrollment object. The local `private-plane` producer/consumer identity has no enrollment object,
so consumer fields could appear null even while poll and ACK used the legacy recipient scope.

The real runtime rehearsal also exposed two launch-path failures outside the wire contract: starting
the Linux game without the BepInEx wrapper bypassed the mod, and character-selection automation could
touch profile state before PlayFab login completed. Those failures explain why individually green
services had not previously produced this complete observation.

## Design changes accepted

- Comfy schema 2 carries `schema_version`, `source_instance`, `mod_release`, `operation`, and
  `window_id` once per batch. Each payload item carries `correlation_id`, `created_utc`, `recipient`,
  `importance_class`, and `idempotency_key` alongside the real ZDO payload.
- `caller_identity` remains transport metadata. The Gateway derives `private-plane`; it is not
  accepted from JSON.
- `ZdoIntegrationContract.ImportanceAllows` is now the final network gate. Rank `<= 4` crosses in
  the accepted configuration. Rejected work remains in Valheim's native `toSync` list.
- Schema-2 ingress fails closed unless the presented mod release equals the expected release baked
  into the Gateway image. Frozen schema 1 remains explicitly legacy and unadmitted for rollback.
- Recipient `legacy` is carried by the item and resolved to the existing recipient-scoped queue.
- The authoritative consumer preserves the correlation through `RPC_ZDOData`, readback,
  acknowledgement, and telemetry. Private-plane telemetry uses the same resolved scope as poll/ACK.
- The local harness launches the real Linux client through the BepInEx wrapper and waits for PlayFab
  readiness before automated character selection.

The effective, redacted configuration is preserved in
[`effective-config.json`](evidence/20260719-172149/effective-config.json).
Acceptance-time test and identity checks are preserved in
[`verification.json`](evidence/20260719-172149/verification.json).

## Final seam and sequence

The requested conceptual sequence placed Importance after release admission. The implementation
cannot honestly use that order: Importance rejection must occur before HTTP so a rejected item never
crosses the network. The actual accepted sequence is:

```mermaid
sequenceDiagram
    participant V as Dedicated Valheim server
    participant C as Comfy producer
    participant G as Gateway ingress
    participant Q as Recipient queue
    participant A as Authoritative Comfy consumer
    participant Z as ZDOMan

    V->>C: CreateSyncListPostfix(real post-sort toSync candidate)
    C->>C: Classify Importance + create correlation ID
    alt rank <= configured maximum
        C->>G: HTTP POST schema-2 zdo_redirect
        G->>G: Authenticate caller as private-plane
        G->>G: Admit mod_release against image-baked release
        G->>Q: Resolve legacy recipient and durably record envelope
        A->>G: Poll recipient-scoped pending queue
        G-->>A: Correlated ZDO envelope
        A->>Z: RPC_ZDOData(real payload)
        Z-->>A: Readback applied or safely superseded
        A->>G: ACK sequence
        A->>G: Correlated consumer telemetry
        G-->>C: Observable status/result surface
    else rank > configured maximum
        C-->>V: Leave item in native toSync; no HTTP submission
    end
```

| Transition | Evidence |
| --- | --- |
| Real candidate observed | `importance_candidate` rows in [`redirect-trace.jsonl`](evidence/20260719-172149/redirect-trace.jsonl). |
| Importance allowed/rejected | Adjacent `importance_allowed` and `importance_rejected` rows in the same trace. |
| HTTP submission | Positive `redirect` row plus Gateway acceptance in [`gateway-trace.txt`](evidence/20260719-172149/gateway-trace.txt). |
| Authentication | `caller_identity=private-plane` in the Gateway trace; the body does not own this field. |
| Release admission | Matching admitted release in the Gateway trace and both artifact identities in [`artifacts.json`](evidence/20260719-172149/artifacts.json). |
| Recipient resolution | `recipients=legacy` in the Gateway trace and `recipient_id=aggregate` conservation view in [`gateway-status.json`](evidence/20260719-172149/gateway-status.json). |
| Authoritative consumer | Active consumer and first correlation in [`consumer-status.json`](evidence/20260719-172149/consumer-status.json). |
| `RPC_ZDOData` result | `result=applied seq=44` in [`client-trace.txt`](evidence/20260719-172149/client-trace.txt); the committed consumer records this only after call and readback. |
| ACK | Gateway `acknowledged=560` and consumer `acknowledged=560` snapshots. |
| Correlated telemetry | First correlation/result in the consumer snapshot equals the producer's positive correlation. |

## Runtime proof

The real accepted item was correlation `cf43899a2861456eb603b5e06f408ee8`, a
`player_critical` candidate at rank 0. Producer evidence records candidate, allow, and redirect in
that order. The Gateway observation records caller `private-plane`, release
`m4-integration-20260719-r1`, recipient `legacy`, and the same correlation. The real headless
Valheim client records `result=applied seq=44` after `RPC_ZDOData` and readback. The compact evidence
set independently re-passes `tools/verify_comfy_lumberjacks_integration.py`; its byte-identical
verdict is [`verdict.json`](evidence/20260719-172149/verdict.json).

The harness also verified the DLL hash loaded inside both real runtime containers against the built
DLL before accepting the run. The server and client contract logs both report release
`m4-integration-20260719-r1`, schema 2, operation `zdo_redirect`.

## Negative proof

Correlation `1ed03fca7e60461f84f63a111c677987` was classified `support_piece`, rank 5,
against maximum rank 4. It has candidate and rejection rows, no allow/redirect row, and is absent
from both curated Gateway and client observations. The verifier fails if that correlation appears
on either downstream side.

The same ingress also received a deliberately wrong release
`m4-integration-20260719-r0`. It authenticated as `private-plane` but release admission rejected it
with `mod_release_incompatible` and HTTP 409 before queue delivery. This is supplemental evidence;
the primary negative is the pre-network Importance rejection.

## Why 1,826 receipts and 560 acknowledgements is expected

This is an early acceptance snapshot, not a completed conservation run:

- Gateway receipts: 1,826 total, 1,826 distinct, sequence 1 through 1,826, zero missing, zero
  duplicates, and zero empty bodies.
- Gateway acknowledged: 560.
- Gateway pending: 1,266.
- Conservation at capture: `560 acknowledged + 1,266 pending = 1,826 receipts`.

The producer was still filling the queue while the consumer worked. The consumer first polled the
then-available 560 envelopes, applied and acknowledged that complete group, then began another poll.
The poll maximum is 1,024, which explains the consumer heartbeat's separate `pending=1024`: it is
the consumer's last in-process batch depth, not the Gateway's authoritative remaining total.

The harness intentionally exits once at least one correlated fast-lane item has been applied and at
least one ACK has reached the Gateway. It does not wait for a full drain. Therefore the 560/1,826
ratio is expected for this acceptance condition and is not evidence of packet loss. It also is not
evidence that all 1,826 items eventually deliver. Full drain, terminal conservation, and retained
sealed receipt remain additional proof obligations.

## Harness audit

| Property | Assessment | Evidence and qualification |
| --- | --- | --- |
| Deterministic behavior | PASS | Fixed code/config produces the same asserted sequence and fail conditions. Two independent successful runs passed. |
| Byte-deterministic output | NOT CLAIMED | Window IDs, UTC timestamps, correlation GUIDs, container names, Steam timing, and Docker image IDs are deliberately run-unique. Comparing run directories byte-for-byte would be invalid. |
| Idempotent | PASS for observed lab state | Unique names avoid collisions; backups are per run; two successful runs and eleven failed attempts preserved the live-plugin tripwire. |
| Self-cleaning | PASS with one limitation | The final audit found zero temporary integration containers. Generated evidence directories and the built Gateway image intentionally remain. Cleanup exceptions are warned rather than promoted to a final nonzero exit; manual rollback verification is therefore mandatory for release evidence. |
| Success restoration | PASS | All six modified config/DLL inputs equal their final-run backups; the original server runtime DLL also equals its backup. |
| Failure restoration | PASS by control-flow audit and repeated observation | Mutations occur only after backups and are inside `try/finally`. Eleven failed attempts reached the unchanged tripwire. From the third attempt onward, all six backed-up inputs equal the final restored state; the first two predated an intentional client-config evolution. |
| Repeat safety | PASS within prerequisites | The harness refuses a running client or stopped original server, creates unique local resources, and restores/removes only resources it owns. It does temporarily stop and restart the original local server. |

The detailed post-run comparison is
[`rollback-audit.json`](evidence/20260719-172149/rollback-audit.json).

## Rollback verification

- Original container `comfy-valheim-lab-valheim-server-1` is running again on its original image.
- Original runtime DLL SHA-256 is
  `4f87c698855aa190c34ac56faf7769107e4027a5ab1852d3dc8cb8f93eb9ed16`, equal to the backup.
- Server config, server seed DLL, client shared config/DLL, and client runtime config/DLL all hash
  exactly to their final-run backups.
- Windows live-plugin `LastWriteTime` remained
  `2026-07-18T16:28:00.4177432-07:00` from start to finish.
- No `comfy-lj-gateway-*`, `comfy-lj-server-*`, or `comfy-lj-client-*` container remains.
- Both repositories were clean before this acceptance-only documentation slice. They must be clean
  again after its commit.

## Artifact inventory

| Artifact | Accepted identity |
| --- | --- |
| Comfy DLL | SHA-256 `08e3f7b885e8920a51420089f3e860c9dc4926f58f7b2efb30e0b267a55da371`; file version `0.5.31`; release metadata `m4-integration-20260719-r1`. |
| Gateway image | `sha256:4bdee6dcec31a340dedeb1b1f2f7c5f2e26b12f1dac3660b70e7c8714e0f4037`. |
| Gateway payload | `/app/Game.Gateway.dll` SHA-256 `46cc4ca853c8d4899badf1e7e32f424f2cae99c7d8b4b1234bcd202615ddf481`; expected-mod release metadata `m4-integration-20260719-r1`. |
| Contract | Submission schema 2, operation `zdo_redirect`, recipient `legacy`; existing consumer delivery schema 1. |
| Runtime window | `comfy-lj-integration-20260719-172149`. |
| Full generated source | Intentionally ignored; per-file sizes and SHA-256 values retained in the evidence manifest. |
| Curated evidence | Committed files and SHA-256 values retained in the evidence manifest. |

The image ID is a local Docker content identity, not a registry digest. No image was pushed.

## Commit inventory

| Repository | Commit | Purpose |
| --- | --- | --- |
| Comfy | `dd7806185e88735be032161860a72c0a59b801a1` | Producer contract, Importance gate, consumer correlation, runtime join repair, harness, verifier, and tests. |
| Lumberjacks | `fb55441f562ee3410087287d33b609dc05ba1fea` | Schema-2 release admission, authenticated receipt handling, recipient routing, correlated telemetry, and tests. |
| Lumberjacks | `e7cef6e9819f4d5f4d462f6d74860611fddb046a` | Required cross-repository public audit note; direct child of the Gateway code commit. |
| Comfy | This document's containing commit | Acceptance documentation and curated evidence only; it does not change the accepted runtime implementation. |

All three named Git objects were resolved directly during acceptance. The generated run originally
referenced the final Lumberjacks audit commit, while `fb55441...` is the code-bearing parent; both
are recorded to remove that prior ambiguity.

## Reproduction

Prerequisites are the existing stopped headless-client container, running original local server,
Steam-authenticated client state, Docker network, and local Valheim/BepInEx files described by the
harness. From `C:\work\comfy`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\work\comfy\fieldlab\scripts\Invoke-ComfyLumberjacksIntegration.ps1
```

The command rebuilds the current Comfy DLL with an isolated plugin output, rebuilds the Gateway with
the same explicit release, prints redacted effective configuration, runs the real positive and
negative paths, verifies the loaded DLL hashes, and restores local state in `finally`.

A new run is a behavioral reproduction, not a byte-for-byte reproduction: it will have new temporal
IDs and may have a different Docker image ID. The accepted artifact identities above remain tied to
the recorded implementation commits and window.

The committed compact packet can be rechecked without launching Valheim:

```powershell
C:\Users\derek\AppData\Local\Programs\Python\Python312\python.exe `
  tools\verify_comfy_lumberjacks_integration.py `
  --server-jsonl fieldlab\integration\evidence\20260719-172149\redirect-trace.jsonl `
  --server-log fieldlab\integration\evidence\20260719-172149\server-trace.txt `
  --client-log fieldlab\integration\evidence\20260719-172149\client-trace.txt `
  --gateway-log fieldlab\integration\evidence\20260719-172149\gateway-trace.txt `
  --status fieldlab\integration\evidence\20260719-172149\gateway-status.json `
  --consumer fieldlab\integration\evidence\20260719-172149\consumer-status.json `
  --window comfy-lj-integration-20260719-172149 `
  --release m4-integration-20260719-r1
```

## Acceptance criteria satisfied

- [x] A real dedicated Valheim server loaded the exact intended Comfy DLL.
- [x] Real `CreateSyncList` work reached the existing Importance classifier and final network gate.
- [x] One allowed item crossed the existing HTTP transport; no curl stood in for the mod.
- [x] Gateway authentication derived `private-plane` rather than trusting body identity.
- [x] Gateway release admission matched the releases embedded in both shipped artifacts.
- [x] The item routed to `legacy` and reached the real authoritative Valheim consumer.
- [x] The consumer invoked `RPC_ZDOData`, validated readback, ACKed, and reported the correlation.
- [x] Producer, Gateway, and consumer observations correlate on one ID.
- [x] One Importance-rejected real item remained off the network.
- [x] One wrong-release submission was rejected before delivery.
- [x] The implementation has unit/repository coverage and a repeatable real-runtime command.
- [x] The original local runtime and repository state were restored.

Acceptance reran 15/15 Comfy contract tests, 13/13 Comfy repository tests, 159/159
Gateway tests, and the compact correlation verifier. The Python suite retained its existing fixture
socket `ResourceWarning` messages, and the Gateway build retained its existing Entity Framework
9.0.1/9.0.4 reference-conflict warning; neither suite reported a failed test.

## Release readiness

### READY

- Local one-server/one-consumer schema-2 vertical slice.
- Artifact-backed release agreement and wrong-release rejection.
- Private-plane authentication on the existing Gateway ingress.
- Importance-approved submission and Importance-rejected network absence.
- Legacy recipient routing, real `RPC_ZDOData`, readback, ACK, and correlated telemetry.
- Repeatable local harness with observed success/failure cleanup and a committed compact verifier
  packet.

### NOT READY

- Deployment to the terminated P7 VM or proof against the public endpoint, TLS, and enrolled guest
  credentials.
- Full drain of the 1,826-item window, terminal conservation, or a sealed retained receipt.
- Gateway restart/WAL replay/compaction proof for this schema-2 run.
- Two real consumers, recipient isolation, reconnect/takeover, or producer outbox loss safety.
- Durable correlated consumer telemetry: the current status service is in-memory and labels its
  snapshot `stability=unstable`.
- World-save before/after integrity for this integration run.
- Non-developer guest enrollment or production volunteer readiness.

### FUTURE

- Promote cleanup warnings to a final harness failure when any restore/remove operation fails.
- Add a separately scoped full-drain/sealed-conservation acceptance window.
- Bound or summarize bulk correlation logging after durable per-item traceability exists elsewhere.
- Image reproducibility and registry digest policy; image-ID reproducibility is deliberately outside
  this acceptance.

## Remaining risks

| Rank | Risk | Severity | Probability | Disposition |
| --- | --- | --- | --- | --- |
| 1 | Local private-plane success may not survive public TLS/enrollment/deployment configuration. | High | Medium | NOT READY; requires live P7 proof under operator control. |
| 2 | This snapshot proves one result, not full delivery or terminal conservation; 1,266 items remained pending at capture. | High | High | NOT READY; run a full-drain sealed window. |
| 3 | Only recipient `legacy` and one real consumer were exercised. | High | Medium | NOT READY; M4a/M4b isolation and multi-client proof. |
| 4 | Consumer correlation telemetry is in-memory and disappears on Gateway restart. | Medium | High | NOT READY for durable evidence; retain raw logs or add durable result records in the owning milestone. |
| 5 | Harness cleanup catches and warns, so a future restore failure could coexist with an otherwise green proof. | Medium | Low | Manual rollback audit required; harden later without changing this accepted run. |
| 6 | No world-save hash comparison was captured for this window. | Medium | Low | NOT READY for save-integrity claims; no such claim is made here. |
| 7 | Run IDs, GUIDs, timing, and local Docker image IDs are intentionally non-deterministic. | Low | High | Compare contracts, hashes, and verifier invariants, not run-directory bytes. |

## Explicitly not proven

This acceptance does **not** prove a deployed production path, public TLS, guest enrollment, Steam
identity admission, two-client behavior, recipient isolation, producer outbox recovery, complete
queue drainage, exactly-once delivery across restart, WAL replay/compaction, durable correlated
telemetry, world-save integrity, performance under sustained load, or a non-developer onboarding
experience. It also does not claim the Gateway image ID is reproducible. The P7 VM remained
TERMINATED; nothing was pushed, deployed, promoted, or restarted externally.
