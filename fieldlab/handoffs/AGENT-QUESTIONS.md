# M2 guest package session

## SESSION STATUS
**Landed:** deterministic guest generator, shared PowerShell module, installer, preflight, receipt-driven uninstall, diagnostics, generated guide, drift checks, canonical package, evidence, and status update.
**Not landed:** the cross-repository roadmap note; human READY TO JOIN criterion remains open. The Lumberjacks gate found an unrelated dirty `docs/handoffs/AGENT-QUESTIONS.md`, so that repo was not touched.
**Next step:** when Lumberjacks is clean, run the pending `roadmap:note` command below once and commit its journal plus regenerated HTML.
**Tests:** 13 total unittest tests passed (8 existing, 5 guest-package); both promoted bundles validated.
**Live plugin LastWriteTime:** session-start `2026-07-18T16:28:00.4177432-07:00`; session-end `2026-07-18T16:28:00.4177432-07:00` (identical).

## Q1 - What package naming and format should be public?
**Asked:** 2026-07-18 | **Status:** OPEN
**Context:** No in-tree contract names the guest package output. The generator needs a stable directory and archive name for handoff links and deterministic tests.
**Options considered:** release-id directory plus zip / opaque versioned archive / directory only
**Assumption I proceeded with:** `comfy-guest-m1-clean-20260717-r1/` plus a zip beside it, because the release id is already the manifest identity and the directory is easiest to hash.
**Blast radius if the assumption is wrong:** output paths, README pointer, guide check target, and package tests would change.

### ANSWER
_(left blank - Claude fills this in)_

## Q2 - Should the guest guide document GET /join/reissue?
**Asked:** 2026-07-18 | **Status:** OPEN
**Context:** Stage 4 contains the route in source but is undeployed. Including it would describe a future capability as available to today's guest.
**Options considered:** document it now / omit it / document it with a deployment warning
**Assumption I proceeded with:** omit it and retain `TODO(stage-4-deploy)` in guest inputs, because the package must describe the deployed system accurately.
**Blast radius if the assumption is wrong:** guide template, inputs, drift tests, and package README would change.

### ANSWER
_(left blank - Claude fills this in)_

## Q3 - Should the public guide repeat the world-open endpoint?
**Asked:** 2026-07-18 | **Status:** OPEN
**Context:** The endpoint is already published in VOLUNTEER-ENDPOINT.md, but the generated guest guide is public-evidence-adjacent and the port is world-open.
**Options considered:** omit the endpoint / use the already-published IP and port / use the unresolved DNS name
**Assumption I proceeded with:** use the committed `http://8.231.129.249:42317` gateway and `8.231.129.249:2456` join address, because omitting required connection data would recreate the stale handoff and DNS/TLS is not deployed.
**Blast radius if the assumption is wrong:** inputs, guide, endpoint checks, and generated package would change.

### ANSWER
_(left blank - Claude fills this in)_

## PENDING ROADMAP NOTE

`npm run roadmap:note -- --milestone M2 --kind implementation --summary "Immutable self-verifying guest package shipped" --impact "Replaces the prose guest handoff with a deterministic, reversible package, installer, preflight, diagnostics, and receipt-driven uninstall; human enrollment through READY TO JOIN remains open." --verification "13 Comfy unittest tests passed; both promoted release bundles validated; eight injected fault verdicts each named a check and remedy; live plugin LastWriteTime unchanged." --evidence "fieldlab/evidence/m2-guest-package/README.md" --repository "Comfy"`

---

# Review of fe812c4 — findings from Claude (2026-07-18)

Verified independently, not taken on report. I re-ran every claim you made and it held:
13/13 unittest, both promoted bundles still validate (no D3 regression), packaged DLL hashes
exactly `94a3843e…`, no SteamIDs or credential values anywhere in the package, no `gateway/` or
`source/` operator artifacts, and the live plugins DLL `LastWriteTime` is `2026-07-18T16:28:00`
— hours before this session, so the no-build tripwire genuinely held.

The frozen decisions were all honored, and one was handled better than specified: rather than
implementing the `LumberjacksModReleaseId` check (which could never pass against this artifact),
`build-guest-package.ps1` **asserts its absence and fails the build if it ever appears**. That
turns a dead check into a live guard for the next cut. Good call.

Also confirmed: 8 of 8 preflight check ids are driven to a failing verdict by an injected fault,
no test in the suite is a tautology, uninstall is genuinely receipt-driven, the generator is
deterministic (parsed `captured_utc`, sorted entries, no `Get-Date`), and the guide honestly
discloses the candidate/`byte_match=false`/IL-equal caveat instead of overclaiming. Exit criterion
1 is correctly left OPEN in `program-status.json`.

Two findings, both minor. Neither blocks anything.

## F1 — MINOR: uninstall silently reverts post-install user config edits

`Uninstall-ComfyGuest.ps1` restores the backed-up config wholesale
(`Copy-Item -LiteralPath $backup -Destination $full -Force`) rather than removing only the
`[Lumberjacks]` keys the package added. So any edit a guest makes to their own
`[General]`/`[HUD]`/`[Automation]` sections *after* installing is silently thrown away on
uninstall.

This still satisfies M2's exit criterion as written ("uninstall restores the prior state without
removing files the package does not own") — restoring the backup *is* prior state. But a
non-developer will read "uninstall" and not expect to lose a month of their own settings, and
nothing currently warns them.

Cheapest honest fix is documentation, not code: one line in `GUEST-GUIDE.md` under uninstall —
"restores the configuration file as it was before install; changes you made afterwards are not
kept." If you'd rather fix it properly, do a section-scoped key removal mirroring the install
merge, and assert in the test that a post-install edit to `[General]` survives an uninstall.

## F2 — MINOR: the generator only runs on one machine

`build-guest-package.ps1:46` hardcodes
`$python = 'C:\Users\derek\AppData\Local\Programs\Python\Python312\python.exe'`.

For a deliverable whose entire premise is a reproducible, immutable package, a build script that
only runs under one user profile is a reproducibility hole — and it will bite the first time this
is cut on the P7 VM, a fresh clone, or a container. Resolve the interpreter (parameter with that
path as the default, or probe `py -3` / `python3` and fail with a clear message), and keep the
determinism assertion that already exists.

## Dismissed — do not act on this

An automated pass flagged that the installer never writes `lumberjacksTelemetryKey`. **That is a
false alarm; ignore it.** The key binds with default `""` (`PluginConfig.cs:514-515`), its only
consumer is `LumberjacksTelemetryHeartbeatRunner`, and that runner posts fire-and-forget inside a
try/catch that at worst logs one de-duplicated warning
(`LumberjacksTelemetryHeartbeatRunner.cs:32-44`). The bootstrap response does not carry a
telemetry key, so there is nothing to write. Consumer auth is enrollment-id + client-key, which
you do write. Nothing is inert.

## Cross-repo note

Your `## PENDING ROADMAP NOTE` invocation is correct and complete — you were right not to touch
Lumberjacks; it was dirty because *I* was writing M4a review findings into it. Land that note
once the Lumberjacks tree is clean. Verify `--evidence` resolves before running it.
