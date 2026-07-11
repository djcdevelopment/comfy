# GitHub Integration Strategy

Status: proposed

Last reviewed: 2026-07-11

## 0. Purpose and scope

This is an implementation proposal for how GitHub, GitHub Actions, and Google Cloud divide
responsibility around the fieldlab netcode-replacement program — the active work described in
[`fieldlab/GROUND-TRUTH.md`](../fieldlab/GROUND-TRUTH.md) and staged in
[`fieldlab/TEST-PROGRAM.md`](../fieldlab/TEST-PROGRAM.md). It is written for whoever builds
`.github/workflows/`, not as a tour of GitHub features.

It assumes the state already on disk, which is further along than a typical greenfield ask —
this repo already runs an evidence-driven, scenario-oriented test program by hand:

- **Portable Scenarios already exist** as YAML under `fieldlab/scenarios/` (e.g.
  `lumberjacks-native-runtime-smoke.yaml`, `valheim-lumberjacks-shadow-authority.yaml`), each
  declaring a goal, hypothesis, runtime targets, probes, metrics, pass/fail gates, and
  stop-and-reassess conditions.
- **A scenario runner already exists**: `fieldlab/scripts/run-experiment.ps1` takes a scenario
  path, produces a timestamped run folder under `fieldlab/runs/`, and writes the packet standard
  fixed in [`fieldlab/README.md`](../fieldlab/README.md): `experiment.yaml`, `environment.json`,
  `commands.ps1`, `raw/`, `telemetry/`, `captures/`, `results.json`, `report.md`, `publish.md`,
  `quickstart.md`, `signature.json`.
- **A capability-promotion ladder already exists**: the I0–I7 invariant ladder in
  [`fieldlab/VALHEIM-NETCODE-REPLACEMENT-WORKLOG.md`](../fieldlab/VALHEIM-NETCODE-REPLACEMENT-WORKLOG.md),
  staged through phases P0–P7 in `TEST-PROGRAM.md`, tracked machine-readably in
  `fieldlab/status/program-status.json` and rendered to a live dashboard by
  `fieldlab/scripts/render-dashboard.py`.
- **An evidence discipline already exists, post-incident**: `TEST-PROGRAM.md`'s operating
  contract states a step is DONE only when its gate artifact is archived under
  `fieldlab/evidence/` or a signed run packet, and the **2-source corroboration rule** — nothing
  counts without ≥2 independent non-documentation sources — is already enforced by hand.
- **Runtime topology is real and known-hard-won**: dedicated server on **am4** (native Linux
  Docker — Docker Desktop on Windows does not publish UDP, per the Trap 1 writeup in
  [`fieldlab/MULTIPLAYER-NETWORK-SETUP.md`](../fieldlab/MULTIPLAYER-NETWORK-SETUP.md)), a real
  GPU player seat on **OMEN**, deploys via `docker exec`/`scp` against
  `~/comfy-valheim-lab/server-compose.yml`.
- **A GCP migration is already decided, not proposed here**: `program-status.json`'s
  `needs_derek` field records it verbatim — am4 is host-memory-exhausted (30GB ~97% used, swap
  full, OOM-killing the server mid-run) and is blocking P7's final clean capture; the plan on
  record is *"migrate am4 to a GCP VM with headroom, then one clean window lands P7."* §7 and
  §11 design GitHub's role in that migration, not a hypothetical one.
- **MCP-driven automation already exists**: the `comfy_gateway` MCP server exposes deploy,
  probe-window, telemetry-tail, and status tools so Derek's manual role stays "launch Valheim,
  restart when a mod update needs it" while everything else runs headlessly — this is the
  automation surface CI hooks into, not a new one.

There is no `.github/` directory yet. This document defines what goes into it so it extends what
already works rather than replacing it.

---

## 1. Overall GitHub Strategy

GitHub's job is **bookkeeping, orchestration, and record-keeping** for a program whose truth
lives in evidence packets under `fieldlab/evidence/` and `fieldlab/runs/`, not in GitHub itself.
GitHub Actions never becomes a second source of truth about whether a gate passed — it runs the
scenario, captures what came out, and stores a pointer to it, exactly as `run-experiment.ps1`
already does locally. GCP's job, once the am4 migration lands, is **runtime**: hosting the
Valheim dedicated server container and the netcode-probe capture path under real memory headroom.
am4/OMEN as physical hosts stay in the loop for whatever GCP genuinely can't do (a rendered
GPU player seat needs a real screen and a real Steam session — that's OMEN's job forever, per
the `MULTIPLAYER-NETWORK-SETUP.md` topology table; GCP takes over the *server* side only).

