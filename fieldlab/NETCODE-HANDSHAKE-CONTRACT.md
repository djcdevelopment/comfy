# Valheim Connection-Handshake Contract — rung I5 (P6) deliverable

The field-by-field + ordered-gate contract the Lumberjacks handshake responder must
satisfy for a Valheim client to complete a connection against a Lumberjacks-fronted
peer. This is P6 step 1. It extends **Funnel 5** of [NETCODE-MAP.md](NETCODE-MAP.md)
(the I0 map) into an executable spec that the responder (`ValheimHandshakeService`)
and the loopback shim both consume.

## Provenance — two static sources agree (post-I0 distrust rule)

| Source | What | When / tool |
| --- | --- | --- |
| **S1 — I0 map** | Funnel 5 of NETCODE-MAP.md (build mapped 2026-07-01) | ilspycmd 8.2, rung I0 |
| **S2 — fresh re-decompile** | independent re-extraction of `ZNet` / `Version` / `ZSteamMatchmaking` | ilspycmd 9.1.0.7988, 2026-07-10 |

Both derive from `assembly_valheim.dll`, **Valheim 0.221.12** (`Version.CurrentVersion =
GameVersion(0,221,12)`; `Version.m_networkVersion = 36u`, `Version.decompiled.cs:5`).
S2 re-read the IL independently rather than trusting S1's prose, and agrees on the
sequence, the PeerInfo layout, and every error code. These are two *static* reads of the
same binary (a different decompiler version each) — they catch transcription error but
are not a runtime observation. The **runtime** corroboration is the loopback shim (this
rung, no game) and Derek's in-world connect (P6 step 6–7 gate). Line cites below are S2's
`ZNet.decompiled.cs` unless noted.

## Architecture boundary — mod does bytes, gateway does logic

Consistent with I3/I4 (the mod POSTs decoded JSON envelopes; Lumberjacks never parses raw
`ZPackage`): the **responder is a logical decision service**, not a byte-level ZPackage
parser. The am4-side mod hook (P6 step 5) owns the `ZPackage` encode/decode using Valheim's
own type — the same round-trip already proven in I3/I4 — and asks Lumberjacks only for the
two *decisions*:

1. **ServerHandshake →** what `ClientHandshake(needPassword, salt)` to answer.
2. **PeerInfo →** does this decoded PeerInfo pass the ordered gate; if so, what
   server-PeerInfo field values to reply with.

The byte layout below is therefore the **spec for the mod hook**; the responder validates
and emits the *logical fields*. Two gate checks are inherently the mod's to compute and are
passed to the responder as booleans (documented per-check): the Steam **session-ticket
verify** (real Steamworks crypto, only the in-game mod can call `VerifySessionTicket`) and
the client's **version parse**.

## The exchange (ordered)

1. **Client → server:** on `OnNewConnection` the client registers `Kicked`/`Error`/
   `ClientHandshake`, then `Invoke("ServerHandshake")` — the client initiates
   (`ZNet:698-701`; server side just registers `ServerHandshake` and waits, `:693-696`).
2. **Server `RPC_ServerHandshake`** (`:727-737`): `ClearPlayerData`, compute
   `needPassword = !string.IsNullOrEmpty(m_serverPassword)`, then
   `Invoke("ClientHandshake", needPassword, ServerPasswordSalt())`.
   *Responder `begin` returns exactly these two values.*
3. **Client `RPC_ClientHandshake(needPassword, salt)`** (`:749-770`): if `needPassword`,
   prompt/aut-submit password → `SendPeerInfo(rpc, pwd)`; else `SendPeerInfo(rpc)`.
4. **`SendPeerInfo`** (`:783-816`) builds the PeerInfo `ZPackage` (layout below) and
   `Invoke("PeerInfo", pkg)`.
5. **Server `RPC_PeerInfo`** (`:818-977`): read fields, run the ordered gate, and on
   success reply with the server's own `SendPeerInfo`, `VersionMatch()`, `SendPlayerList`,
   `SendAdminList`, then **`m_zdoMan.AddPeer(peer)` → `m_routedRpc.AddPeer(peer)`**
   (`:975-976`, fixed order) — the transition into steady-state replication.
   *Responder `peerinfo` returns accept+serverPeerInfo (with `entersSteadyState=true`) or
   reject+code.*

## PeerInfo ZPackage layout (`SendPeerInfo`, `:783-816`) — spec for the mod hook

Common prefix (always, in order):

| # | Field | Type | Note |
| --- | --- | --- | --- |
| 1 | `GetUID()` | long | = `ZDOMan.GetSessionID()` (`:1787`) |
| 2 | `Version.CurrentVersion.ToString()` | string | game version string |
| 3 | network version | uint | literal `36u` (`:788`) |
| 4 | `m_referencePosition` | Vector3 | 3 floats |
| 5 | player name | string | `GetPlayerProfile().GetName()` |

Then `if (IsServer())` — **server-only** fields 6–11: `worldName` (string), `seed` (int),
`seedName` (string), `worldUid` (long), `worldGenVersion` (int), `netTime` (double).

`else` — **client-only** fields: `passwordHash` (string), `steamSessionTicket` (byte[]).
- `passwordHash = HashPassword(password, salt)` = MD5 of ASCII(`password+salt`), raw hash
  bytes reinterpreted as an ASCII string (**not** hex), empty string when no password
  (`HashPassword` `:1897`; `ServerPasswordSalt` = 16 RNG bytes cached for process life,
  `:2678`).
- If `RequestSessionTicket` returns null the client sets `ErrorConnectFailed` and never
  sends PeerInfo (`:809-812`).
