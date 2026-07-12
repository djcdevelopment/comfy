# OMEN client authenticity-smoke runbook

**What this is:** the repeatable version of the loopback-integrity smoke for the Valheim x
Lumberjacks / ComfyNetworkSense netcode-replacement path. It turns the old operator-in-the-loop
flow (arm the server, hand-launch the client, drive the gates) into **one command with a single
manual touch** — typing the Valheim join password.

Related: [MULTIPLAYER-NETWORK-SETUP.md](MULTIPLAYER-NETWORK-SETUP.md) ·
[VALHEIM-NETCODE-REPLACEMENT-WORKLOG.md](VALHEIM-NETCODE-REPLACEMENT-WORKLOG.md) ·
`scripts/run-loopback-window.ps1` · `scripts/omen-client-smoke.ps1` · `scripts/run-omen-smoke.ps1`

---

## The loop (what runs, in order)

| Step | Who/where | Automated? |
|---|---|---|
| 1. Arm server+mod window | am4/P7 server + Lumberjacks gateway | yes — `run-loopback-window.ps1 -Stage arm` |
| 2. Fresh-launch OMEN client + join | OMEN (real GPU) | **launch automated; join password MANUAL** — `omen-client-smoke.ps1` |
| 3. Drive the route + probe window | mod on OMEN | yes — mod auto-rehearsal walks `p7-compose.tsv` hands-free |
| 4. Read the four gates + save + stability | MCP mod-channel | yes — `run-loopback-window.ps1 -Stage gate` |
| 5. Disarm to observe-only baseline | am4/P7 server | yes — `run-loopback-window.ps1 -Stage disarm` |

**The one manual step** is step 2's Valheim join password. Character-select is automated
(`COMFY_AUTOJOIN=1` → the mod picks the profile and clicks Start) and the server address is
automated (the `+connect <endpoint>` launch arg). Only the password dialog is left for a human — by
design (we never touch Steam creds / 2FA, and the manual join stays manual).

---

## Run it

On **OMEN** (real GPU desktop, Steam logged into `floooooobcakes`), in one PowerShell session:

```powershell
cd C:\work\comfy\fieldlab\scripts

# 1. Point the harness at the live server (P7 GCP VM, or omit for the am4 tailnet default).
.\set-gcp-p7-target.ps1 -PublicIp <P7-public-ip>

# 2. One command. It arms, launches the client, waits for you to type the join password,
#    runs the probe window, reads the four gates, and disarms.
.\run-omen-smoke.ps1 -WindowId i7-live-w1
```

When the Valheim password dialog appears, **type the join password and click Connect.** That is the
only manual action. The script auto-confirms the connect by tailing the client log, waits out the
~150 s armed probe/rehearsal window, then prints the four gate results.

### Just the client handoff (when the server is already armed)

```powershell
.\omen-client-smoke.ps1 -WindowId i7-live-w1        # endpoint from $env:FIELDLAB_VALHEIM_ENDPOINT
.\omen-client-smoke.ps1 -SkipLaunch                 # preflight + checks only, no launch (safe dry run)
```

### The four gates (driven via the MCP mod-channel)

`-Stage gate` reads them via the comfy-gateway MCP tools: `valheim_handshake_gate`,
`valheim_ownership_pin_status`, `valheim_zdo_redirect_gate`, `valheim_zdo_injection_gate` (plus
`valheim_save_integrity` and the client-stability scan). `valheim_loopback_preflight` is the
read-only full-stack check used by `-Stage check`.

---

## What `omen-client-smoke.ps1` guarantees

- **Real GPU desktop only.** Refuses session 0 / non-interactive contexts. Headless / containerized
  Valheim is a **dead path** (see the failure table in MULTIPLAYER-NETWORK-SETUP.md).
- **Right identity (non-fatal warn).** Reads `loginusers.vdf`; warns loudly if the signed-in account
  isn't `floooooobcakes` / wary.fool (`76561198088711642`), and extra-loudly if it's the server-side
  `waryfool` / Zephar410 identity — never cross them (single session per license).
- **Fresh process.** Force-quits any running `valheim.exe` first: the mod's auto-rehearsal + netcode
  probe only re-arm on a full process start, never a menu rejoin.
- **Automated launch, manual password.** Sets `COMFY_AUTOJOIN=1`, launches `valheim.exe +connect
  <endpoint>`, then waits for the operator's password and confirms the connect from the client log
  (`%USERPROFILE%\AppData\LocalLow\IronGate\Valheim\Player.log`). Warns on
  `INVALID_MESSAGE` / socket error / desync / disconnect signatures.

---

## Two distinct secrets (do not conflate)

1. **Valheim JOIN password** — typed into the in-game dialog by the operator. Manual. Unchanged by
   any of this tooling.
2. **Lumberjacks NETWORK password** — what the **mod** would present on its connection to the
   Lumberjacks gateway. It is *not* a Valheim password and never appears in the Valheim dialog. The
   smoke supplies it as an **optional env passthrough**, resolved (in precedence order) from:
   - `-LumberjacksNetworkPassword` param, then
   - `$env:COMFY_LUMBERJACKS_NETWORK_PASSWORD`, then
   - a gitignored local file `scripts/omen-client-smoke.secrets.ps1` that sets
     `$LumberjacksNetworkPassword`.

   It is exported to the client env before launch and **never hard-coded** (the secrets file is
   gitignored).

> **Current status of secret #2 (verified 2026-07-11):** the open GCP P7 "SUT" the smoke targets
> today runs **without** this password, and the current build does not yet consume it — the mod
> (`ComfyNetworkSense` `[Lumberjacks]` config) exposes `lumberjacksGatewayUrl` /
> `COMFY_LUMBERJACKS_GATEWAY_URL` but **no password key**, and the Lumberjacks gateway has **no auth**
> on any path (WebSocket join + HTTP endpoints are open; its own tech-debt audit confirms this). So
> the passthrough is a documented **no-op today**, wired so that when the gateway auth layer + a mod
> `[Lumberjacks]` password key land, the same env carries the secret with zero script change. The
> "real comfy path requires it" — that enforcement is the pending piece, not this smoke.

---

## Constraints honored

- Reuses `run-loopback-window.ps1` and the mod unchanged — no fork.
- Never touches Steam credentials / 2FA; the join password stays manual.
- Neither password is hard-coded in a committed script.
- The live end-to-end still needs OMEN's real GPU session + the P7/am4 server armed; everything else
  in this repo is verifiable offline (scripts parse, paths resolve, preflight `-SkipLaunch` runs).
