# Handoff — Real player on the Valheim network (server relocated to am4)

> **⚠️ SUPERSEDED (2026-07-09 evening).** Kept as the war-story record of how player-two got
> online. Two facts below are stale: (1) player two of record is now **wary.fool rendered
> natively on OMEN** (Derek's directive), not the i5; (2) the account table criss-crosses
> account names and personas — the settled mapping is account `waryfool`→persona Zephar410,
> account `floooooobcakes`→persona wary.fool. Current state: `../GROUND-TRUTH.md`. Current
> topology: `../MULTIPLAYER-NETWORK-SETUP.md`. Current plan: `../TEST-PROGRAM.md`.

**Date:** 2026-07-09
**Outcome:** ✅ A real GPU-rendered player (`Durracktu`, account `floooooobcakes`) is connected to the `ComfyEra16` world. The multi-day "player never connects" blocker is solved.

---

## TL;DR of what fixed it
The whole failure chain, and the winning path:

| Attempt | Why it failed |
|---|---|
| OMEN steam-headless container | no discrete GPU → llvmpipe software render ("hand-drawn"), unusable |
| am4 steam-headless container (GPU passthrough) | container Mesa **25.0.7** too old for Battlemage Arc B70 (PCI `0xe223`); host needs Mesa **26.x** → still llvmpipe |
| Vulkan renderer on GPU-less box | crashes on load → use **"Play Valheim using OpenGL"** |
| Fresh Steam account | no character → `+connect` silently no-ops → **create a character first** |
| **Server on OMEN (Docker Desktop)** | **Docker Desktop/Windows does NOT publish UDP to host/external peers** — clients could never reach `2456/udp`. Firewall was a red herring. |
| **i5 laptop, native Windows, Iris Xe** | real GPU + a screen + native drivers → **WORKS**, reference client |

**Keystone fix:** moved the Valheim server off OMEN's Docker Desktop onto **am4 (native Linux Docker)**, which publishes UDP correctly. See memory: `docker-desktop-windows-no-udp-publish`, `valheim-lab-working-topology`, `battlemage-needs-mesa-26`.

---

## Current live state

**am4** (`100.116.82.60`, SSH `derek@am4` works, key-based):
- Valheim **server RUNNING**: `cd ~/comfy-valheim-lab && docker compose -f server-compose.yml ...`
  - Container `comfy-valheim-server-am4-valheim-server-1`, image `ghcr.io/community-valheim-tools/valheim-server`
  - World `ComfyEra16` (~1.3 GB / 9.15M ZDOs), pass `comfytest`, `BEPINEX=true`, server-side `ComfyNetworkSense.dll` present
  - Listening `0.0.0.0:2456-2457/udp` (verified real `ss -ulnp` listeners)
  - State at `~/comfy-valheim-lab/server-state/config` (world in `worlds_local/`, mod in `bepinex/plugins/`)
- **Dead cruft to remove:** `comfy-valheim-am4` project (the llvmpipe GPU client container, port 8095) — useless, `docker compose down` it.

**i5 laptop** (`100.125.141.110`, no SSH — Windows): native Valheim, account `floooooobcakes` (persona wary.fool), character `Durracktu`, connected to `100.116.82.60:2456`.

**OMEN** (`100.124.12.37`, this session's host, Docker Desktop):
- Original `comfy-valheim-lab-valheim-server-1` is **STOPPED** (do not restart — UDP won't publish).
- `client-01` / `client-02` containers still **running but orphaned** (point at the dead OMEN server) — tear down.
- `comfy-gateway` still running.
- Added Windows Firewall inbound rule "Comfy Valheim Lab (UDP 2456-2457)" — now irrelevant (server moved), harmless to leave or remove.

**Steam accounts (one Valheim license each, single-session):**
- `waryfool` / persona **Zephar410** → OMEN local + client-01
- `floooooobcakes` / persona **wary.fool** → i5 (the active player)

**Tailnet:** omen `100.124.12.37`, am4 `100.116.82.60`, i5 `100.125.141.110` (i5 sometimes shows offline — wake it).

---

## Open loose ends (next session)
1. **Cleanup:** `docker compose down` the orphaned OMEN `client-01`/`client-02` + the am4 `comfy-valheim-am4` llvmpipe container. Optionally remove the OMEN firewall rule.
2. **Second player (if 2 peers needed for the netcode probe):** run Valheim **native on OMEN's RTX 5070** with the `waryfool` account → connect to `100.116.82.60:2456`. (Two fast players = two GPUs on two boxes = two accounts.)
3. **Telemetry re-wire:** `comfy-gateway` (OMEN) reads BepInEx log/config by path from `autonomous/state/client01/...`; the server-side ComfyNetworkSense telemetry now lives on **am4**. Repoint the gateway/probe if you want it seeing the new topology. Server BepInEx log is inside the am4 server container / `server-state`.

## Gotchas to remember (also in memory)
- Docker Desktop Windows: **no UDP publish** — run UDP servers on am4 native Docker.
- Brand-new GPU in a container: check container Mesa ≥ host Mesa or it falls back to llvmpipe.
- Valheim: fresh account = make a character before joining; GPU-less box = launch with **OpenGL**, not Vulkan.