| Concern | Home | Why |
|---|---|---|
| Source of truth for code (mod, MCP tools, scripts) | GitHub (Git) | Standard. |
| Scenario execution, evidence capture, gate checking | GitHub Actions, mirroring `run-experiment.ps1` | Same reproducibility argument that already justified the packet standard — a run triggered by CI should produce the identical packet shape a human triggers locally. |
| Human review of judgment calls | Pull Requests | Where a mod diff, its gate evidence, and a reviewer's read of the 2-source rule co-locate. |
| Bugs, infra asks (e.g. "am4 is OOMing") | Issues | `program-status.json`'s `needs_derek` field is already doing this job by hand; an Issue is the same fact, queryable and closeable. |
| Open questions before they're a decision | Discussions | Not actionable until promoted to an Issue or an entry in `DECISIONS-PENDING.md`. |
| Immutable milestone record | Releases (tags), one per phase gate close (P2 CLOSED, P6/I5 CLOSED, etc.) | A Release names the exact mod build (`0.5.x`), the commit, and the evidence bundle that closed that phase — matching how `GROUND-TRUTH.md` already narrates phase closures by commit and mod version. |
| Container images (Valheim server image + mod-baked variant) | Google Artifact Registry, referenced by digest | The GCP migration target pulls by digest, not by a moving tag — see §6. |
| Evidence (run packets, telemetry, signature.json) | GCS bucket, indexed from the run; `fieldlab/evidence/` and `fieldlab/runs/` stay the in-repo index | GitHub Actions' own artifact retention (90 days) is shorter than this program's evidence needs to live — `GROUND-TRUTH.md` cites run packets from a week earlier as live corroboration. |
| Documentation | `docs/`, `fieldlab/*.md` in-repo | Already the pattern — `GROUND-TRUTH.md` is explicitly "the canonical entrypoint," versioned with the code it describes. |
| Deployment orchestration | GitHub Actions triggers the same `comfy_gateway` MCP deploy path (or its GCP successor) that Derek already drives by hand | GitHub decides *when* and *what mod build*; it does not become a second control plane alongside the MCP gateway. |

**What does not belong in GitHub:** long-lived credentials for am4/OMEN SSH or the future GCP
VM (Workload Identity Federation mints short-lived tokens instead, §7/§13); the Steam account
credentials for `waryfool`/`floooooobcakes` (these stay operator-held, never touched by
automation — see §13); anything that requires a rendered screen and a human hand on a
controller (Derek's OMEN seat is not automatable and this document does not try to make it so).

---

## 2. Repository Structure

Most of this already exists; this section names what's implicit and adds only what's missing
(`.github/`).

```
fieldlab/
  scenarios/            # Portable Scenarios — YAML, already exists (§4)
  scripts/               # operator scripts: run-experiment.ps1, run-*-window.ps1, validate-run-packet.ps1, verify-netcode-probe.ps1 — already exists
  runs/                  # per-run evidence packets, timestamped folders — already exists (§5)
  evidence/               # gate-scoped evidence archive (i1, i2-pin, i5-handshake, ...) — already exists (§5)
  status/                 # program-status.json + rendered dashboard — already exists
  handoffs/                # segment-decomposed builder briefs — already exists, pattern reused for CI-triggered isolated jobs
  autonomous/, hardware/, docs/, retro/, routes/, command-plans/   # existing subdirectories, unchanged by this proposal
docs/
  github-integration-strategy.md   # this file
  kernel.md, positioning.md, adoption-strategy.md, governance.md   # existing strategy docs, unchanged
network/                  # research fork, unchanged
handoffs/                 # top-level handoff kits (e.g. gallery pipeline), unchanged
.github/
  workflows/              # NEW — CI/CD pipeline (§3)
  actions/                # NEW — composite actions once ≥2 workflows share a step sequence (§14)
```

**Why nothing new is needed under `fieldlab/` itself:** the scenario/evidence/runner shape this
document's brief asks for (`scenarios/`, `evidence/`, an operator grammar) is not a proposal
here — it is already built, in daily use, and load-bearing for the P0–P7 program. The only gap
is that it currently runs by hand or via ad hoc PowerShell sessions; `.github/workflows/` is
where it gets a second, unattended trigger path that produces byte-identical packets.

---

## 3. CI Pipeline

One workflow, `.github/workflows/ci.yml`, triggered on `pull_request` and `push` to `main`
(matching the repo's actual default branch — `GROUND-TRUTH.md` cites `main == origin/main`
explicitly as a trust signal, so CI should never introduce a divergent branch model). Given the
runtime dependency on am4/OMEN-class hardware (native Docker with real UDP publishing, and for
some scenarios a rendered GPU client), most stages run on a **self-hosted runner living on the
same network as the lab hosts** from day one — this is not the §14 "scale later" self-hosted
step, because GitHub-hosted runners categorically cannot reach a UDP-publishing Docker host or a
GPU-rendered Steam session. The stages that don't need lab hardware (build, lint, unit tests on
the MCP tooling and `ComfyNetworkSense.cs`) run on standard GitHub-hosted runners to keep the
self-hosted pool free for what only it can do.

### Stage: Commit
- **Input:** pushed commit / PR head SHA.
- **Output:** the trigger event.
- **Failure condition:** N/A.

### Stage: Build
- **Input:** checked-out source.
- **Output:** the mod builds clean — `dotnet build` for `ComfyNetworkSense.cs` and its project,
  matching the "0 warnings" bar `GROUND-TRUTH.md` already treats as a trust signal; MCP
  gateway/tool code builds if it has its own project.
- **Failure condition:** compile error, or a warning where the codebase's own stated bar is 0
  warnings.
- **Artifacts produced:** none persisted — a gate, not a producer.

