# P7 deployment and operator-efficiency audit

Audit time: 2026-07-15 19:02 UTC
Scope: OMEN controller, IAP tunnel, GCP VM `comfy-lumberjacks-p7`, Gateway and Valheim containers.
Method: read-only inspection; no authority mode, world data, or service configuration was changed.

## Executive result

The deployment is operational, private, and substantially over-provisioned for the
current single-client window. The main efficiency risk is not compute capacity; it
is release provenance and operator repeatability. The local OMEN plugin and the GCP
Valheim plugin have different hashes, and the Gateway image has no source-revision
label. This means a cold start cannot currently be proven to reproduce the tested
artifact. Rollback files exist, but rollback is a manual file-copy procedure rather
than a single verified command.

## Control results

| Control | Result | Evidence / action |
|---|---|---|
| Configuration drift | **ATTENTION (classified)** | OMEN `ComfyNetworkSense.dll` is `bc8113df227f8c0ea712a3a40080913d0227baf2069a238aba8ed8188dcaa8`; GCP remains on the previously proven `cde0d458f2c74bc9b3dba3f73ba5bdce5e4df602bf635c42110bd24b8630d72c` release. The role-specific config hashes differ intentionally: OMEN consumes while GCP produces/redirects. The local binary must receive a distinct release identity before being promoted.
| Cold-start artifact pinning | **PASS for recorded release / ATTENTION for next release** | The 0.5.27 primary evidence proves matching runtime/fallback DLLs and pinned Valheim image digest `e8b13da3c44f54a38511c8ac224f2959a437c0b2626cf916683ca7acc8dfb146`. The new deploy path now records assembly inputs, runtime/fallback hashes, and a release manifest; Gateway source/image provenance still needs a first manifest-backed deployment.
| Tunnel lifecycle | **PASS / recovery untested** | Gateway health is `{"status":"ok","service":"gateway"}` through `http://127.0.0.1:14000/health`; listener is loopback-only. `gateway-tunnel.ps1` now provides status, stop, start, and supervised watch. IAP still emits the known NumPy/stdin teardown warnings.
| Deployment verification | **PASS** | systemd, Gateway health, pinned Valheim digest, and guarded plugin readiness/hash checks exist. `deploy-network-sense.ps1 -ManifestPath ...` now emits a release manifest.
| Rollback | **PASS for plugin/Gateway procedure; live rehearsal pending** | Plugin backups are created under `/mnt/comfy-p7/backups/comfynetworksense/`; `rollback-network-sense.ps1` restores and restarts Valheim; `rollback-gateway.ps1` restores source backups, rebuilds Gateway, and checks loopback health. Execute both in a controlled recovery window.
| Right-sizing | **PASS (defer change)** | VM has 8 vCPU, 64,298 MB RAM, 49,522 MB available, 2 MB swap used, and 78 GB free (48% disk used). This is ample headroom for one client and current WAL load. Do not resize until multi-client CPU, memory, network, and WAL-growth samples exist; then test a smaller shape in a disposable window.

## Required follow-up, in order

1. Build the next uniquely versioned plugin release and run the guarded deploy with
   its manifest; do not reuse `0.5.27` for a different binary.
2. Execute the plugin and Gateway rollback scripts in a controlled recovery window,
   then require `/health`, persistence, pending=0, and native-only=0 before success.
3. Apply the private-topology Terraform change only after reviewing its plan; it
   removes stale public Gateway firewall and uptime-check definitions.
4. Capture a 15-minute single-client baseline and a multi-client load sample before
   any VM right-sizing decision. Preserve CPU p95, RSS, disk/WAL growth, tunnel
   reconnects, Gateway latency, pending depth, and receipt/ack counters.

## Cold-start acceptance gate

A cold start is reproducible only when all of the following match the selected
manifest: source revision, both container digests, plugin hash, canonical config
hash, environment manifest ID, and deployment timestamp. After restart, verify the
Gateway health endpoint, consumer active state, durable persistence, pending depth,
and a zero native-only counter during the single-client window.

## Evidence retained

Raw cutover and compaction artifacts remain under
`C:\work\comfy\fieldlab\runs\audits\p7-efficiency\`. Runtime and network-tenet
cross-references are in `docs/network/valheim-lumberjacks-p7-overview.md`,
`docs/network/interest-management.md`, and
`docs/network/evidence-index.md`.
