# P7 deployment identifiers — captured 2026-07-19 ~06:44 UTC

Captured live immediately before stopping the VM, during the session that found the
release-gate artifact-boundary defect. All values read from the running host, not
from repo records.

## Instance

| Field | Value |
| --- | --- |
| VM | `comfy-lumberjacks-p7` |
| Project | `lumberjacks-exp-20260711-djc` |
| Zone | `us-west1-b` |
| Machine type | `n2-highmem-2` (2 vCPU / 16 GB) |
| External IP | `8.231.129.249` (static, survives stop) |
| Internal IP | `10.27.0.2` |
| Public Gateway | `http://8.231.129.249:42317` (**not** `:4000` — no firewall rule) |
| Valheim | `8.231.129.249:2456-2457/udp` |
| Uptime at capture | 30 min (started this session; prior state `TERMINATED`) |
| Memory at capture | 10841 MB used / 15988 MB total, 5147 MB available |

> Machine type is `n2-highmem-2`. `docs/google-cloud-stage1-runbook.md:22,30-33`
> records this VM as `n2-highmem-8` and attributes an earlier cutover OOM to a
> smaller instance. ~~Unreconciled.~~
>
> **RECONCILED 2026-07-20.** The capture above is correct and the runbook was stale.
> Re-read from the GCP API on 2026-07-20: machine type `n2-highmem-2`, status
> `TERMINATED`, disks 40 GB boot + 150 GB state (both `pd-balanced`). The 8 -> 2
> downsize was a deliberate cost decision, not a regression. The runbook's
> 2026-07-12 paragraphs are now explicitly marked historical and carry a
> reconciliation block; `fieldlab/status/program-status.json` (`infra[0].detail`)
> and `fieldlab/integration/diagrams/hardware-tech-stack.svg` were corrected in the
> same slice.

## Durable pin (`/etc/comfy-p7/environment`, mode 0600)

```
LUMBERJACKS_GATEWAY_IMAGE=lumberjacks-gateway:m1-clean-20260717-r1
LUMBERJACKS_VERSION=a776fdf
LUMBERJACKS_PLAYER_PORT=42317
```

`LUMBERJACKS_AUTHORITATIVE_WINDOW_ID` not set explicitly; compose default
`p7-primary-v1` applies.

## Containers

| Container | Image | Status |
| --- | --- | --- |
| `comfy-lumberjacks-p7-gateway-1` | `lumberjacks-gateway:m1-clean-20260717-r1` | Up |
| `comfy-lumberjacks-p7-valheim-server-1` | `e8b13da3c44f` | Up |
| `comfy-lumberjacks-p7-postgres-1` | `postgres:16-alpine` | Up (healthy) |
| `comfy-lumberjacks-p7-eventlog-1` | `comfy-lumberjacks-p7-eventlog` | Up |
| `comfy-lumberjacks-p7-progression-1` | `comfy-lumberjacks-p7-progression` | Up |
| `comfy-lumberjacks-p7-operatorapi-1` | `comfy-lumberjacks-p7-operatorapi` | Up |

## Gateway image identity

- Running image id: `sha256:3576d8e03fb49b6a03f920a367c69cd841fffa74c07cfecbcc065f1ff89fee55`
- Tagged **both** ways, same id `3576d8e03fb4`, built `2026-07-17 04:50:52 UTC`:
  - `lumberjacks-gateway:m1-clean-20260717-r1`
  - `lumberjacks-gateway:drill-m1-clean-20260717-r1`

So the m1 promotion does carry both the `drill-` and clean tags — the tag-convention
gap is narrower than the scripts alone suggest.

Other images on disk:

| Tag | Id | Built |
| --- | --- | --- |
| `lumberjacks-gateway:drill-m0-clean-20260716-r2` | `141bd9e5a2ce` | 2026-07-16 07:06:44 |
| `lumberjacks-m0-clean:a7c47b5` | `141bd9e5a2ce` | 2026-07-16 07:06:44 |
| `comfy-lumberjacks-p7-gateway:latest` | `358f5e11e35b` | 2026-07-16 00:58:38 |

`358f5e11e35b` is the M0-era rollback image referenced as `run-promotion-drill.ps1`
default `-RollbackImageId`. Confirmed still present.

## THE DEFECT — baked release id absent from the shipped image

