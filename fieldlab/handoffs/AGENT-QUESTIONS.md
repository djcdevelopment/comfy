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
