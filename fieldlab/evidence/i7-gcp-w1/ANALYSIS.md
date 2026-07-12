# i7-gcp-w1 — corroborating first occurrence (PARTIAL bundle)

**Role:** this is *not* the airtight four-gate milestone bundle. It is the surviving,
independently-harvested evidence that the P7/I7 composition genuinely armed-and-ran
live on the GCP VM `comfy-lumberjacks-p7` on 2026-07-11 (local) — the window the
worklog + `infra/gcp/p7/README.md` describe but never archived to the project's
evidence standard. The complete archived capture is the fresh window **i7-w6**
(sibling dir `evidence/i7-w6/`); the two windows together satisfy P7 step8
(repeatability: two independent live windows, one fully archived).

## What is corroborated (non-doc, surviving artifacts)

- **Infra / no-OOM:** `environment.txt` — VM has ~48 GiB free of 62; mod DLL
  SHA-256 `827fc6b2…c4f816d` == the documented 0.5.18 binary.
- **I5 handshake (server log):** `ACCEPT (Lumberjacks-decided) window=i7-gcp-w1
  uid=1272968031 player=Durracktu host=76561198088711642 net_version=36` →
  `Server: New peer connected`. Admission decided by Lumberjacks over the real
  ZSteamSocket.
- **Composition armed together, clean stop (server log):** handshake `ARMED` →
  ownership pin `ARMED` → redirect `ARMED` (all `window=i7-gcp-w1`) → pin
  `auto-stopped` cleanly at 17:57:56 — a full window with no OOM clip, which am4
  never achieved.
- **I3 redirect mod-side (redirect-send jsonl):** authoritative `redirect_auto_stop`
  row `seq=6316 suppressed=6316 posted_ok=6316 ack_failures=0 dropped=0 requeued=0`,
  session `20260712-005025-b488d679`. This is the mod send-of-record and matches the
  documented 6316.

## Honest gaps (why a fresh window was still required)

- Redirect **gateway-receipts** half lost (gateway bounced after the window) — so
  `receipts_match_no_loss` cannot be re-adjudicated here; only the mod count stands.
- **I2 pin** counts (25 pinned / 106 holds) are doc-only for this window — the pin
  armed + stopped cleanly per the server log, but no `i7-gcp-w1`-tagged pin rows
  survive.
- **I4 injection** client-side artifacts cleared on relaunch; not captured.
- No archived save-integrity before/after pair for this window.

See `PROVENANCE.json` for file hashes and the structured claim/gap list.
