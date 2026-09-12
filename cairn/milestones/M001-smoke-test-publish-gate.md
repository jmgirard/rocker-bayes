# M001: Smoke-test gate before any tag moves

- **Status:** in-progress
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4, GP8
- **Resolves:** —
- **Surface tier:** user-facing. It decides which images reach the published
  Docker tags.
- **Branch/PR:** `m001-smoke-test-publish-gate`

## Goal

Every tag attached by `.github/workflows/docker.yml` points at an image that
was booted and exercised first. The gate covers three failures: a server that
does not come up, R packages that did not arrive as binaries, and a CmdStan
that cannot compile and sample a model.

## Scope

**In:** a new `.github/smoke-test.sh` with three phases (server up, bspm
binary, CmdStan). Its shape is ported from rstudio2u and the CmdStan phase is
new. Also a restructured `docker.yml`. Every leg pushes by digest on every
ref, pulls the digest back, asserts its architecture, and smoke-tests it. One
publish job attaches tags only after all four legs pass. A `test_mode`
dispatch input runs the whole lane and prints the tag list instead of
attaching it.

**Out:** the pre-merge PR lane and the lint workflows go to M002. The
unattended-rebuild alerts, the keepalive, and the ported unit-test suites go
to M003. The mirror-failure probes from rstudio2u were dropped at the
2026-09-11 plan gate because IP1 makes that behavior the base image's. The
Docker Hub description sync becomes a candidate row.

## Acceptance criteria

- [ ] AC1: Run against a freshly built rocker-bayes image,
      `bash .github/smoke-test.sh <image-ref>` exits 0 and prints one PASS line
      per phase. The container runs and reports healthy within
      `SMOKE_TIMEOUT`. An R package installs through bspm and `dpkg -s` shows
      the matching `r-cran-*` package. `library(cmdstanr)` reports a CmdStan
      path and version. A bundled Bernoulli model compiles and samples, and the
      posterior mean of `theta` lands within 0.05 of its analytic value.
- [ ] AC2: The script exits non-zero and names the phase that failed for each
      of six controls. (a) `ubuntu:24.04`, where nothing serves 8787. (b) The
      built image with `SMOKE_TIMEOUT=1`, which takes the deadline path. (c)
      `SMOKE_PKG` set to a CRAN package that r2u ships no binary for, so
      `library()` succeeds and the `dpkg -s` assertion still fails. (d)
      `SMOKE_STAN_FILE` pointing at a Stan program that does not compile. (e)
      `SMOKE_THETA_REF` set to a value the sampler cannot produce. (f)
      `jmgirard/rstudio2u:noble`, which serves 8787 and has no CmdStan. If the
      base image ever ships CmdStan, control (f) turns green and fails its own
      assertion instead of passing for the wrong reason.
- [ ] AC3: Every build leg pulls back the digest it pushed. The leg fails when
      the image's recorded architecture or the container's `uname -m` does not
      match the architecture that leg declares. The leg then runs
      `smoke-test.sh` against that same pulled digest. One CI run shows the
      assertion line and the smoke PASS on all four legs. A second run with one
      leg's expected architecture inverted shows that leg red at the assertion.
- [ ] AC4: The publish job attaches no tag unless it receives four digest
      files. With fewer it errors and names the count it got. Each leg uploads
      its digest only in a step that runs after that leg's smoke-test step. A
      `test_mode` run with one leg's smoke test forced to fail shows the
      publish job erroring and no tag attached.
- [ ] AC5: The publish job reads the assembled manifest list back before it
      attaches any tag, and fails unless the index names both `linux/amd64` and
      `linux/arm64`. The guard goes red on four bad indexes. One names amd64
      alone. One holds two entries of the same architecture. One holds amd64
      plus an attestation entry whose platform reads `unknown`. One has an
      empty `manifests` array.
- [ ] AC6: `hadolint Dockerfile` reports no violations and `docker build`
      succeeds from a clean context. This is the profile's verify slot.

## Coverage

- AC1 → T1, T2, T3
- AC2 → T2, T3
- AC3 → T4, T5
- AC4 → T5, T6
- AC5 → T6, T7
- AC6 → T8

## Tasks

- [x] T1: Add the Stan fixture that the smoke test compiles. Use a Bernoulli
      model with fixed data and a conjugate posterior, so the expected mean is
      analytic. Decide whether the fixture ships in the image or in the repo.