Read from inside the running container, against `/app/Game.Gateway.dll`:

```
key_present=0
any_release_id=(none)
```

The shipped Gateway assembly carries **no** `LumberjacksExpectedModRelease`
attribute and no `m<n>-clean-<yyyymmdd>-r<n>` string of any form. Therefore
`ValheimReleaseIdentity.ExpectedModRelease` is `null` and the release gate is
disabled — arming `StrictReleaseEnabled` would short-circuit on
`!string.IsNullOrEmpty(ExpectedModReleaseId)` and never fire.

Cause: `C:\work\Lumberjacks\Dockerfile` (last modified `9068486`, 2026-03-27) does
not pass `-p:LumberjacksExpectedModRelease` to `dotnet publish`; the mechanism landed
in `9def403` on 2026-07-17, four months later. `Game.Gateway.csproj:13` defaults the
property to `dev`, which `ReadBakedValue()` maps to `null`.

`New-ReleaseCut.ps1` verifies a locally published DLL under
`src/Game.Gateway/bin/Release`, which is **not** the artifact that ships.

## Mod artifact (frozen — untouched this session)

| Path | SHA-256 |
| --- | --- |
| `/mnt/comfy-p7/valheim/config/bepinex/plugins/ComfyNetworkSense.dll` | `94a3843ef8042adceaca6bc4d5c0c38c7c8dc5a1aa05b5f2a3019879840ba3a8` |
| `/mnt/comfy-p7/valheim/data/bepinex/BepInEx/plugins/ComfyNetworkSense.dll` | `94a3843ef8042adceaca6bc4d5c0c38c7c8dc5a1aa05b5f2a3019879840ba3a8` |
| `/mnt/comfy-p7/import/server-state/config/bepinex/plugins/ComfyNetworkSense.dll` | `827fc6b2c3f2781039be9e9cb31c3db839a3e93ac38a418527cf17fcdc4f816d` |
| `/mnt/comfy-p7/import/server-state/data/bepinex/BepInEx/plugins/ComfyNetworkSense.dll` | `827fc6b2c3f2781039be9e9cb31c3db839a3e93ac38a418527cf17fcdc4f816d` |

The two live BepInEx paths agree and match the frozen 0.5.31 hash of record. The two
under `import/server-state/` carry a **different** hash — a staging/import copy, not
loaded by the running server. Noted, not investigated.

Working-tree source `ComfyNetworkSense.cs:39` reads
`public const string ReleaseId = "dev";` — the mod has never been cut with a real
release id, which is consistent with `StrictReleaseEnabled` having to stay off.

## Durable queue

- WAL: `/mnt/comfy-p7/lumberjacks/zdo-queue/redirect.wal`, **251,446,277 bytes**
  (~240 MB) at capture; ~209 MB at boot, so this session added ~40 MB.
- Replayed clean on boot; `persistence_healthy: true` throughout.
- No automatic compaction. `POST /valheim/zdo-redirect/compact` exists and was **not**
  run.

## Session observations (see `telemetry-final.txt`, `gateway-container.txt`)

- Login burst produced **101,413 receipts** on `p7-primary-v1`, drained in exact
  1,024-envelope batches; `pending` fell monotonically. No gap or saturation signals.
- `active_consumers: 0`, `applied: 0`, `superseded: 0` throughout, and
  `heartbeat_stale: true`. `applied`/`superseded` are client-self-reported with a
  15 s staleness window (`ValheimZdoConsumerTelemetryService.StaleAfter`), so they are
  a live gauge, not a durable ledger. Unexplained: the queue drained while
  `active_consumers` read 0. Needs an in-game repro to settle.
- Boot error, pre-existing and tolerated: `42P01: relation "regions" does not exist`
  → *"Could not load persisted data — running with in-memory defaults only."* Does not
  affect ZDO delivery (in-memory service + WAL, no DB).
- `serviceContext.version` reports `a776fdf`, a bare commit sha, not a release tag.

## Files in this directory

- `deployment-identifiers.md` — this file
- `gateway-container.txt` — 379 lines, full gateway log for the session (boot 06:13:42 → 06:44 UTC)
- `telemetry-final.txt` — `/health`, `/api/v0/telemetry/cutover`, `/api/v0/valheim/zdo-consumers/p7-primary-v1` at capture
