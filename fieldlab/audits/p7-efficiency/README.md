# P7 Lumberjacks efficiency and tenet audit

This audit targets the live GCP P7 deployment and the OMEN fieldlab controller.
It is deliberately separate from runtime cutover code: an audit run must not
change authority mode, restart Gateway, or mutate the Valheim world.

The evidence contract follows `Lumberjacks/docs/network/evidence-index.md`:
claims are split into design intent, implementation, verification, and client
consumption. Lab projections, shared serialization, Gateway transport, and
actual client application are recorded as separate controls.

## Run

From PowerShell:

```powershell
.\audit-manifest.ps1
```

Optional parameters can point at a different fieldlab or SSH target:

```powershell
.\audit-manifest.ps1 -SshTarget comfy-p7 -IncludeRemote
```

The script writes a timestamped, machine-readable manifest under `runs/` and
does not restart services or edit deployment configuration. Remote collection
is best-effort unless `-RequireRemote` is supplied.

## Initial controls

| Control | Evidence required | Initial status |
|---|---|---|
| Authoritative coverage | cutover telemetry, receipt/apply/ack counts | UNRUN |
| No mixed authority | native-only count remains zero during primary window | UNRUN |
| Correct acknowledgement | apply result precedes ack for every sequence | UNRUN |
| Duplicate suppression | duplicate input and duplicate application counters | UNRUN |
| Durable recovery | WAL replay after Gateway restart, no gaps or false acks | UNRUN |
| AoI/interest | per-client relevance and delivered entity counts | UNRUN |
| Wire efficiency | raw payload/envelope/transport byte accounting | UNRUN |
| Main-thread cost | client frame-time and apply-batch telemetry | UNRUN |
| Resource efficiency | CPU, memory, disk I/O, WAL/log growth | UNRUN |
| Operational efficiency | one-command deploy/run/pull/gate and rollback timing | UNRUN |
| Evidence quality | commit, versions, timestamps and raw artifacts retained | UNRUN |

No multi-client widening is authorized by this document. The single-client
authoritative window must pass first.
