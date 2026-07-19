# Comfy to Lumberjacks vertical seam

This map is code-derived and names the one path exercised by
`fieldlab/scripts/Invoke-ComfyLumberjacksIntegration.ps1`.

| Boundary | Existing code used by the slice |
| --- | --- |
| Real server work | Harmony postfix `ZdoRedirectPatches.CreateSyncListPostfix` receives Valheim's post-`ServerSortSendZDOS` `toSync` list. |
| Importance decision | `LumberjacksPriorityClassifier.Classify` followed by `ZdoIntegrationContract.ImportanceAllows`; rejected work remains in `toSync`, allowed work is removed for redirect. |
| Producer | `ZdoRedirectRunner.Redirect` serializes the actual ZDO and `PostBatch` sends schema 2 to the existing `/valheim/zdo-redirect/receipts` ingress. |
| Authentication | `ValheimClientAccessMiddleware` derives `private-plane` from the server container's network address and grants Producer; `caller_identity` is transport metadata and is never trusted from JSON. |
| Release admission | `ValheimZdoRedirectAdmissionPolicy` compares schema-2 `mod_release` with `ValheimReleaseIdentity.ExpectedModRelease`, which is baked into `/app/Game.Gateway.dll` in the image. |
| Routing | The payload names recipient `legacy`; `ValheimZdoRedirectService` stores it in that existing queue and consumer poll/ack scope resolves to the same server-derived recipient. |
| Consumer | `ZdoAuthoritativeConsumerRunner` polls the existing pending surface, invokes Valheim's `ZDOMan.RPC_ZDOData`, validates readback, acknowledges the sequence, and posts consumer telemetry. |
| Result | The client log and `/api/v0/valheim/zdo-consumers/{window}` expose `last_correlation_id` and `last_operation_result`; Gateway accepted logs carry caller, release, recipient, and correlation. |

The seam is: `ZdoRedirectPatches.CreateSyncListPostfix` gives
`ZdoRedirectRunner.Process` a real post-native-filter ZDO, which emits schema-2
`zdo_redirect` JSON over HTTP to `/valheim/zdo-redirect/receipts`; Lumberjacks
authenticates it as `private-plane`, admits the DLL's baked mod release, routes
it to `legacy`, and `ZdoAuthoritativeConsumerRunner` invokes `RPC_ZDOData` and
exposes completion through correlated consumer telemetry and acknowledgement.

## Schema 2 field ownership

| Field | Ownership |
| --- | --- |
| `schema_version`, `source_instance`, `mod_release`, `operation`, `window_id` | Submission body metadata, once per batch. |
| `correlation_id`, `created_utc`, `recipient`, `importance_class`, `idempotency_key` | Metadata on each item in `payload`. |
| ZDO uid, revisions, prefab, position, priority rank/reason, distance, and `body_b64` | Each item's actual game payload. |
| `caller_identity` | Gateway-derived transport metadata; logged/returned but never accepted from the body. |

Schema 1 remains a named, unadmitted rollback shape for the frozen 0.5.31 cut.
It does not satisfy this integration contract. The production-shaped proof is
schema 2 and fails closed when the Gateway image lacks a baked expected release.