### Stage: Static analysis
- **Input:** source.
- **Output:** lint/format checks on Python (`render-dashboard.py`, `observe_priority_manifest.py`)
  and PowerShell (`PSScriptAnalyzer` against `fieldlab/scripts/*.ps1`), CodeQL for C#/Python
  (§13).
- **Failure condition:** analyzer findings at or above configured severity.
- **Artifacts produced:** CodeQL SARIF upload.

### Stage: Unit tests
- **Input:** source.
- **Output:** whatever hermetic tests exist under `tests/` at the repo root.
- **Failure condition:** any test fails.
- **Artifacts produced:** test result files, uploaded and summarized in the job summary.

### Stage: Portable Scenario execution
- **Input:** built mod DLL, a scenario set selected from `fieldlab/scenarios/` by PR
  labels/changed-file paths (a PR touching only `render-dashboard.py` doesn't need
  `valheim-lumberjacks-shadow-authority.yaml`; a PR touching `ComfyNetworkSense.cs`'s ownership
  code triggers the I2/pin scenarios).
- **Output:** exactly what `run-experiment.ps1` already produces locally, invoked identically
  from the self-hosted runner: `.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\<name>.yaml`.
- **Failure condition:** a scenario's declared `pass_fail_gates` are not met, or its
  `stop_and_reassess` conditions trigger (e.g., service fails health readiness after 120
  seconds — already a defined gate in `lumberjacks-native-runtime-smoke.yaml`).
- **Artifacts produced:** the run folder under `fieldlab/runs/<timestamp>-<scenario>/`, pushed
  to the evidence store (§5).

### Stage: Evidence capture
- **Input:** raw output from the scenario run — this stage is not a separate pass over logs
  afterward, it is the packet standard the runner already writes: `environment.json`,
  `raw/`, `telemetry/`, `captures/`, `results.json`.
- **Output:** `signature.json` — the existing packet standard already names this field; CI
  computes it the same way a human run would, content-hashing the packet's files.
- **Failure condition:** a scenario's `metrics` list (per its YAML) is missing a required
  metric, or `results.json`'s `has_lifecycle_summary` is false — `TEST-PROGRAM.md`'s own rule:
  *"A PASS with `has_lifecycle_summary=false` or fallback-default counters is not a PASS."* CI
  enforces this exact rule mechanically instead of relying on a human catching it, which is
  precisely the class of bug that produced the "SendZDOs inlined" overreach documented in
  `GROUND-TRUTH.md`.
- **Artifacts produced:** the evidence bundle, indexed (§5).

### Stage: Artifact creation
- **Input:** build output.
- **Output:** publish-ready mod DLL, an SBOM against its dependency lockfile.
- **Failure condition:** publish fails or SBOM generation fails.
- **Artifacts produced:** publish output, SBOM.

### Stage: Container build
- **Input:** the mod DLL, the existing `ghcr.io/community-valheim-tools/valheim-server` base
  image referenced in `server-compose.yml`.
