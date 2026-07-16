# Validated P7 Baseline Publication

## What this is

This folder publishes the validated, hash-recorded P7 authoritative priority ZDO baseline required by milestone M0/A5 of the Lumberjacks Volunteer Roadmap. It represents the "gold" FieldLab run (`20260716-011112-valheim-lumberjacks-authoritative-priority-cutover`).

The exact claim: The validated, hash-recorded P7 run observed 83,220 eligible server-to-client ZDO revisions in one strict single-client window. All 83,220 were durably received by Lumberjacks and closed as applied or safely superseded with durable acknowledgement; zero eligible revisions used native ZDO delivery.

This 100% denominator covers that declared ZDO delivery window only, not every Valheim packet. Valheim still decides which world-object revisions a player should receive. This proof does not claim replacement of every Valheim RPC, simulation, ownership decision, Steam login, or base peer-transport function.

## Files in this folder

| Filename | Role | SHA-256 |
|---|---|---|
| `report.md` | sanitized publication copy of the gold run report | `328196cf7c1bdf38fd2bdc9ece735a1dd0f551c261150fc65c22f1f11e7b0659` |
| `acceptance-snapshot.json` | byte-identical copy of the run's acceptance snapshot | `51cf67d3533b97c5eb26f7cf767c93aa061218ef5007dca1773e595e87070e26` |
| `PUBLICATION.md` | this document | (hash recorded in the Lumberjacks A5 receipt) |

## Provenance and sanitization

The raw immutable run packet lives at `fieldlab/runs/20260716-011112-valheim-lumberjacks-authoritative-priority-cutover/` (the raw `runs/` tree is untracked; only the catalog files and this publication set are tracked). The raw `report.md` SHA-256 is `cc9fa1ff3930d95108ac4df19bf699f33b176ad5e6e0fa1dcfbb43b4b7e3cbd9`.

The sole redaction in the published `report.md` is the replacement of the deployment public IPv4 address with `<gcp-public-ip>` (5 occurrences). No other content was changed, and `acceptance-snapshot.json` is completely unmodified. A strict secret scan verifying the absence of SteamID64 patterns, credential-shaped assignments, IPs, and emails returned clean on this published set.

## Binding to the frozen release

This evidence chains to the M0 release identity via the release manifest `m0-clean-20260716-r2` (manifest SHA-256 `59835b0b0b7658b22cd2f07c37aa4c7ba4923e424953b228d886e1f7242a6520`). The exact release artifacts are validated by the A3 bundle receipt at Lumberjacks `docs/roadmap/m0-a3-release-bundle-receipt.json`.

The FieldLab catalog (`fieldlab/runs/index.json`, SHA-256 `3c22d6e049cab1ea1a1b3e75bf9050e1b7672dbe970ad19d3a367ba0e711dfae`) records its single `gold` entry as this run. The historical runtime identities that produced this evidence are:
* **Gateway image:** `sha256:358f5e11e35b54367a83d4e52ea3d47c0346e62a82ed357c2ff403eafafcd0a2`
* **Mod (ComfyNetworkSense 0.5.31):** SHA-256 `b31697d2a0cbe47b86c32b33d19fb9445e21af0cfe51687cb5afe871a3d7d77b`

## Key results

| Metric | Result |
|---|---|
| Eligible revisions in declared window | 83,220 |
| Durable receipts | 83,220 |
| Exact applications | 72,946 |
| Safe supersessions | 10,274 |
| Acknowledgements | 83,220 |
| Pending | 0 |
| Eligible native-only sends | 0 |
| Priority tagged | 83,220 (100%) |
| Observed reject / duplicate / retry | 0 / 0 / 0 |
| Poll / ACK / telemetry failures | 0 / 0 / 0 |
| Peer-ready → first apply | 6.721 s |
| Peer-ready → complete | 102.114 s |

## What this does not prove

This evidence explicitly operates within bounded technical boundaries:
* **Single client only:** The current queue and acknowledgement state is shared. Automated recipient isolation preventing clients from consuming another peer's records is M4a work.
* **Candidate relevance remains native:** Valheim natively creates the peer-specific candidate list. Replacing native interest management, ownership, and non-ZDO RPCs is later authority plane work (M7).
* **Not a volunteer-journey proof:** This does not prove the immutable generic package, guest onboarding, or automated rollback usability designed for real external players (M5 work).
* **Per-run sealed receipts are pending:** Current dashboard accounting is resettable and aggregate. Generating bounded, per-run sealed conservation receipts is M3 work.

## Publication status

This folder is staged for milestone M0/A5. It becomes formal closing evidence only when referenced at an immutable repository revision after the A4 (no-build cold-start and rollback) promotion drill passes. Until then, the roadmap's publication status remains `local_pending_m0`.