- [x] T2: Write `.github/smoke-test.sh`. It takes the image reference as its
      one argument. It reads `SMOKE_TIMEOUT`, `SMOKE_PORT`, `SMOKE_PKG`,
      `SMOKE_STAN_FILE`, and `SMOKE_THETA_REF`. It runs under
      `set -euo pipefail`. An EXIT trap dumps container logs on failure and
      always removes the container. The port bind stays on localhost under
      IP2. The phases are the ones AC1 lists. The shape follows
      `rstudio2u/.github/smoke-test.sh:1-124`, without its mirror phase.
- [ ] T3: Run the pass case and the six controls of AC2 against a freshly
      built image. Record the FAIL line from each transcript.
- [ ] T4: In `docker.yml`, remove the `refs/heads/main` guard on the digest
      push so every ref pushes an untagged image by digest. Add the pull-back
      step and the two architecture assertions to each leg.
- [ ] T5: Add the smoke-test step to each leg, ordered before the digest
      upload, so a leg that fails contributes no digest.
- [ ] T6: Replace the two per-variant merge jobs with one publish job gated on
      four digests. This is the all-or-nothing choice made at the 2026-09-11
      gate under GP4. Add the `test_mode` dispatch input and assemble every tag
      in a single `imagetools create`.
- [ ] T7: Add the dry-run manifest read-back and the both-architectures
      assertion before the real create. Drive the four bad indexes from AC5.
- [ ] T8: Update the CI/publish family and the Conventions in
      `cairn/DESIGN.md` to state the gate and the all-or-nothing publish rule.
      Run the verify slot.

## Work log

- 2026-09-11: created by /milestone-plan.
- 2026-09-11: gate chose all-four-legs-or-nothing publishing over per-variant independence. Reason: GP4 makes every leg a commitment. Falsified by evidence that one variant breaks often enough to cost users more than a stale tag.
- 2026-09-11: plan chose pushing untagged digests on every ref over the main-only push guard. Reason: AC4 and AC5 are unreachable off main otherwise. Falsified by untagged digests costing storage or becoming visible to users.
- 2026-09-11: plan chose a conjugate Bernoulli fixture over a richer model. Reason: a known answer keeps the sampling assertion stable. Falsified by the assertion proving flaky in CI at the stated tolerance.
- 2026-09-11: implement gate chose an extracted `.github/publish-guard.sh` with a local test over inline workflow shell. Reason: AC5's four bad indexes run locally in seconds instead of costing four-leg CI builds. Falsified by the script drifting from what the workflow actually calls.
- 2026-09-11: implement gate chose shipping the Stan fixture in the repo over baking it into the image. Reason: it is a CI artifact, and AC2 control (d) needs a second Stan file that no user needs.
- 2026-09-11: implement gate chose verifying both variants' manifest lists before either variant's tags attach. Reason: the 2026-09-11 plan gate already made publishing all-or-nothing across the four legs under GP4.
- 2026-09-11: implement gate left `retry-on-failure` unchanged (the user expressed no preference, so the recommendation was taken). Reason: cached layers make a repeated smoke failure cheap, and the mirror flakiness the job exists for is unchanged.
- 2026-09-11: T1 added `.github/smoke-fixtures/` with `bernoulli.stan`, `bernoulli.data.json` (N=100, sum(y)=40, analytic posterior mean 41/102 = 0.4019608) and `does-not-compile.stan` for AC2 control (d).
- 2026-09-11: `hadolint Dockerfile` reported DL3025 on the pre-existing shell-form HEALTHCHECK. Rewrote it in exec form. hadolint is now clean. AC6 needs this.
- 2026-09-11: T2 wrote `.github/smoke-test.sh`. Three phases, each printing one PASS line and every failure path naming its phase. `SMOKE_PKG` defaults to `praise`, which is not in the roster, so the install exercises a fresh bspm fetch. Phase 3 runs as the `rstudio` user with `HOME=/home/rstudio`, because CmdStan lives under that home and root finds nothing. `bash -n` and shellcheck are clean.
- 2026-09-11: criteria audit ([O], full mode) flagged the goal and all five drafted criteria. It found an unenumerable goal domain and a smoke test never wired per leg. It also found single-exemplar controls, an unreachable branch-run evidence state, digest count standing in for a passing smoke test, and a single-form manifest probe. All were fixed above before the gate. The GP4 tension went to the gate as a question.

## Decisions

## Review