- **Output:** a derived image with the mod baked in at a known layer, rather than the current
  runbook's `scp`-the-DLL-into-a-running-container deploy path — this is the one structural
  change this proposal introduces, because "which DLL is actually running" was exactly the class
  of ambiguity Trap 2 in `MULTIPLAYER-NETWORK-SETUP.md` already burned hours on (a decoy config
  path, not a decoy image, but the same root problem: two candidate answers to "what's really
  active").
- **Failure condition:** image build fails.
- **Artifacts produced:** locally tagged image.

### Stage: Container signing
- **Input:** built image.
- **Output:** cosign keyless signature over the image digest.
- **Failure condition:** signing fails.
- **Artifacts produced:** signature + attestation.

### Stage: Publish image
- **Input:** signed image.
- **Output:** pushed to Google Artifact Registry via Workload Identity Federation.
- **Failure condition:** push/auth fails.
- **Artifacts produced:** the image digest — the single identifier carried forward, same
  principle as §6.

### Stage: Deployment candidate
- **Input:** the published digest + evidence bundle + SBOM.
- **Output:** a candidate record `{ digest, commit_sha, mod_version, evidence_manifest_url,
  scenario_results, invariant_gates_touched }` — the last field maps the change to which of
  I0–I7 it's relevant to, so the promotion recommendation (below) can reason about the right
  ladder rung.
- **Failure condition:** any upstream stage failed.
- **Artifacts produced:** the candidate record.

### Stage: Optional staging deployment
- **Input:** a deployment candidate, `main`-only.
- **Output:** deployed to am4 today (or the GCP VM post-migration, §11) via the same
  deploy path the MCP gateway already drives, pointed at the pinned digest.
- **Failure condition:** deploy fails, or post-deployment validation fails, triggering rollback
  to the previously-deployed digest — mapped onto the existing "config-driven auto-start" and
  "one-command deploy→run→pull→gate wrapper" guardrail already required by `TEST-PROGRAM.md`'s
  operating contract.
- **Artifacts produced:** deployment log, previous-digest record.

### Stage: Post-deployment validation
- **Input:** the newly staged deployment.
- **Output:** the relevant scenario(s) re-run against the live am4/GCP target — same scenario
  code, only the target host changes, matching §4's portability requirement. For scenarios that
  require a real rendered client (P6 handshake, P7 loopback), this stage flags that a human
  touchpoint is required rather than attempting to fake a GPU session — this is not a gap to
  paper over, it's the honest boundary `TEST-PROGRAM.md` already draws around Derek's
  "in-game presence" role.
- **Failure condition:** a scenario passes headlessly but fails against the live target — the
  same signal class as the OOM-kill root cause already diagnosed in `GROUND-TRUTH.md`, which
  this stage would have caught mechanically instead of costing a multi-hour investigation.
- **Artifacts produced:** a second evidence bundle tagged `environment: staging`, linked to the
  same commit SHA.

### Stage: Promotion recommendation
- **Input:** the full chain plus the run-history for the relevant I0–I7 invariant.
- **Output:** a recommendation, not a decision — a PR comment or Release draft stating which
  invariant gate this evidence would newly satisfy, checked against the 2-source corroboration
  rule already in force (`program-status.json`'s `trust` block). If the new evidence is the
  *first* source for a claim, the recommendation says so explicitly rather than reporting a
  premature PASS — directly preventing the exact overreach class `GROUND-TRUTH.md` documents
  (fallback-default counters read as measurements).
- **Failure condition:** none — makes no decision.
- **Artifacts produced:** the recommendation, handed to §9/§10.

---

## 4. Portable Scenario Execution

The operator grammar already exists in substance across `fieldlab/scripts/`; this section names
the six verbs and maps each onto what's already there, rather than inventing a new interface:

| Verb | Existing equivalent | Responsibility |
|---|---|---|
| `prepare` | `install-dotnet9.ps1`, `bootstrap-lumberjacks.ps1`, `bootstrap-wsl-postgres.ps1`/`bootstrap-windows-postgres.ps1` | Bring up dependencies the scenario needs but doesn't own. On `ci`/`staging` targets, a no-op if the self-hosted runner's environment is already provisioned. |
| `launch` | the deploy half of `run-*-window.ps1` scripts, or `comfy_gateway`'s deploy tool | Start or confirm the target (Valheim server container, Lumberjacks gateway services) is reachable — health-checked exactly as `lumberjacks-native-runtime-smoke.yaml` already does per-service (`health: http://localhost:4000/health`, etc.). |
| `join` | the client-connect half of `run-loopback-window.ps1`/`run-handshake-loopback.py` | Connect scenario actors — a headless probe client for I1-class scenarios, or a flagged "needs Derek" touchpoint for scenarios that require OMEN's rendered seat (P6/P7-class). |
| `observe` | `run-injection-window.ps1`, `run-redirect-window.ps1`, `run-netcode-probe-cycle.ps1`, `analyze-networksense-perf.ps1` | Drive the scenario and capture evidence as it happens — telemetry tail, probe counters, the packet's `raw/`/`telemetry/`/`captures/` — not a separate pass afterward. |
| `cleanup` | the teardown half of the window scripts | Stop probes, disconnect clients. Best-effort; a cleanup failure doesn't flip a passing scenario to failing. |
| `rollback` | mod version pin flip, `ownershipPinEnabled=false`-style config rollback already documented as the pattern in `GROUND-TRUTH.md`'s P3 writeup | Only invoked by the pipeline's Post-deployment validation stage, never by a scenario directly — reverts a staging/production deployment to the previously-known-good mod build and config. |

**Portability guarantee, and its real boundary:** the same scenario YAML and its declared probes
run unmodified against `local` (a contributor's own am4-class dev host, if they have one),
`ci` (the self-hosted runner), and `staging`/`production` (am4 today, GCP post-migration) —
this is already true today of `lumberjacks-native-runtime-smoke.yaml`, whose `probes` accept a
gateway URL argument the same way `deployment-strategy.md`-style smoke tests do in the
Lumberjacks repo it targets. The honest exception, already acknowledged in `TEST-PROGRAM.md`'s
operating contract, is any scenario requiring a **rendered GPU client with a live Steam
session** (P6 handshake satisfaction, P7 loopback integrity) — there is no portable way to
automate "a real screen and a real controller," and this document does not pretend otherwise.
Those scenarios stay `advisory`/human-gated in CI (§10) and are the ones whose
`stop_and_reassess`/`needs_derek` fields route straight to a human touchpoint, exactly as
`program-status.json` already does.

---

## 5. Evidence Pipeline

**Evidence** is what a scenario or pipeline stage directly observed and recorded, unmodified,
at the time it happened — the packet standard already fixes this shape: `environment.json`
(git state, machine facts), `raw/` (unprocessed logs), `telemetry/` (probe JSONL — e.g. the
1.28 MB `netcode-probe.jsonl` cited as I1's corroborating evidence), `captures/` (screenshots,
recordings), `results.json` (gate outcomes and counters), `signature.json` (content hash).

**Interpretation** is anything derived from evidence by a person: `report.md`'s narrative,
`GROUND-TRUTH.md`'s verdicts, a promotion recommendation's accept/reject, this document's own
prose. `program-status.json`'s `headlines` array is interpretation *about* evidence, clearly
labeled with a `verdict` (`good`/`warn`) rather than presented as a raw measurement — this
repo already models the evidence/interpretation split correctly; CI should not blur it back
together.

- **What is evidence:** `netcode-probe.jsonl` rows; `telemetry-server.jsonl`; save-file
  ZDO-count deltas (save-integrity checks); `results.json` counters; `environment.json`'s git
  SHA and machine facts; screenshots under `captures/`; the am4 docker logs and `md5` checks
  already used as corroborating sources in `GROUND-TRUTH.md`.
- **What is interpretation:** "the I1 PASS is real" (a conclusion drawn from four evidence
  sources); "SendZDOs is inlined" (flagged in `GROUND-TRUTH.md` as an overreach precisely
  because it was asserted without evidence); any `report.md` narrative section.
- **What can change:** interpretation — `GROUND-TRUTH.md` already corrects three prior claims
  in place, explicitly labeled as corrections, while the underlying evidence files that
  triggered the correction (the `autostop=0` probe run) are untouched.
- **What must never change:** a run packet's evidence files, once its `signature.json` hash has
  been referenced by a PR, Release, or `program-status.json` entry. A bad or misleading capture
  is superseded by a new timestamped run folder, never edited in place — this is already the de
  facto behavior (every run gets its own `fieldlab/runs/<timestamp>-<scenario>/` folder); CI's
  job is to make violating it (e.g., an agent overwriting a prior run's `results.json`) actually
  impossible rather than just discouraged, via GCS object versioning + a retention lock on the
  evidence bucket, mirroring the corpus-overwrite incident risk this kind of program is
  otherwise exposed to.

**Storage:** v1 mirrors every CI-produced run packet to a GCS bucket
(`gs://comfy-fieldlab-evidence/<scenario>/<run_id>/`) via Workload Identity Federation, with
`fieldlab/evidence/` and `fieldlab/runs/` staying the in-repo index — exactly their current
role — so `git log` on those paths remains a durable index of what evidence exists without
needing to query GCS to find out. The **2-source corroboration rule** already in force
(`program-status.json`'s `trust.rule`) becomes a mechanical check at the Evidence capture stage:
a claim isn't marked corroborated until its manifest references ≥2 independently-sourced
evidence entries (e.g., a probe JSONL *and* a docker log, not two views of the same file).

---

## 6. Artifact Strategy

| Artifact | Versioning scheme | Notes |
|---|---|---|
| Mod-baked Valheim server image | Immutable digest, tagged `valheim-server-mod:<mod-version>-<commit-sha>` | Replaces the current `scp`-DLL-into-running-container deploy path with a digest-addressed image — closes the exact "which build is really running" ambiguity Trap 2 already burned hours on for config, and would burn again for binaries without this. |
| Mod DLL (build artifact) | Tied to commit SHA | Input to the container build; not independently released. |
| Scenario outputs / run packets | `<scenario>/<run_id>/signature.json` | Never overwritten; superseded by a new `run_id`. |
| Milestone releases | Tag per phase closure, e.g. `p6-i5-closed-0.5.18`, matching how `GROUND-TRUTH.md` already narrates closures by mod version | Points at the exact image digest + evidence bundle that closed that phase, not a rebuild. |
| SBOMs | One per image, CycloneDX | Attached to the Artifact Registry entry, linked from the Release. |
| Container signatures | cosign, keyless/OIDC, per digest | Verified before the deploy step pulls. |

**Why digests, not tags:** the entire Trap 2 postmortem in `MULTIPLAYER-NETWORK-SETUP.md` is a
case study in what happens when "which config is really active" has two plausible answers — a
real one and a decoy. A mutable image tag (`:latest`) creates exactly that same shape of
ambiguity for binaries. A digest makes "what's deployed" and "what was validated" the same 64
hex characters by construction, closing that class of bug at the artifact-identity level instead
of relying on a runbook warning to catch it (like the current `docker exec ... find` diagnostic
already has to for the config trap).

---

## 7. Google Cloud Integration

This section designs the migration already decided in `program-status.json`'s `needs_derek`
field — am4 is host-memory-exhausted (OOM-killing the server mid-capture) and the fix on record
is moving the dedicated server to a GCP VM with real headroom. GitHub's responsibility ends at
producing a signed, evidenced, digest-addressed image and asking GCP to run it; everything after
— VM state, running containers, the OS-level Docker UDP-publish behavior that already works
correctly on native Linux (unlike the Docker-Desktop-on-Windows trap that ruled out a Windows
VM) — belongs to GCP, managed by Terraform, not workflow YAML.

- **Compute Engine:** the migration target for the am4 role — a Linux Compute Engine VM sized
  for the P7 capture workload's actual measured memory pressure (the postmortem gives a real
  number to size against: 30GB host, ~97% used, swap full, under the exact traffic pattern that
  needs to be reproduced — pick VM memory from that evidence, not a guess). Must run native
  Linux Docker for the same reason am4 was chosen over OMEN originally: UDP publish behavior.
- **Artifact Registry:** authoritative store for the mod-baked server image (§6). GitHub Actions
  pushes via Workload Identity Federation; the VM pulls via its own service account, also via
  Workload Identity.
- **Terraform:** owns the VM, network, firewall (UDP 2456-2457 open, matching the current
  `server-compose.yml` port mapping), and observability config. A separate,
  manually-triggered `infra-apply.yml` workflow, gated by required approval — infra changes are
  a different risk class than a mod-code deploy and shouldn't share a trigger with every PR
  merge.
- **Docker Compose:** stays the runtime orchestrator on the VM, matching
  `~/comfy-valheim-lab/server-compose.yml`'s current shape — this migration changes *where*
  Compose runs, not *how* it's structured, so the hard-won topology knowledge in
  `MULTIPLAYER-NETWORK-SETUP.md` carries over rather than needing to be rediscovered against a
  new platform.
- **Secrets:** short-lived only, minted per workflow run via Workload Identity Federation. The
  Steam account credentials (`waryfool`, `floooooobcakes`) are explicitly **not** GCP secrets —
  they belong to OMEN's human-driven client seat, which does not move to GCP (a GPU-rendered
  Steam session cannot run headless on a server VM; this migration only ever targeted the
  dedicated server role).
- **Identity / Workload Identity Federation:** the trust boundary — a GitHub Actions OIDC token
  scoped to this repo/workflow exchanges for a short-lived GCP token; no standing GCP key lives
  in GitHub.

**Where GitHub's responsibility ends, explicitly:** GitHub does not become the thing watching
for the *next* OOM kill. Ongoing memory/host health monitoring on the GCP VM is Cloud
Monitoring's job, configured once via Terraform — this is the direct fix for the failure mode
that blocked P7: a host-health signal that would have flagged "swap 100% full" well before the
9th OOM kill, instead of it being reconstructed after the fact from container logs and cgroup
counters.

---

## 8. Contributor Experience

Given the current program is effectively single-operator (Derek + Claude, per `TEST-PROGRAM.md`'s
operating contract) rather than open-contribution, "contributor experience" here means **the
onboarding path for a new machine or a new collaborator's laptop reaching parity with am4/OMEN**,
mirrored as closely as possible to what CI does:

```powershell
git clone <repo> && cd comfy
.\fieldlab\scripts\install-dotnet9.ps1
.\fieldlab\scripts\bootstrap-lumberjacks.ps1
.\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\lumberjacks-native-runtime-smoke.yaml
```

- **Verify success:** `run-experiment.ps1` exits reporting the packet's `results.json` status —
  identical to what a contributor would read from a CI job summary.
- **Recover from failure:** the packet's `report.md` is generated from the same
  `New-RuntimeReportLines` logic CI's Evidence capture stage uses, so a contributor reproducing
  a red CI run gets the same diagnosis shape, not a paraphrase.
- **Hardware-gated scenarios:** any scenario in `fieldlab/scenarios/` that requires am4/OMEN-class
  topology (native Linux Docker with real UDP, or a rendered GPU Steam client) is explicitly
  marked as such in its manifest so a contributor on a laptop knows immediately which scenarios
  are theirs to run and which require lab hardware — this is not a gap to hide, it's the same
  honest boundary §4 already draws for CI.

---

## 9. Pull Request Workflow

**Required checks:** Build, Static analysis, Unit tests, Portable Scenario execution (for
non-hardware-gated, non-advisory scenarios), Deployment candidate.

**Posted but not blocking:** staging deployment result, post-deployment validation, the
Promotion recommendation comment — run on `main` merges, not per-PR, given the shared
am4/GCP target.

**Required approvals:** one human for changes under `ComfyNetworkSense.cs`, `fieldlab/scripts/`,
or `fieldlab/scenarios/`. Two for `infra/`-equivalent Terraform changes once §7 lands (matching
the risk-class split already used elsewhere in this proposal). Any PR that touches an I0–I7
invariant's implementation additionally requires the reviewer to check the 2-source
corroboration rule was actually satisfied by the attached evidence, not just that a green
checkmark exists.

**What reviewers evaluate that automation cannot:** whether a scenario's `pass_fail_gates`
still represent the right question (a scenario passing proves the mod does what the scenario
checks, not that the scenario checks the right thing — exactly the gap that let "SendZDOs
inlined" go unchallenged); whether a claim's two corroborating sources are genuinely
independent (the i5-handshake-live client-identity ambiguity in `GROUND-TRUTH.md` — "an
am4-local GPU client container was also up during the window" — is precisely the kind of
false-independence a human has to catch, automation cannot); whether a phase is actually ready
to close.

**Surfaced directly in the PR:** scenario pass/fail summary, evidence bundle links (GCS +
in-repo `fieldlab/evidence/` path), image digest once built, the invariant-gate mapping from the
Deployment candidate record, and a diff against `program-status.json`'s current trust counts
(`claims_total`, `confirmed`, `refuted`, `uncorroborated`) so a reviewer sees at a glance whether
this PR is expected to move those numbers.

---

## 10. Capability Promotion

This program already has a capability ladder — I0 through I7, staged through phases P0–P7 in
`TEST-PROGRAM.md`. This section maps the brief's generic gate names onto the ladder that
actually governs this repo, rather than introducing a parallel one:

| Generic gate | This program's equivalent | Evidence required | Who approves |
|---|---|---|---|
| Experimental | A new scenario exists under `fieldlab/scenarios/`, runs, may be flaky. | One recorded pass, any target. | None — default state for any new scenario, matching how scenarios are added today. |
| Validated | A scenario is required (non-advisory) in CI against `ci`/`local` targets — e.g. today's I1 "reachability" class claims. | N consecutive green runs. | Automatic — a pure repeatability claim. |
| Repeatable | Passes against the live am4/GCP target, not just CI — matches this program's own "repeatable connected baseline" language already used for P2's close ("second green run gated both sides; signed client+server baseline packets"). | Post-deployment validation green across ≥2 independent deploys, satisfying the 2-source rule. | Automation recommends; the on-call reviewer accepts — same low-friction pattern already used when P2 was closed on its second green run. |
| Marked Proven | A human has evaluated it as a real capability, the way `GROUND-TRUTH.md`'s "CLOSED" verdicts already work (e.g. "P6/I5 CLOSED... the FIRST LIVE Lumberjacks-fronted admission") — not just numbers, a judged claim. | The Repeatable-gate evidence bundle plus a written verdict (a `GROUND-TRUTH.md`-style entry or a Release note). | Human only — this is exactly the gate this program already treats as requiring a person's read, per its own "good"/"warn" verdict labeling. |
| Stable | Sustained across a defined window with no regressions — the eventual "P7 CLOSED, repeat run confirms" state this program is currently blocked on reaching. | Accumulated evidence across the window, including the outstanding "one clean single-window four-for-four capture + the repeat" already named as the remaining requirement. | Human — and given P7 composes every prior invariant, this is the highest-stakes promotion in the program; treat it with the same rigor `GROUND-TRUTH.md`'s 10-agent cross-verified audit already modeled. |

**Automatic:** Experimental → Validated, a pure repeatability claim.

**Human-approved:** Validated → Repeatable is automation-recommended, human-accepted. Repeatable
→ Marked Proven → Stable require a human judgment each time — this program has already lived
through what happens when that boundary blurs (the "SendZDOs inlined — SETTLED" claim that
turned out to rest on fallback-default counters, not a real measurement). CI's job is to make
that class of mistake structurally harder, not to take the judgment call away from a person.

---

## 11. Deployment Philosophy

| Environment | What runs there | Reached via |
|---|---|---|
| Local | A contributor's own Docker host, if it meets the native-Linux-Docker UDP requirement | Manual `run-experiment.ps1`. |
| Lab (today) | am4 (server) + OMEN (rendered client) | The existing MCP gateway deploy path; this document doesn't change it, only adds a CI-triggered path alongside it. |
| Lab (post-migration) | GCP Compute Engine VM (server) + OMEN (rendered client, unchanged) | The digest-addressed deploy from §3/§7, replacing am4 as the server target only. |
| Production | Not applicable in the sense of a public game service — "production" for this program is "the topology Derek plays against," which is the lab environment above. | N/A. |

**Rollback:** the deploy step records the digest and config (mod version, `[Netcode]` flags, the
`ownershipPinEnabled`-style toggles) it's replacing before deploying the new one. A failed
post-deployment validation triggers automatic rollback to the previous digest+config pair — this
is the `rollback` verb from §4, invoked by the pipeline, mirroring the exact manual pattern
`GROUND-TRUTH.md` already documents for P3 ("Rollback: `ownershipPinEnabled=false`").

**Blue/green, canary, feature flags:** not needed — there is one server target at a time by
design (a shared multiplayer world can't meaningfully run blue/green). Feature flags already
exist in substance as the mod's own config toggles (`[Netcode]` flags, `ownershipPinEnabled`);
this document doesn't add a new flag system on top of one that already works.

**Disaster recovery:** the world save (`ComfyEra16`) is the one truly irreplaceable asset in
this environment — save-integrity delta checks are already a hard gate on every phase that
writes ZDO state (P3/P5/P7, per `TEST-PROGRAM.md`). The GCP migration should include scheduled
disk snapshots of the world-save volume via Terraform, matching the rigor already applied to
save-integrity checking at the application layer.

**Determinism:** every deployment step operates on a digest and an explicit config snapshot,
never a tag or "whatever's currently on the host" — directly closing the ambiguity class Trap 2
already demonstrated is expensive when left implicit.

---

## 12. Observability

Mostly already exists; CI's job is to feed it, not replace it:

| Signal | Source | Where it lands |
|---|---|---|
| Metrics (probe counters, ZDO throughput) | `netcode-probe.jsonl`, `telemetry-server.jsonl` | Already collected; CI adds a mirrored copy to GCS per §5. |
| Logs | am4 docker logs, container stdout | Cloud Logging post-migration (§7); am4 SSH access today. |
| Host health (memory, swap, OOM events) | **New** — the exact gap that let 9 OOM kills go undiagnosed as "the composition" instead of "the host" | Cloud Monitoring on the GCP VM, configured via Terraform in `infra-apply.yml` — this is the single highest-value observability addition this document proposes, because it directly targets the failure mode already spelled out in `program-status.json`. |
| Scenario duration | Run packet `environment.json` timestamps | Evidence index (§5), trended by the Promotion recommendation stage. |
| Invariant/gate history | `program-status.json`'s `trust` block | Already exists; CI's Evidence capture stage becomes a second writer of this same structure, keeping it as the one place trust counts live. |
| Deployment history | Deployment candidate records + Release tags | Git/Release history — no separate system. |

---

## 13. Security

- **OIDC everywhere a static secret would otherwise sit:** GitHub Actions → GCP via Workload
  Identity Federation; cosign signing keyless via GitHub's OIDC issuer.
- **Least privilege:** separate service accounts for "push image," "deploy to VM," and "apply
  Terraform," scoped by repo and branch.
- **Secret management:** the Steam account pair (`waryfool`, `floooooobcakes`) never becomes a
  GitHub secret or a GCP Secret Manager entry reachable from CI — it's operator-held on OMEN by
  design, since it gates a human-rendered client seat, not an automatable one. Anything the
  server container needs at runtime (world password `comfytest`, etc.) is a GCP Secret Manager
  reference resolved on the VM.
- **Signed commits:** flag-only in v1.
- **Signed containers:** every mod-baked image, cosign-signed; deploy step verifies before pull.
- **Dependency scanning:** Dependabot for the NuGet/Python/PowerShell-module surfaces.
- **CodeQL:** enabled for C# and Python.
- **SBOM generation:** CycloneDX per image, attached to Artifact Registry, linked from Releases.
- **Vulnerability scanning:** Artifact Registry's built-in scanning on push.
- **Policy enforcement:** branch protection for the checks in §9; two-approver rule for
  `infra-apply.yml`-touching changes; no dedicated policy engine needed at current scale.
- **Legal/ToS gate:** `TEST-PROGRAM.md` already names this as *"a hard gate before anything
  ships publicly"* — this document doesn't relax that; nothing in this pipeline auto-publishes
  past that gate, and the Promotion recommendation stage (§3) should surface it explicitly
  whenever a candidate reaches Marked Proven, not assume someone remembers to check it manually.

---

## 14. Scaling Strategy

1. **Simple workflows (where this starts):** one `ci.yml`, one `infra-apply.yml`.
2. **Self-hosted runner (needed from day one, not a later step — see §3):** a runner on the
   am4/OMEN network is required immediately because GitHub-hosted runners cannot reach a
   UDP-publishing Docker host or a rendered GPU Steam session. This inverts the brief's usual
   ladder order — self-hosted isn't a scale-up here, it's a correctness requirement from the
   start, the same way it was already a hard requirement for the manual workflow.
3. **Matrix builds:** introduced only if a genuinely parallel axis appears — e.g. testing against
   multiple Valheim server versions (`l-0.221.12` and a future release) simultaneously. Not
   introduced speculatively.
4. **Reusable workflows / composite actions:** introduced when the deploy-and-gate sequence used
   for staging deployment is duplicated across `ci.yml` and a future second workflow — not
   before duplication is actually observed.
5. **Distributed runners:** only if scenario volume against the lab hardware itself becomes the
   bottleneck (queue depth on the single self-hosted runner), which single-operator program
   volume doesn't currently suggest.
6. **Remote execution:** not on this program's horizon — build times aren't the constraint here;
   hardware availability (one am4/GCP server, one OMEN client) is, and no amount of remote build
   execution changes that ceiling.

The through-line stays the same as the general principle: each step is justified by a number
already visible in this program's own evidence (queue wait, duplicated YAML, a hardware
ceiling), not a prediction.

---

## 15. Guiding Principles

1. **Automate bookkeeping, never judgment.** CI enforces the 2-source rule and the
   `has_lifecycle_summary` check mechanically; it never decides a phase is CLOSED.
2. **Evidence is immutable.** A run packet's files, once referenced, are never edited — only
   superseded by a new timestamped run.
3. **Scenarios define capability.** If `fieldlab/scenarios/` has no YAML for a claim, that claim
   has no evidence-backed standing above Experimental, no matter how confident the prose sounds.
4. **Deploy the artifact that was validated.** A digest and an explicit config snapshot, never
   "whatever's on the host" — the exact discipline Trap 2 proved expensive to skip.
5. **Prefer portable workflows over environment-specific scripts** — with an honest exception
   for what genuinely cannot be automated (a rendered GPU client with a human at the controller).
   Naming that exception explicitly is more honest than pretending portability everywhere.
6. **Scale only when measurements justify it** — and recognize that for this program, a
   self-hosted runner is day-one infrastructure, not a later scaling step, because the hardware
   requirement was never speculative.
7. **Humans approve capability; automation proves repeatability.** The I0–I7 ladder's lower
   rungs are cheap to earn and safe to automate; Marked Proven and Stable cost a real judgment
   call every time, the same way this program's own "CLOSED" verdicts already work.
8. **GitHub orchestrates; GCP and the lab hardware run.** If a design pushes runtime behavior
   (config, Steam credentials, scheduling) into workflow YAML, it belongs in Terraform, the mod's
   own config, or stays with the operator instead.
9. **One source of truth per fact.** An image's identity is its digest. A phase's status is
   `program-status.json` plus its linked evidence, not a comment or a memory of what happened.
   A claim's corroboration is its two independent evidence sources, not a green checkmark alone.