- Compatibility shim: the reader only `ReadUInt()`s field 3 when the parsed client
  `GameVersion >= 0.214.301` (`FirstVersionWithNetworkVersion`); older clients default
  `num=0` and fail the `!=36` gate anyway (`:827-831`).

## The gate — ordered rejection checks (`RPC_PeerInfo`, server branch)

Evaluated **in this exact order**; the first failing check `Invoke("Error", code)` and
returns. Codes are `ConnectionStatus` members (enum `ZNet:23-38`).

| Order | Check | Condition | Code | `ConnectionStatus` | Owner of the input |
| --- | --- | --- | --- | --- | --- |
| A | version | `num != 36` (`:835`) | **3** | ErrorVersion | responder (int compare) |
| B | blacklist / whitelist | `!IsAllowed(host, name)` (`:871`) | **8** | ErrorBanned | responder (list check) |
| C | steam ticket | `!VerifySessionTicket(ticket, peerID)` (`:878-888`, Steamworks only) | **8** | ErrorBanned | **mod** (passes `ticketValid` bool) |
| D | playfab/crossplay | PlayFab backend only | 10 / 5 | ErrorPlatformExcluded / ErrorConnectFailed | **skipped** under Steam-only (I6) |
| E | server full | `GetNrOfPlayers() >= 10` (`:912`) | **9** | ErrorFull | responder (literal max **10**) |
| F | password | `m_serverPassword != passwordHash` (`:918`) | **6** | ErrorPassword | responder (string compare) |
| G | duplicate | `IsConnected(uid)` (`:924`) | **7** | ErrorAlreadyConnected | responder (session set) |

On all-pass: register steady-state RPCs, server replies PeerInfo/VersionMatch/PlayerList/
AdminList, then `AddPeer(zdoMan)` + `AddPeer(routedRpc)` → **entersSteadyState**.

Notes that shape the failure battery:
- **B and C share code 8** — blacklist and bad-ticket are indistinguishable by code alone;
  the responder reports the `failedCheck` label to disambiguate for tooling.
- `IsAllowed` (`:2512`): banned if `host` or `name` in `m_bannedList`, **or** if
  `m_permittedList` is non-empty and `host` not in it (whitelist mode).
- Order is load-bearing: a PeerInfo that fails multiple checks must surface the
  **earliest** code (e.g. wrong-version + wrong-password → **3**, not 6). The loopback
  battery asserts this ordering explicitly.
- D (PlayFab) is inert under `m_onlineBackend == Steamworks` (the analyzed Steam build);
  I6 already pins Steam-only, so the responder omits D by default.

## Machine contract (consumed by responder + shim)

```json
{
  "build": "0.221.12",
  "network_version": 36,
  "max_players": 10,
  "connection_status": {
    "None": 0, "Connecting": 1, "Connected": 2, "ErrorVersion": 3,
    "ErrorDisconnected": 4, "ErrorConnectFailed": 5, "ErrorPassword": 6,
    "ErrorAlreadyConnected": 7, "ErrorBanned": 8, "ErrorFull": 9,
    "ErrorPlatformExcluded": 10, "ErrorCrossplayPrivilege": 11, "ErrorKicked": 12
  },
  "gate_order": [
    {"check": "version",   "code": 3, "name": "ErrorVersion"},
    {"check": "blacklist", "code": 8, "name": "ErrorBanned"},
    {"check": "ticket",    "code": 8, "name": "ErrorBanned"},
    {"check": "full",      "code": 9, "name": "ErrorFull"},
    {"check": "password",  "code": 6, "name": "ErrorPassword"},
    {"check": "duplicate", "code": 7, "name": "ErrorAlreadyConnected"}
  ],
  "peerinfo_common": ["uid:long", "version:string", "netVersion:uint", "refPos:vec3", "playerName:string"],
  "peerinfo_server": ["worldName:string", "seed:int", "seedName:string", "worldUid:long", "worldGenVersion:int", "netTime:double"],
  "peerinfo_client": ["passwordHash:string", "steamSessionTicket:bytes"]
}
```

Any change to this JSON is a protocol change and must be re-grounded against the decompile
(both sources), never a doc edit alone.

## Scope & honesty (what the loopback proves vs. what it does not)

- The responder and loopback exercise the handshake **decision logic only** — a *logical,
  headless* proof. "steady-state reached" in the responder / MCP gate means the ordered gate
  accepted and **would** drive Valheim's `AddPeer` transition; it is **not** an observation of
  a real `ZDOMan.AddPeer` or an in-world peer. The MCP gate reports
  `scope: logical_headless_no_live_addpeer` to keep this unmistakable.
- The **live** proof is the P6 step 6–7 gate: Derek connects in-game and stays in-world ≥30s
  against the Lumberjacks-fronted peer, with actual peer registration and stable replication.
- **Version-string path:** the mod owns the `SendPeerInfo:827-831` conditional read — it reads
  the network-version `uint` only when the client's parsed `GameVersion >= 0.214.301`
  (`FirstVersionWithNetworkVersion`); a pre-0.214.301 client yields `net_version = 0`, which the
  gate then rejects at check A. The responder receives the already-shimmed `net_version` and a
  non-empty version string (a missing string is a malformed PeerInfo).
- **Gate coverage is verified by distinct check label, not error code:** blacklist and
  bad-ticket both return code 8, so the MCP gate requires all six *checks*
  (`version, blacklist, ticket, full, password, duplicate`) in the exchange trace — a
  codes-only check would merge the two code-8 cases.
