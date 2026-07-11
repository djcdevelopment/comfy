# P6/I5 — LIVE handshake gate (the first Lumberjacks-fronted admission)

**Window:** `i5-live-w1` · **date:** 2026-07-11 · **mod:** ComfyNetworkSense 0.5.18 (server-side
interceptor) · **client:** OMEN, SteamID `76561198088711642` (account `floooooobcakes` / persona
`wary.fool`), Valheim character **`Durracktu`** · **server:** am4 ComfyEra16 (9.155M ZDOs).

This is the **live** P6 step 6-7/8 gate — the runtime corroboration the headless loopback
(28/28) could not give. A real Valheim client's admission was decided by the Lumberjacks
responder, over the real Steam socket, completed by vanilla `AddPeer`.

## What the interceptor is

A Harmony **prefix on `ZNet.RPC_PeerInfo`** (server-side / am4 only, rollback flag
`handshakeResponderEnabled`). When armed it reads a `SetPos(0)` **clone** of the client's
PeerInfo ZPackage (the banked i4 read-cursor lesson), decodes the logical fields, and does a
synchronous Lumberjacks `/valheim/handshake/peerinfo` decision over a raw `TcpClient` (server
Mono HTTP trap, ADR 0003). On **reject** it `Invoke("Error", code)` and skips vanilla; on
**accept** it returns to vanilla so the real `ZNet.AddPeer` transition runs. **Fail-open**: any
decode/HTTP fault falls through to vanilla, so the interceptor can never lock out a join on its
own fault. Save-safe: it runs pre-`AddPeer` and writes no persisted ZDO state.

## The gates (am4 server log is the authoritative persistent record — `am4-server-log-decisions.txt`)

| Gate | Evidence | Verdict |
| --- | --- | --- |
| Interceptor decodes real bytes | `ACCEPT ... uid=1167002880 net_version=36 player=Durracktu` | ✅ correct |
| **Accept ≥30s in-world (step 6-7)** | 01:22:22 `ACCEPT` → `New peer connected` → 01:22:36 `Got character ZDOID from Durracktu` → held to 01:24:07 (**~105s**) through a death/respawn (`1167002880:1` → `0:0` → `:10`), 0 disconnects | ✅ |
| **Failure code (step 8)** | 01:28:44 `REJECT ... code=8 check=blacklist` + client "Banned" dialog (screenshot) | ✅ |
| **Fronting** (admission is Lumberjacks-decided) | same client + same am4 (no such ban server-side); only the Lumberjacks window config changed and the outcome flipped accept→reject | ✅ |
| **Save-integrity (HARD)** | pre/post `valheim_save_integrity` = `pass`, ZDOS 9,155,594 delta **0**, all structural counts exact across the armed session AND the disarm restart | ✅ |
| Rollback | `handshakeResponderEnabled=false` + restart → 0 ARMED lines, pure vanilla pass-through | ✅ |

## Honest scope / caveats (kept off the "confirmed" pile until noted)

- **Password (F) and steam-ticket (C) gates are delegated to vanilla**, not Lumberjacks. They are
  real MD5+salt / Steamworks crypto that only the in-game code can evaluate against the server's
  stored hash and live salt (the contract's "mod owns crypto" boundary). The interceptor sends an
  empty `password_hash` and reports `ticket_valid=true`; vanilla re-checks the real password on the
  accept path. So "Lumberjacks-decided" is precise for **version / blacklist / full / duplicate**;
  password and ticket remain vanilla's. am4's real `SERVER_PASS` is still enforced (by vanilla) — the
  client entered it to be admitted.
- **First-try misconfig, recorded honestly:** the first armed build (0.5.17) staged an accept-all
  Lumberjacks context (`password=""`) while am4 requires a password, so the client's real hash
  mismatched and Lumberjacks rejected with **code 6 (password)** three times (01:12) — surfaced to
  Derek as "wrong password." That was the interceptor *working* (Lumberjacks overriding a
  vanilla-accept), just misconfigured; the fix (0.5.18, delegate password to vanilla) produced the
  clean accept. Two of the six gate codes (6, 8) were thus surfaced live; the full ordered battery
  remains proven **headlessly** (28/28 xUnit), not all six live.
- **Lumberjacks window trace not archived:** the `/handshake/status/i5-live-w1` trace (observed live
  as `accepted=1, steady_state_reached=1`) was in-memory and lost when the Lumberjacks gateway
  process was torn down after the test. The persistent authoritative record is the am4 server log
  (the interceptor's own ACCEPT/REJECT lines) + the vanilla `New peer connected` / `Got character
  ZDOID` lines + Derek's client screenshots.
- **Accept = layered gate, not replacement:** on accept the interceptor lets vanilla complete, so
  both Lumberjacks and vanilla accepted. Lumberjacks is an admission gate layered *before* vanilla
  (it can reject what vanilla would accept — the ban proves it), not a full replacement of vanilla's
  gate.
- **One authoritative accept window + one ban reject** (plus the three incidental code-6 rejects).
  Repeatable on demand: rearm `handshakeResponderEnabled=true`, stage a Lumberjacks window, reconnect.

## Files

- `am4-server-log-decisions.txt` — the ARMED / ACCEPT / REJECT / peer-connect / character-ZDOID lines.
- `ANALYSIS.md` — this file.
