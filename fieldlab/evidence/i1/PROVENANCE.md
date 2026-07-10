# I1 evidence — provenance & hashes

Rung **I1 (interception reachability)** run of 2026-07-09, adjudicated by the ground-truth audit
(see `../../GROUND-TRUTH.md`, verdict 3). Tracked here because `fieldlab/runs/` is gitignored
and the originals live only on OMEN disk + am4 (both volatile).

## Files

- `netcode-probe-summary.json` — full verifier summary (copy, byte-identical to
  `fieldlab/runs/i1/netcode-probe-summary.json`).
- `netcode-probe.excerpt.jsonl` — first 21 rows (incl. the `start` lifecycle row) + last 20 rows
  of the 5,001-row probe log.

## Hashes of the originals (2026-07-09)

| File | Bytes | MD5 | SHA256 |
|---|---|---|---|
| `fieldlab/runs/i1/netcode-probe.jsonl` | 1,278,604 | `479cc274772ebd0e583f22fede38e9dc` | `3abe7e65aecfbeb420766b74a7d028d5520e900ebc4ccd1abe79c1145f4a11cc` |
| `fieldlab/runs/i1/netcode-probe-summary.json` | 3,773 | `abe69c0ca4b424d9ca0cec428b386a7a` | `0fb271fb798c982bbb6cd7d7a45affabc60500ab7f1da8d0fd048e6fd52e5641` |

The audit independently md5-matched the OMEN copy of `netcode-probe.jsonl` against the source
file still on am4 (`~/comfy-valheim-lab/server-state/config/bepinex/comfy-network-sense/`),
scp'd 37 s after capture.

## Timeline (all 2026-07-09 UTC, cross-verified against session logs + am4 docker logs)

- 14:43:46 — am4 server container (re)start (`StartedAt`)
- 14:46:37 — client connects: SteamID `76561198088711642`, character `Durracktu`
  (character ZDOID `1733452292:10` matches the probe's recv owner uid)
- 14:47:10 — probe auto-start (server log line matches the jsonl `start` row to the second)
- 14:47:10–14:47:14 — 5,000 detail rows captured (initial-connect world-sync burst; detail cap hit)
- 14:47:51 — jsonl scp'd to OMEN `fieldlab/runs/i1/`
- 14:48:15 — verifier summary generated (`pass_i1_reachable_sendzdos_inlined_fallback`)
- 15:06:09 — commit `b5ec7a5` lands (code + docs only; run evidence was gitignored)

## What this run proves — and what it does not

**Proves:** both ZDO funnels (receive via `RPC_ZDOData`, send-side detail via `CreateSyncList`)
are reachable and legible in a live connected session: 1,154 recv + 3,846 send rows, uid/owner
legible on all 5,000, 3,898 distinct ZDOs, 0 malformed in-window. **I1 gate: PASS.**

**Does NOT prove:** (1) `SendZDOs` inlining — the run used `autostop=0`, so no counters row was
emitted; every `*_calls` and `parse_errors=0` in the summary is a verifier fallback default;
(2) sustained-play behavior — this is a 4.2 s connect burst, not a traversal; (3) which machine
hosted the client. The airtight re-run is `TEST-PROGRAM.md` P2 (finite autostop, real counters,
inlining measured).
