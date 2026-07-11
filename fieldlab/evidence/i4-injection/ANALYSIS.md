# I4 Inbound Injection Gate

Window `i4-w6` passed on 2026-07-10/11 with ComfyNetworkSense `0.5.15`.

- Lumberjacks staged `synthetic-wood-1` for prefab `Wood`.
- The client completed 90 polls with zero poll errors.
- One synthetic ZDO was received, applied, and rendered.
- Readback owner was `5497853135698`, the configured Lumberjacks authority.
- No rejects, duplicates, or pending render rows remained at auto-stop.
- Client stability checks were clean.
- After injection was disarmed, the dedicated server restarted and the client rejoined.
- Save-integrity remained exact: portals 4472, spawned 85439, targets 20255, locations 18004, ZDO delta 0, and world files byte-identical.

The initial `i4-w4` and diagnostic `i4-w5` runs failed safely. `i4-w5` identified that a locally constructed `ZPackage` was passed to `RPC_ZDOData` at its write cursor. The fix was `packet.SetPos(0)` before invocation; `i4-w6` is the authoritative passing run.
