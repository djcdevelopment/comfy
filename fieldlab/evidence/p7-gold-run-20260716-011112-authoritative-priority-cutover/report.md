> **Publication copy (M0/A5).** Sanitized copy of the immutable local FieldLab run packet
> `fieldlab/runs/20260716-011112-valheim-lumberjacks-authoritative-priority-cutover/report.md`
> (raw file SHA-256 `cc9fa1ff3930d95108ac4df19bf699f33b176ad5e6e0fa1dcfbb43b4b7e3cbd9`).
> Sole redaction: the deployment public IPv4 address is replaced with `<gcp-public-ip>`
> (5 occurrences). No other content was changed. The `acceptance-snapshot.json` beside this
> file is byte-identical to the raw original (SHA-256 `51cf67d3533b97c5eb26f7cf767c93aa061218ef5007dca1773e595e87070e26`).

# Field report: authoritative priority ZDO cutover victory

Date: 2026-07-16 UTC  
Session: `20260716-011112-f7e72fb4`  
Target: GCP P7 / `ComfyEra16`  
Result: **pass - single-client authoritative priority window complete**

## Goal

Prove that a real enrolled Valheim player can join the GCP server and receive the
complete observed ZDO replication window from Lumberjacks, with priority metadata
driving load order and without native ZDO fallback.

## Result

The client closed all 83,220 Gateway receipts with 83,220 acknowledgements and zero
pending records. Every envelope was priority tagged. The client applied 72,946
records and safely superseded 10,274 older records; those values sum exactly to the
acknowledged total. No record was rejected, duplicated, or retried, and the clean
session recorded no poll, acknowledgement, or telemetry failure.

| Gate | Observed | Result |
|---|---:|---|
| Mode | `lumberjacks-primary` | pass |
| Window | `p7-primary-v1` | pass |
| Receipts / acknowledged | 83,220 / 83,220 | pass |
| Pending / complete | 0 / `true` | pass |
| Coverage / native-only | 100% / 0 | pass |
| Priority tagged | 83,220 | pass |
| Fast lane | 47,534 (57.1%) | pass |
| Applied + superseded | 72,946 + 10,274 = 83,220 | pass |
| Reject / duplicate / retry | 0 / 0 / 0 | pass |
| Poll / ack / telemetry failure | 0 / 0 / 0 | pass |
| Maximum client queue | 960 of a 1,024-record poll | bounded |
| First peer to first apply | 6.72 seconds | observed |
| First peer to complete | 102.11 seconds | observed |
| Final acceptance sample | 121.2 FPS; p95 8.5 ms | healthy sample |

The player intentionally flew rapidly into a direction not previously visited and
reported that the trees appeared impressively quickly. This supports the priority
experience goal but remains a player observation, not a substitute for the counters.

## What was actually authoritative

In primary mode, the server-side mod received Valheim's peer-specific ZDO sync list,
preserved its source ordering, classified each item using the production copy of the
FieldLab priority rules, posted it to the Gateway, and suppressed the corresponding
native ZDO send. The Gateway sequenced and persisted each receipt in `redirect.wal`.

The OMEN mod polled the shared Gateway endpoint directly with its per-enrollment
credential. A background worker decoded batches of up to 1,024, while the Unity main
thread applied at most 64 per update through `RPC_ZDOData`. The consumer validated
applications, suppressed duplicates, retried failures, and acknowledged only applied
or safely superseded sequence numbers.

Steam authentication, the native Valheim peer connection, server simulation, native
candidate relevance selection, and non-ZDO RPCs remain native. The correct claim is
therefore **100% Lumberjacks delivery of the observed single-client ZDO window**, not
replacement of every byte Valheim sends.

## How the work converged

1. `20260708-042303-valheim-lumberjacks-priority-load-order` observed 11,544 real
   object rows at six Era16 route stops and established the priority vocabulary.
2. Priority mirror/gateway-plan runs exercised ordered side-channel contracts without
   mutating native replication.
3. Redirect and injection gates proved native suppression, receipt equality, durable
   replay, and rendered `RPC_ZDOData` application.
4. The consumer implementation added the missing production loop: background polls,
   Unity dispatch, validation, success-only acknowledgement, retry, duplicate
   suppression, timeout rollback, and telemetry.
5. ComfyNetworkSense 0.5.31 unified the priority classifier with the redirect path,
   started primary redirect at peer readiness, used 1,024-record poll/ack batches, and
   retained a 64-apply frame budget. The Gateway sorted pending records by priority
   rank, distance, and sequence.
6. One-time Steam OpenID invitations issued a per-player enrollment ID and token. The
   client then used `http://<gcp-public-ip>:42317` directly; the earlier OMEN SSH tunnel
   and external poller were no longer in the gameplay path.
7. Guarded deployment produced a rollback backup and verified the runtime and
   cold-start DLL hashes. The WAL was compacted from 168,987,408 to 256,244 bytes
   (99.848%) before the clean proof.
8. The preceding session proved rapid priority draining but experienced two recovered
   HTTP connection resets. Valheim was restarted, and this clean session completed
   with all transport-failure counters at zero.

## Reproduce

### 1. Verify source before deployment

