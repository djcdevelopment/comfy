# Plan — cutover to `baseline` (full-stack monorepo)

2026-07-21. Written at the close of the window that deployed `m5-recipients-20260720-r1`
and world-tested recipient-scoped delivery end to end. Target repo:
`https://github.com/djcdevelopment/baseline` (private, empty at time of writing) —
*"Merges Comfy repo and mods with Lumberjacks network implementation."*

## 1. Why this exists

A cross-repo audit run on 2026-07-21 catalogued where `comfy` and `Lumberjacks` fight for
control of the same concerns. **Most of what it found is not a bug in either repo — it is a
consequence of there being two repos.** A monorepo does not resolve those ownership debates;
it deletes them. This document carries the audit's findings forward so the cutover starts
from evidence rather than from memory.

Two of the audit's recommendations were explicitly left undecided because they were not
answerable from repo contents: who owns the production `docker-compose.yml`, and who owns
the VM environment-file template. **In `baseline` both questions disappear.**

## 2. What is true right now (the state being carried over)

| Fact | Value |
| --- | --- |
| Release | `m5-recipients-20260720-r1` (both-sides cut) |
| Mod DLL | `035faa8793114c75…` — client and P7 server both on it |
| Gateway image | `sha256:69e025e8c13b…` |
| Superseded mod | `94a3843e…` (the previously frozen 0.5.31 artifact — **unfrozen** by this cut) |
| comfy commit | `8ca27ed` |
| Lumberjacks commit | `1d801e7` (manifest), later notes through `53ca8a0` |
| P7 VM | `comfy-lumberjacks-p7`, `n2-highmem-2`, **STOPPED** |
| Manifest | `Lumberjacks/docs/roadmap/m5-recipients-build-candidate.json` |

Proven live this window: the P7 server stamps the destination peer at Valheim's per-peer
sync-list boundary, the Gateway maps that Steam identity to its own opaque recipient on
ingest, and a real enrolled client drained **its own partition** with populated correlation
ids. That is `plan-m4-unification.md` §3 — the sentence the plan called unprovable.

## 3. Open items that must survive the cutover

Ordered by how badly they bite if forgotten.

1. **The release gate covers one service out of five.** P7 compose pins `gateway` to a
   release image, but `eventlog`, `progression`, and `operatorapi` use
   `build: context: ${LUMBERJACKS_ROOT}` — compiled from whatever source sits on the VM.
   No release identity, no gate, no hash in any manifest. Drift between the pinned gateway
   and an unpinned sibling raises **no error and no reject, only wrong behaviour**. Neither
   repo had documented this. Recorded in the m5 manifest limitations.
2. **`StrictRosterEnabled` is config pretending to be state.** In-memory only; every
   container recreate and every VM restart silently disarms it. Re-armed via
   `POST /valheim/handshake/config`. There is no versioned source of truth for an
   operationally load-bearing flag.
3. **`program-status.json` is stale and structurally will be again.** It still advertises
   "Stage 1 … is clear to run … closes F1 live for the first time" after Stages 1–4 landed.
   The fix is not another refresh — it is to stop restating M-series state in a second
   surface and hold a pointer instead. In `baseline`, keep **one** status surface.
4. **37 infra files on the VM differ from the commit.** `/opt/comfy` was given git
   provenance this window (`git init` + remote + `reset --mixed`, no files written), so the
   drift is now visible. The deployed `docker-compose.yml` is clean at 0 lines; the rest
   (`main.tf`, `monitoring.tf`, the systemd unit) is provisioning-era stale, and
   `PROMOTION-DRILL.md` / `New-GatewayReleaseCut.ps1` are not on the box at all.
5. **`run-promotion-drill.ps1` has stale rollback defaults.** It hardcodes M0-era rollback
   identities; the documented Phase 3 command overrides neither, so following the runbook
   verbatim would overwrite the deployed mod with a historical one and restart the server to
   verify it had. Direct promotion was used instead. **Still unfixed in the script.**
6. **Two-consumer isolation is untested, deliberately pinned** until volunteers exist. It is
   *untested*, not *blocked* — the partitions now exist for it to bite on.

## 4. Traps that cost time this window — do not rediscover them

- **The env file does not reach the container.** `/etc/comfy-p7/environment` is read by the
  *compose process*, not the container. Without a `${...}` reference in the compose
  `environment:` map, a flag looks set and reaches nothing. Only `docker exec … printenv`
  proves it.
- **Order is mod first, flag second.** Flipping `ProducerEmitsRecipients` before the mod
  that stamps recipients is deployed opens silent total delivery loss — consumer resolves to
  its own partition while the producer still files under `legacy`.
- **Python `write_text` on Windows converts `\n` → `\r\n`.** It rewrites LF-stored files
  wholesale; on the append-only roadmap journal that turned a one-line append into "44
  insertions, 43 deletions." Always pass `newline="\n"`.
- **Never pipe a validator into `tail` under `set -e`.** The pipeline exit status is the last
  command's, so the gate's failure is swallowed and the script commits anyway. Use
  `set -eo pipefail`.
- **PowerShell 5.1 + `2>&1` on a native exe** turns stderr into terminating errors and aborts
  the script. Do not redirect; stderr is captured already.
- **`gcloud` IAP ssh must run in the foreground.** Backgrounded, the payload runs and the
  output is lost.
- **The public roadmap validator rejects SteamIDs.** It is right to. Redact identifiers in
  any note destined for `roadmap.html`.

## 5. Suggested cutover shape

Not prescriptive — the ordering matters more than the details.

1. **Land both trees whole first.** Preserve history if practical; a squashed import loses the
   provenance that several manifests reference by commit sha (e.g. the roadmap links a
   GitHub blob pinned to comfy `433f1cc3`).
2. **Collapse the release lifecycle.** All cut/verify/promote/rollback tooling currently lives
   in `comfy` and builds `Lumberjacks` artifacts. In one repo it is simply *the* release
   tooling. Fold the mod half and the Gateway half into one cut that emits one manifest.
3. **Extend the gate to all five services** (open item 1) while doing so — this is the moment
   it is cheapest.
4. **One status surface.** Keep the living roadmap (it is the present tense, it is validated,
   and it is already published). Retire `program-status.json` to a historical record with a
   pointer, or fold the I0–I7 ladder into the roadmap as history.
5. **Check in an `environment.example`** so the VM's unversioned config has a tracked shape.
6. **Then re-provision the VM from `baseline`** and confirm the result reproduces what was
   world-tested this window. That is the real acceptance test for the cutover: *the state we
   proved by hand becomes the state the repo produces.*

## 6. The honest framing

Today's end-to-end run was **session state, not repo state**. Everything holding it together
was done by hand: image saved/scp'd/loaded, mod DLL copied into the container and the client,
compose file copied, strict roster armed by an HTTP call. If the VM were rebuilt from either
repo tomorrow, it would not come back.

The point of `baseline` is to make the proven state the *reproducible* state. Item 6 above is
therefore the only completion criterion that counts.

## References

- Release manifest: `Lumberjacks/docs/roadmap/m5-recipients-build-candidate.json`
- Living roadmap: `Lumberjacks/docs/roadmap/` (notes 44–50 cover this window)
- Unification plan: `Lumberjacks/docs/plan-m4-unification.md`
- Stage 1 runbook: `Lumberjacks/docs/runbook-m4a-stage1-live-test.md`
- Risk 12 decision: `Lumberjacks/docs/decision-release-reproducibility-risk-12.md`
