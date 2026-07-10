# I6 — Steam-only transport (no crossplay/PlayFab game socket)

**Verdict: SATISFIED** for the record topology (OMEN client via ZSteamSocket ↔ am4 dedicated server,
Steam-only). Captured 2026-07-10 as pre-P3 work (TEST-PROGRAM P3 steps 1-2). Four sources, three
non-doc — clears the [[post-i0-distrust-rule]] bar.

## Server-side (am4) — P3 step 1

- **Docker env** (`docker inspect comfy-valheim-server-am4-valheim-server-1`):
  `CROSSPLAY=false`, `SERVER_PUBLIC=false`. No `-crossplay` launch arg.
- **Boot log** (2026-07-10 00:31:23, after the P2 re-arm restart):
  ```
  Steam game server initialized
  Sending PlayFab login request (attempt 1)
  Opened Steam server
  Game server connected
  ```
  The game host socket is **Steam** (`Opened Steam server`). There is **no `Opened PlayFab server`**
  line — so no `ZPlayFabSocket` host was opened, i.e. no crossplay game transport.

### RED HERRING — "Sending PlayFab login request" is NOT crossplay
A Steam-only dedicated server still logs into PlayFab: PlayFab is Valheim's **server-list /
matchmaking backend** (the in-game server browser), separate from the game-traffic transport. The
crossplay game socket is a *different* object. Decompiled proof (`ZNet`):
- `ZSteamSocket` host is **always** created (`new ZSteamSocket()`, ZNet:339).
- The PlayFab host socket is created **only** `if (m_onlineBackend == OnlineBackendType.PlayFab)`:
  `RegisterServer(...) -> new ZPlayFabSocket() -> StartHost() -> ZLog.Log("Opened PlayFab server")`
  (ZNet:344-350). That branch did not run (no "Opened PlayFab server" in the log).

So: PlayFab **login** (registry auth) happens regardless; PlayFab **socket** (crossplay transport)
only with crossplay=on. Only the login is present -> Steam-only transport.

## Client-side (OMEN) — P3 step 2

- The client joined via **IP:port `100.116.82.60:2456`** (direct address join), confirmed by the am4
  peer-connect log (`Got connection` / `Got handshake`, session 2026-07-10 06:32:37).
- Decompiled `ZNet` connect paths:
  - Direct address / Steam-ID join -> `Connect(new ZSteamSocket(host))` (ZNet:650, 655). **ZSteamSocket.**
  - PlayFab join -> requires `m_serverPlayFabPlayerId` (a join-code, ZNet:385-386) ->
    `new ZPlayFabSocket(remotePlayerId, ...)` (ZNet:620-622). Not used (no join code; IP:port join).
- Therefore the client's peer socket is `ZSteamSocket`; the PlayFab connect path was never taken.

## Optional airtightening (not required; fold into the P3 mod slice)

A runtime assertion — postfix that reads `peer.m_socket is ZSteamSocket` (the type is inspectable,
ZNet:880) and records it as a telemetry field — would make step 2 a live observation rather than a
logic proof. Cheapest to add in the same mod build as the P3 ownership-transition observer (see
`NETCODE-OWNERSHIP-MAP.md`), per [[kvm-elimination-guardrail]]. The evidence chain above already
satisfies the gate without it.

Related: `GROUND-TRUTH.md`, `TEST-PROGRAM.md` P3, [[valheim-decompile-toolchain]].