From `C:\work\lumberjacks`:

```powershell
& C:\work\dotnet9\dotnet.exe test `
  tests\Game.Gateway.Tests\Game.Gateway.Tests.csproj
```

Expected snapshot: 46 passed, 0 failed. The current test project reports pre-existing
Entity Framework assembly-version warnings.

From `C:\work\comfy`:

```powershell
dotnet build `
  C:\work\comfy\network\mod\ComfyNetworkSense\ComfyNetworkSense.csproj `
  -c Release
```

Expected: build succeeds with zero warnings and zero errors. For this victory build,
the DLL version is `0.5.31` and SHA-256 is
`b31697d2a0cbe47b86c32b33d19fb9445e21af0cfe51687cb5afe871a3d7d77b`.

### 2. Deploy and verify the mod

Close the local Valheim process before replacing the OMEN plugin. Deploy the server
copy with the guarded script and retain the returned backup path:

```powershell
& C:\work\comfy\infra\gcp\p7\scripts\deploy-network-sense.ps1 `
  -ManifestPath `
    C:\work\comfy\fieldlab\runs\releases\p7-primary-v1-0.5.31-clean.json
```

Verify both OMEN and the manifest report the expected hash. The live server backup for
this build is `/mnt/comfy-p7/backups/comfynetworksense/20260716T004955Z`.

### 3. Enroll a client once

The administrator generates a one-use, 24-hour Steam sign-in link without copying the
admin key off GCP:

```powershell
& C:\work\comfy\infra\gcp\p7\scripts\new-player-invite.ps1
```

The player opens only that newly generated link, signs in through Steam OpenID, and
copies the returned `[Lumberjacks]` values into
`BepInEx\config\djcdevelopment.valheim.comfynetworksense.cfg`. Treat the returned
access key as a secret; never put it in a report, screenshot, commit, or chat log.

Required client values are the direct Gateway URL, `p7-primary-v1` authoritative
window, the issued enrollment ID, the issued access key, and
`zdoAuthoritativeConsumerEnabled = true`.

### 4. Establish a clean baseline

Before the player joins:

- Gateway `/health` returns `status=ok`;
- the server heartbeat is fresh and reports mod `0.5.31`;
- mode is `lumberjacks-primary`, coverage is 100%, and native-only is zero;
- `p7-primary-v1` has zero pending records;
- WAL persistence is healthy and disk space is sufficient;
- the GCP and OMEN DLL hashes match the release manifest.

The trusted-pilot dashboards are:

```text
http://<gcp-public-ip>:42317/networksense
http://<gcp-public-ip>:42317/community
```

### 5. Launch the real direct session

```powershell
& C:\work\comfy\infra\gcp\p7\scripts\start-direct-session.ps1
```

This health-checks the direct Gateway and launches Valheim with
`+connect <gcp-public-ip>:2456`. No OMEN SSH tunnel or standalone forwarding poller is
required. Select the test character, join, and exercise spawn, a dense build, and fast
travel into an uncached region.

### 6. Capture the closure before disconnect

Poll the live cutover surface during the run:

```powershell
Invoke-RestMethod `
  http://<gcp-public-ip>:42317/api/v0/telemetry/cutover |
  ConvertTo-Json -Depth 20
```

Pass only when the acceptance rule in
`C:\work\lumberjacks\docs\network\valheim-lumberjacks-p7-overview.md` is satisfied in
one coherent window. Copy the closure sample before disconnecting; a later empty
window can reset live receipt counters while retaining consumer totals.

### 7. Roll back if a gate fails

```powershell
& C:\work\comfy\infra\gcp\p7\scripts\rollback-network-sense.ps1 `
  -BackupPath /mnt/comfy-p7/backups/comfynetworksense/<timestamp>

& C:\work\comfy\infra\gcp\p7\scripts\rollback-gateway.ps1 `
  -BackupPath /mnt/comfy-p7/backups/gateway/<timestamp>
```

After either rollback, verify health, runtime/cold-start hashes, mod readiness, server
readiness, and an empty queue before admitting primary traffic.

## Evidence

- Machine-readable gate: [acceptance-snapshot.json](acceptance-snapshot.json)
- Release manifest:
  `C:\work\comfy\fieldlab\runs\releases\p7-primary-v1-0.5.31-clean.json`
- Raw client telemetry:
  `C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-network-sense\telemetry-client.jsonl`
  (acceptance sample line 303,910; captured file size 233,984,934 bytes; SHA-256
  `8e7141c81a9fd583545250236c934bb7f19be77efc14d187da52e09edb88b60d`)
- Prior priority route:
  `C:\work\comfy\fieldlab\runs\20260708-042303-valheim-lumberjacks-priority-load-order\report.md`
- Gateway source backup for the final deployment:
  `/mnt/comfy-p7/backups/gateway/20260716T005900Z`

## Remaining boundary

This report is the single-client victory, not the multi-client finish line. The next
correctness change is recipient-scoped queues/acknowledgements, followed by a two-real-
client window proving that each Steam-enrolled consumer receives its own relevant ZDO
set without cross-acknowledgement. Transport hardening, automatic WAL management,
capacity measurement, and right-sizing follow that correctness gate.
