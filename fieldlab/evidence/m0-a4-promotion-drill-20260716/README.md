# M0/A4 Promotion Drill Evidence: m0-clean-20260716-r2

The M0/A4 checkpoint proves that the manifest-tied release `m0-clean-20260716-r2` cold-starts on the P7 GCP VM from prebuilt bundle artifacts with no VM-side source rebuild, rolls back artifact-only to the historical validated runtime, and restores the candidate. Each transition is verified fail-closed by exact image ID, gateway `/health` endpoint checks, and mod DLL SHA-256 verification at both runtime and fallback paths.

## 1. Verified Identities

| Role | Artifact | SHA-256 Identity |
| :--- | :--- | :--- |
| Candidate | Gateway Image | `sha256:141bd9e5a2ce8bd95f1bd93a9f123637cbc1cffcb0795594fae94e28d7fe86fb` |
| Candidate | Mod DLL | `94a3843ef8042adceaca6bc4d5c0c38c7c8dc5a1aa05b5f2a3019879840ba3a8` |
| Rollback | Gateway Image | `sha256:358f5e11e35b54367a83d4e52ea3d47c0346e62a82ed357c2ff403eafafcd0a2` |
| Rollback | Mod DLL | `b31697d2a0cbe47b86c32b33d19fb9445e21af0cfe51687cb5afe871a3d7d77b` |

## 2. Execution Record

The drill was executed on 2026-07-16 UTC inside the scheduled GCP mutation window with the Valheim server confirmed empty by the owner.

The snapshot archive (`valheim-config.tgz`, 51 GB) was captured 12:11–12:38Z with the `valheim-server` container stopped for consistency. During this phase, the driving workstation's IAP-tunneled `ssh` sessions could not reliably return output from long transactions; local `ssh` processes wedged after remote completion, though remote state was verified untouched each time. To enforce fail-closed visibility, the drill script's remote transport was hardened mid-window: transactions were shifted to run detached on the VM using exit/output marker files, polled by short-lived sessions, and all local `ssh`/`scp` calls were wrapped in timeout-bounded jobs with idempotent launches.

The drill was then resumed via `-ResumeSnapshotRoot` against the already-captured archive. The hash pass re-ran at 13:59Z (the `captured_utc` in `snapshot-manifest.json` reflects this hash time, not the archive time). The mutation phases then completed in sequence with all checks green:

* **Cold Start**: 14:02:43Z
* **Rollback**: 14:04:51Z
* **Restore**: 14:07:06Z

No phase mutated the VM before its specific precondition checks passed.

## 3. Post-Restore Live Validation

Immediately following the restore receipt, the owner joined the promoted server with a standard Valheim client:

* Notably fast world loading with no observed desync or client errors.
* Server logs confirmed the world (9,155,582 ZDOs) loaded cleanly.
* `ComfyNetworkSense` active, plugin logging normally.

## 4. Receipt Inventory

The evidence for this phase is the following five JSON receipts. SHA-256 hashes for these files are recorded in the Lumberjacks-side receipt (`docs/roadmap/m0-a4-promotion-drill-receipt.json`), which also binds them to the Comfy revision that carries this folder.

| File | Role | Meaning |
| :--- | :--- | :--- |
| `drill-plan.json` | Plan | Declares intended phase targets, artifacts, and GCP context. |
| `snapshot-manifest.json` | Baseline | Records remote hashes of the pre-mutation environment/config state. |
| `cold-start-receipt.json` | Execution | Verifies deployment of candidate artifacts via strict load/pin, no rebuild. |
| `rollback-receipt.json` | Execution | Verifies reversion to the exact historical fallback identities. |
| `restored-state-receipt.json` | Execution | Verifies final restoration to the candidate state, closing the drill. |

## 5. Relationship to M0

A4 was the final active checkpoint in the M0 sequence. With these receipts recorded, the A5 publication set (staged at Comfy revision `433f1cc`) becomes closable: this evidence satisfies the A4 drill requirement in the A5 receipt's `closes_when` conditions.
