# P7 primary V1 authoritative priority ZDO victory - ComfyNetworkSense 0.5.31

Date: 2026-07-16 UTC

Environment:

- GCP deployment: `comfy-lumberjacks-p7`
- Gateway image:
  `sha256:358f5e11e35b54367a83d4e52ea3d47c0346e62a82ed357c2ff403eafafcd0a2`
- ComfyNetworkSense: `0.5.31`
- OMEN/GCP/cold-start DLL SHA-256:
  `b31697d2a0cbe47b86c32b33d19fb9445e21af0cfe51687cb5afe871a3d7d77b`
- Session: `20260716-011112-f7e72fb4`
- Consumer: `4e4c6475430d`
- Enrollment/window: `p7-primary-v1`
- Client path: authenticated direct HTTP to GCP `:42317`; no OMEN tunnel or
  standalone poller
- Scope: one enrolled client, persistent all-prefab (`*`) ZDO redirect

## Result

**PASS.** The client joined the real `ComfyEra16` server and closed the complete
observed ZDO window through Lumberjacks priority delivery.

| Gate | Observed |
|---|---:|
| mode | `lumberjacks-primary` |
| coverage / native-only | 100% / 0 |
| Gateway receipts / acknowledgements | 83,220 / 83,220 |
| pending / complete | 0 / `true` |
| priority tagged | 83,220 (100%) |
| priority fast lane | 47,534 (57.1%) |
| exact applies / safe supersessions | 72,946 / 10,274 |
| exact + superseded | 83,220 |
| reject / duplicate / retry | 0 / 0 / 0 |
| poll / acknowledgement / telemetry failure | 0 / 0 / 0 |
| maximum client queue | 960 |
| peer-ready to first application | 6.721 seconds |
| peer-ready to complete | 102.114 seconds |
| acceptance frame sample | 121.2 FPS; p95 8.5 ms |
| durable queue / persistence healthy | `true` / `true` |

The player intentionally flew rapidly through a direction not previously visited and
reported that tree pop-in kept pace impressively. This is qualitative experience
evidence; the table is the authority gate.

## Proven implementation path

The server-side mod intercepted Valheim's peer-specific ZDO list, preserved the
source order, attached the shared FieldLab priority tier/rank/reason/distance, posted
each receipt to the Gateway, and suppressed native ZDO delivery. The Gateway persisted
the records in `redirect.wal` and returned batches ordered by priority rank, distance,
and sequence.

The client mod polled in the background in batches of up to 1,024, suppressed
duplicates, and marshalled no more than 64 applications per update to Unity's main
thread. It invoked and validated `RPC_ZDOData` and acknowledged only successful
applications or safe supersessions. The zero failure/retry counters above come from
a fresh Valheim process; the preceding session's two recovered HTTP resets are not
silently merged into this clean window.

## Provenance

- Machine-readable snapshot:
  `C:\work\comfy\fieldlab\runs\20260716-011112-valheim-lumberjacks-authoritative-priority-cutover\acceptance-snapshot.json`
- Full reproduction report:
  `C:\work\comfy\fieldlab\runs\20260716-011112-valheim-lumberjacks-authoritative-priority-cutover\report.md`
- Client telemetry:
  `C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-network-sense\telemetry-client.jsonl`
- Acceptance sample: line 303,910
- Telemetry file at capture: 233,984,934 bytes; SHA-256
  `8e7141c81a9fd583545250236c934bb7f19be77efc14d187da52e09edb88b60d`
- Release manifest:
  `C:\work\comfy\fieldlab\runs\releases\p7-primary-v1-0.5.31-clean.json`
- Gateway tests: 46 passed, 0 failed on 2026-07-16
- Mod build: 0 warnings, 0 errors on 2026-07-16
- Server plugin backup:
  `/mnt/comfy-p7/backups/comfynetworksense/20260716T004955Z`
- Gateway source backup: `/mnt/comfy-p7/backups/gateway/20260716T005900Z`

## Claim boundary and next gate

This proves 100% Lumberjacks delivery of the observed single-client ZDO window. It
does not claim replacement of Steam authentication, the native Valheim peer
connection, server simulation, Valheim's candidate relevance selection, or non-ZDO
RPCs.

The current P7 queue is shared. The next correctness gate is recipient-scoped pending
delivery and acknowledgement followed by two simultaneous real Steam clients proving
that neither can consume or acknowledge the other's relevant ZDOs.
