# Comfy guest package — m1-clean-20260717-r1

This package installs the ComfyNetworkSense clean-build artifact for Valheim.

## Before installing

- Licensed Steam copy of Valheim, build **0.221.12**.
- BepInExPack Valheim **5.4.2202** installed in the Valheim directory.
- A one-use bootstrap URL supplied by the host. Do not paste its response into public logs.

## Install

Run PowerShell 5.1 from this package directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-ComfyGuest.ps1 -BootstrapUrl '<one-use bootstrap URL>'
```

The installer discovers the Steam library, checks BepInEx, calls the bootstrap endpoint once,
backs up existing files, merges only the `[Lumberjacks]` section, and installs the DLL atomically.
It writes `BepInEx\comfy-guest-install.json`; keep that receipt for uninstall.

## Join

Use the join address **8.231.129.249:2456** and the password sent separately by the host.
The gateway endpoint is **http://8.231.129.249:42317**. Its anonymous health path is
`/health` and enrollment path is `/api/v0/valheim/enrollment/me`.

## Troubleshooting

Run:

```powershell
powershell -NoProfile -File .\scripts\Invoke-GuestPreflight.ps1 -ValheimPath 'C:\Path\To\Valheim'
```

Every failed check includes a remedy. To remove this package, run
`Uninstall-ComfyGuest.ps1`; uninstall is receipt-driven and restores the exact pre-install files.

## Artifact identity and limits

- Release identity comes from `manifest.json`, not from the DLL.
- Mod version: **0.5.31.0**.
- DLL SHA-256: `94a3843ef8042adceaca6bc4d5c0c38c7c8dc5a1aa05b5f2a3019879840ba3a8`.
- The DLL is a **clean-build artifact, IL-equal to the runtime DLL**; it is not claimed to be byte-identical to the historical runtime artifact.
- The sealed manifest describes a candidate cut. This is a candidate, not a promoted deployment. The historical runtime DLL remains the rollback artifact. The clean mod hash differs from the historical DLL only in PE identity/debug metadata observed during comparison; IL is equal. No GCP mutation, world snapshot, or volunteer session occurred.
- TODO(stage-4-deploy): document GET /join/reissue after deployment.
