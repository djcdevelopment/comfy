# I3 outbound REDIRECT — gate evidence (window i3-w4)

**Verdict: `receipts_match_no_loss` — AUTHORITATIVE PASS.** P4/I3, mod 0.5.12, 2026-07-10 ~12:02 PDT (19:02 UTC), server-side on am4, rollback-gated, world save-safe.

## The gate (three independent legs agree exactly)

| leg | source | value |
|---|---|---|
| suppressed (mod count-of-record) | am4 `redirect-send.jsonl` | **1303** (`ack_failures=0`, `dropped=0`, `post_failed_batches=0`, `posted_ok=1303`) |
| delivered (receiver) | Lumberjacks `/valheim/zdo-redirect/status/i3-w4` | **1303** receipts, `distinct_seq=1303`, `min_seq=1 … max_seq=1303` (contiguous), `missing_seq=0`, `duplicates=0` |
| authoritative stop | mod lifecycle | `stop_event=redirect_auto_stop`, `mod_unacked_rows=0` |

1303 ZDOs removed from `ZDOMan.CreateSyncList`'s `toSync` before native serialization, each ack-replicated so vanilla would not re-offer it, and every one delivered to the Lumberjacks gateway with a contiguous seq and zero loss/dups.

**Species (per-prefab receipts, hash→name verified via `GetStableHashCode`):** FirTree_small (888684615) ×559 + FirTree (1185163063) ×406 + Pinetree_01 (797319082) ×338 = 1303. The three insurance prefabs on the allowlist (FirTree_small_dead, Birch1, Beech1) matched **0** — corroborating the world-save ground truth that this stand is conifer-only.

## Companion gates

- **Client stability:** clean — no `INVALID_MESSAGE` / socket errors in the OMEN client log across the window.
- **Rollback rehearsal:** the suppression auto-disarmed at `zdoRedirectActiveSeconds`=90 (`redirect_auto_stop`) while the probe window (150s) kept running — P4 step 11, hands-free.
- **Save integrity (HARD gate):** `pass` before, during, and after the disarm save→reload — portals 4472 / spawned 85439 / targets 20255 / locations 18004 all exact, ZDOS 9,155,594 delta 0, `ComfyEra16.db` byte-identical (1,330,070,771 bytes, mtime unchanged). The redirect writes no persisted ZDO state (Serialize is read-only), so the world is a strict no-op — same save-safety class as the I2 pin.

## Target (ground-truthed, not guessed)

world (9376, 544), sector 146:8, **6,447 m from the player's spawn** (49:35) — provably fresh (never synced this session). Chosen by querying the parsed world-save (`ComfyEra16.duckdb`, 9.155M real ZDOs), computing the real tree-prefab hashes, and confirming a conifer stand with **zero building ZDOs in a 256 m box**. Terrain there is high (ground ≈ y79); the teleport floated the player at **Y=105** (above the ~y94 canopy) so the auto-walk did not wedge in trunks. A single teleport loaded the ~5×5 surrounding sectors, syncing 1303 fresh conifers.

## Honest record of how we got here (4 windows)

- **i3-w1** (route control-first): the 90 s active window overlapped only `route_01_open_control` at (0,0), a deliberately empty control stop → 0 suppressed. Route coverage, not mechanism.
- **i3-w2** (rejoin, no relaunch): the client auto-walk is guarded by `AutoRehearsalRunOncePerSession` — it re-arms only on a fresh process launch, so a menu **rejoin** ran no walk → 0 suppressed. Every capture window needs a full client relaunch.
- **i3-w3** (route_05_dense, elevated): route_05_dense is open ocean at the pin but has a small treed island — the redirect **suppressed 88 conifers correctly** (`ack_failures=0`) but **posted 0, dropped all 88**. This exposed the real defect: `ZdoRedirectRunner.PostBatch` used `WebRequest.Create("http://…")`, which throws `NotSupportedException("The URI prefix is not recognized.")` in Valheim's stripped **server** Mono runtime (empty WebRequest prefix table). The live monitor's `supp=0` was a red herring — a disk-flush lag on `redirect-send.jsonl`; the Lumberjacks receipts are the real-time truth.
- **Fix (0.5.12):** replaced the WebRequest POST with a raw `TcpClient` HTTP/1.1 write (`SendHttpPostViaSocket`) — bypasses the prefix table, background-thread safe, throws on non-2xx so the retry/`last_error` path is unchanged. Suppression/ack/rollback semantics identical (0.5.10→0.5.12). Deployed am4 + OMEN.
- **i3-w4:** clean authoritative PASS above.

## Caveats

- Single authoritative window. A 2nd repeatability run is available on demand (one relaunch+join at the same or another ground-truthed conifer sector).
- Full JSON→ZDO decode of the redirected payload is deferred to I4 (inbound injection); I3 proves the wire-equivalent envelope leaves the server losslessly.
- The mechanism-across-builds note: suppression/ack carried unchanged from the proven 0.5.10/0.5.11 pin/redirect path; only the delivery transport changed in 0.5.12.

Provenance + hashes in `PROVENANCE.json`.
