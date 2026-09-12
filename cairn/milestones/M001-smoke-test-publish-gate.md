# M001: Smoke-test gate before any tag moves

- **Status:** review
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

- [x] AC1: Run against a freshly built rocker-bayes image,
      `bash .github/smoke-test.sh <image-ref>` exits 0 and prints one PASS line
      per phase. The container runs and reports healthy within
      `SMOKE_TIMEOUT`. An R package installs through bspm and `dpkg -s` shows
      the matching `r-cran-*` package. `library(cmdstanr)` reports a CmdStan
      path and version. A bundled Bernoulli model compiles and samples, and the
      posterior mean of `theta` lands within 0.05 of its analytic value.
- [x] AC2: The script exits non-zero and names the phase that failed for each
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
- [x] AC5: The publish job reads the assembled manifest list back before it
      attaches any tag, and fails unless the index names both `linux/amd64` and
      `linux/arm64`. The guard goes red on four bad indexes. One names amd64
      alone. One holds two entries of the same architecture. One holds amd64
      plus an attestation entry whose platform reads `unknown`. One has an
      empty `manifests` array.
- [x] AC6: `hadolint Dockerfile` reports no violations and `docker build`
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
- [x] T3: Run the pass case and the six controls of AC2 against a freshly
      built image. Record the FAIL line from each transcript.
- [x] T4: In `docker.yml`, remove the `refs/heads/main` guard on the digest
      push so every ref pushes an untagged image by digest. Add the pull-back
      step and the two architecture assertions to each leg.
- [x] T5: Add the smoke-test step to each leg, ordered before the digest
      upload, so a leg that fails contributes no digest.
- [x] T6: Replace the two per-variant merge jobs with one publish job gated on
      four digests. This is the all-or-nothing choice made at the 2026-09-11
      gate under GP4. Add the `test_mode` dispatch input and assemble every tag
      in a single `imagetools create`.
- [x] T7: Add the dry-run manifest read-back and the both-architectures
      assertion before the real create. Drive the four bad indexes from AC5.
- [x] T8: Update the CI/publish family and the Conventions in
      `cairn/DESIGN.md` to state the gate and the all-or-nothing publish rule.
      Run the verify slot.

## Work log

- 2026-09-11: created by /milestone-plan.
- 2026-09-11: gate chose all-four-legs-or-nothing publishing over per-variant independence. Reason: GP4 makes every leg a commitment. Falsified by evidence that one variant breaks often enough to cost users more than a stale tag.
- 2026-09-11: plan chose pushing untagged digests on every ref over the main-only push guard. Reason: AC4 and AC5 are unreachable off main otherwise. Falsified by untagged digests costing storage or becoming visible to users.
- 2026-09-11: plan chose a conjugate Bernoulli fixture over a richer model. Reason: a known answer keeps the sampling assertion stable. Falsified by the assertion proving flaky in CI at the stated tolerance.
- 2026-09-11: implement gate chose an extracted `.github/publish-guard.sh` with a local test over inline workflow shell. Reason: AC5's four bad indexes run locally in seconds instead of costing four-leg CI builds. Falsified by the script drifting from what the workflow actually calls.
- 2026-09-11: implement gate chose shipping the Stan fixture in the repo over baking it into the image. Reason: it is a CI artifact, and AC2 control (d) needs a second Stan file that no user needs.
- 2026-09-11: implement gate chose checking both variants' manifest lists before either variant's tags attach. Reason: the 2026-09-11 plan gate already made publishing all-or-nothing across the four legs under GP4.
- 2026-09-11: implement gate left `retry-on-failure` unchanged (the user expressed no preference, so the recommendation was taken). Reason: cached layers make a repeated smoke failure cheap, and the mirror flakiness the job exists for is unchanged.
- 2026-09-11: T1 added `.github/smoke-fixtures/` with `bernoulli.stan`, `bernoulli.data.json` (N=100, sum(y)=40, analytic posterior mean 41/102 = 0.4019608) and `does-not-compile.stan` for AC2 control (d).
- 2026-09-11: `hadolint Dockerfile` reported DL3025 on the pre-existing shell-form HEALTHCHECK. Rewrote it in exec form. hadolint is now clean. AC6 needs this.
- 2026-09-11: T2 wrote `.github/smoke-test.sh`. Three phases, each printing one PASS line and every failure path naming its phase. `SMOKE_PKG` defaults to `praise`, which is not in the roster, so the install exercises a fresh bspm fetch. Phase 3 runs as the `rstudio` user with `HOME=/home/rstudio`, because CmdStan lives under that home and root finds nothing. `bash -n` and shellcheck are clean.
- 2026-09-11: T4 and T5 rewrote the build legs in `docker.yml`. The matrix now carries `arch` rather than a platform string. Every ref pushes by digest. Each leg pulls that digest back and asserts both the recorded architecture and the container's `uname -m`. It then smoke-tests the image and only after that uploads its digest.
- 2026-09-11: T6 replaced the two per-variant merge jobs with one publish job for all four legs. It runs under `always()` so a run with a failed leg still reaches the digest guard and reports the shortfall. The `test_mode` dispatch input assembles and checks both manifest lists and attaches nothing.
- 2026-09-11: T7 added `.github/publish-guard.sh` (subcommands `digests` and `manifest`) and `.github/tests/test_publish_guard.sh`. The test drives 13 cases and all pass. It covers the four bad indexes AC5 names, plus a missing file, unreadable JSON, and four digest-count cases. Three cases are silent controls: a valid two-architecture index, one carrying an attestation entry, and a full set of four digests.
- 2026-09-11: T3 found that controls (d) and (e) printed the same phase 3 FAIL line. Phase 3 now prints a stage marker before it gives up. A compile failure, a sampling failure, and a wrong posterior mean each get their own FAIL line.
- 2026-09-11: T3 control (c) uses `SMOKE_PKG=oolong`. A diff of current CRAN against the r2u index inside the built image found 8 CRAN packages with no r2u binary (observed 2026-09-11). Of those, `oolong` installs from source and loads.
- 2026-09-11: T8 updated the DESIGN CI/publish family and added a Conventions bullet for the gate and the all-or-nothing publish rule. GP8's parenthetical said a CI smoke test was a candidate. It is corrected in place to name the gate.
- 2026-09-11: tasks were worked T1, T2, T7, T4 to T6, T8, then T3. T3 needs a locally built image, and that build ran for most of the session. No task content changed.
- 2026-09-11: T3 control (d) failed at the data-file check rather than the compile, because that check ran first. Compiling needs no data, so the compile now runs before it. Re-run in progress at this commit.
- 2026-09-11: T3 ran the AC1 pass case and the six AC2 controls against `rocker-bayes:dev`, built from this branch on arm64. Pass case exit 0 with three PASS lines, theta mean 0.3988 against reference 0.4020. Controls exit 1 with these lines. (a) `phase 1 (server up) - container exited before becoming healthy`. (b) `phase 1 (server up) - not healthy within 1s (last status: starting)`. (c) `phase 2 (bspm binary) - oolong did not install as an apt binary (r-cran-oolong absent)`. (d) `phase 3 (cmdstan) - does-not-compile.stan did not compile`. (e) `phase 3 (cmdstan) - the posterior mean is not within 0.05 of 0.9`. (f) `phase 3 (cmdstan) - cmdstanr is missing, or reports no CmdStan path or version`.
- 2026-09-11: T3 checked the failure identity behind each control, not the FAIL line alone. Control (d) failed on a stanc parse error at the `no_such_type` declaration. Control (f) failed because `cmdstanr` is not installed in the base image at all. The (f) message was widened to say so rather than claim a missing path.
- 2026-09-11: claim audit: 67 claims read, 4 corrected — .github/smoke-test.sh, .github/publish-guard.sh, .github/workflows/docker.yml
- 2026-09-11: the claim audit ([O], fresh context) found four comments describing behavior the code did not have. The digest guard named a failed leg on an over-count. A jq comment overstated what a non-index document does. The smoke test claimed every failure path prints a FAIL line, and a failed `docker run` printed none. A workflow comment claimed the publish job can see which legs produced a digest. All four are fixed and re-read by the same reader, which now marks each supported.
- 2026-09-12: review gathered fresh evidence for AC1, AC2, AC5 and AC6 and ticked those four. AC3 and AC4 stay unticked: each ends in a clause only a CI run can satisfy, and no CI run exists for this branch.
- 2026-09-12: review ran three fresh-context lenses. 29 findings reported, 0 meeting the return floor. 4 proposed fix-now, 11 proposed as candidate rows, the rest rejected with reason.
- 2026-09-12: gate took all four fix-now findings. F1 changed the publish job's `always()` to `!cancelled()`. F5 guarded the health-status read. F6 added `set -euo pipefail` and an empty check to the leg's CmdStan grep. F20 moved `SMOKE_PKG` out of interpolated R source.
- 2026-09-12: gate authorized pushing the branch and running CI to gather the AC3 and AC4 evidence, ahead of step 2's usual hold. The workflow's push filter is main-only, so the push starts nothing by itself.
- 2026-09-11: criteria audit ([O], full mode) flagged the goal and all five drafted criteria. It found an unenumerable goal domain and a smoke test never wired per leg. It also found single-exemplar controls, an unreachable branch-run evidence state, digest count standing in for a passing smoke test, and a single-form manifest probe. All were fixed above before the gate. The GP4 tension went to the gate as a question.

## Decisions

## Review

Evidence was gathered 2026-09-12 on the branch head `1aa991a`. The branch is in
sync with `origin/main`. The default branch did not move since the branch was
cut. The image under test is `rocker-bayes:review`. It was built on arm64 from
this branch with `docker build --no-cache`.

### Acceptance-criterion evidence

- **AC1 verified.** `bash .github/smoke-test.sh rocker-bayes:review` exited 0
  and printed three PASS lines. Phase 1 reported the container healthy. Phase 2
  installed `praise` and confirmed `r-cran-praise` through `dpkg -s`. Phase 3
  reported CmdStan path `/home/rstudio/.cmdstan/cmdstan-2.39.0` and version
  2.39.0. It then compiled and sampled the Bernoulli fixture to a posterior
  mean of 0.3988 against the reference 0.4020, inside the 0.05 tolerance. The
  reference was re-derived from the fixture data. 40 successes in 100 trials
  give a Beta(41, 61) posterior with mean 41/102 = 0.4019608.
- **AC2 verified.** All six controls exited 1 and named their phase. (a)
  `ubuntu:24.04` gave `phase 1 (server up) - container exited before becoming
  healthy`. (b) `SMOKE_TIMEOUT=1` gave `phase 1 (server up) - not healthy
  within 1s (last status: starting)`. (c) `SMOKE_PKG=oolong` gave `phase 2
  (bspm binary) - oolong did not install as an apt binary (r-cran-oolong
  absent)`. (d) `SMOKE_STAN_FILE=does-not-compile.stan` gave `phase 3 (cmdstan)
  - does-not-compile.stan did not compile`. (e) `SMOKE_THETA_REF=0.9` gave
  `phase 3 (cmdstan) - the posterior mean is not within 0.05 of 0.9`. (f)
  `jmgirard/rstudio2u:noble` gave `phase 3 (cmdstan) - cmdstanr is missing, or
  reports no CmdStan path or version`.
  The failure identity behind each line was checked, not the line alone.
  Control (c) printed `installing *source* package 'oolong'` and `DONE
  (oolong)`. So `library()` did succeed, and the `dpkg -s` assertion is what
  caught it. Control (d) failed on a stanc syntax error at the `no_such_type`
  declaration, not on a missing data file. Control (f) failed on `there is no
  package called 'cmdstanr'`. It passed phases 1 and 2 first, so it did not
  pass the CmdStan phase for the wrong reason.
- **AC5 verified.** In the `assemble` step, `.github/workflows/docker.yml`
  builds each variant's index with `imagetools create --dry-run` and writes it
  to a file. It then runs `publish-guard.sh manifest` on that file. The `Attach the
  tags` step runs the real `imagetools create` after that step, so the
  read-back comes before any tag. `bash .github/tests/test_publish_guard.sh`
  passed 14 of 14 cases. It refuses all four bad indexes AC5 names. Those are
  amd64 alone, two amd64 entries, amd64 plus an `unknown`-platform attestation
  entry, and an empty `manifests` array. Each case asserts on the guard's
  message, not on exit status alone. The suite also refuses a missing file,
  unreadable JSON, and a top-level array. Two silent controls prove the guard
  can still pass. Those are a real two-architecture index, and one carrying an
  attestation entry.
- **AC6 verified.** This is the `docker-image` profile's verify slot.
  `hadolint Dockerfile` exited 0 with no violations. `docker build --no-cache
  -t rocker-bayes:review .` succeeded from a clean context with exit 0. It
  ended `Successfully tagged rocker-bayes:review`.

### Consistency gate

- `cairn_validate.py` exited 0. Every check reported PASS and every advisory
  reported OK. `coverage complete` passed, so every criterion maps to an
  existing task.
- GP8's text changed in this milestone, so `cairn_impact.py --changed` ran. It
  listed 6 GP8 references and 7 GP4 references. This milestone rewrote the
  DESIGN Function Families and Conventions references. The M002 and M003 header
  declarations need no change. Removing GP8's "a CI smoke test is a ROADMAP
  candidate" parenthetical strengthens the principle those milestones build on.
  It does not change what they must satisfy.
- Toolchain checks came from the `docker-image` profile's consistency-gate
  slot. The build and hadolint results are the ones under AC6. The base image
  is pinned by an explicit tag, `FROM jmgirard/rstudio2u:${BASE_TAG}` with
  default `noble`, never `latest`. No secrets are baked into layers. The only
  `ENV` is `CMDSTAN_VERSION`, and `docker/login-action` consumes the Docker Hub
  token as a workflow secret rather than a build argument. `.dockerignore` is
  present and excludes `.git`, `.github`, and `cairn`. The changelog slot is
  `none`, so this milestone owes no changelog entry.

### AC3 and AC4: the parts that need a CI run

AC3 and AC4 each end in a clause that only a CI run can satisfy. AC3 wants one
run showing the assertion line and the smoke PASS on all four legs. It wants a
second run with one leg's expected architecture inverted, going red at the
assertion. AC4 wants a `test_mode` run with one leg's smoke test forced to
fail. That run must show the publish job erroring with no tag attached.

No CI run exists for this branch. `gh run list` shows runs on `main` and on the
old `rstudio2u-parity` branch only. The workflow's push filter is
`branches: [main]`, so pushing this branch starts nothing on its own. A
`workflow_dispatch` run is the only route, and that needs the branch pushed
first. `/milestone-review` step 2 holds the push until after the step-7
approval. Gathering this evidence is therefore a decision for the maintainer,
not something the review settles on its own.

The clauses of AC3 and AC4 that do not need CI were read against
`.github/workflows/docker.yml` and hold. Each leg pulls its pushed digest back,
asserts `{{.Architecture}}` against `matrix.arch`, and asserts the container's
`uname -m` against the matching value. The smoke-test step runs next, and the
two digest steps run after it, so a leg that fails contributes no digest. The
publish job runs `publish-guard.sh digests /tmp/digests/all 4` before anything
else. The local test suite shows that guard reporting `expected 4 verified
digests, found 3` on a short count. Both criteria stay unticked until the CI
evidence lands.

### Independent review

Three fresh-context reviewers ran against the branch diff. The blame-history
lens read the workflow's full history. The prior-review lens found no
prior-review evidence and contributed no findings. The archive holds no
milestones yet, and the GitHub inline-comment probe returned nothing.
The diff-bug lens reported 25 findings and the blame-history lens reported 4,
of which 3 were self-declared non-defects. Every finding and its disposition
follows.

**Fixed on the branch at the gate.** The maintainer took all four at the
2026-09-12 gate. None of them returns the milestone under the return floor,
because none demonstrates an acceptance criterion failing. After the fixes,
`bash -n`, shellcheck and actionlint are clean. The AC1 pass case still exits 0
with the same three PASS lines and the same theta mean of 0.3988. Control (c)
still fails phase 2 on the source-installed `oolong`, which is the
discriminating case for the phase-2 code that changed.

- F1: the publish job's `if` uses `always()`, which stays true when the run is
  cancelled. Four green legs followed by a cancel still attach every tag.
  Changed to `!cancelled()`.
- F5: `.github/smoke-test.sh:95` reads `.State.Health.Status` without the guard
  line 88 uses. Under `set -e` a container that disappears mid-poll aborts the
  script with no `FAIL:` line, which contradicts the header comment this branch
  added. Reproduced directly. Guarded the call as line 88 does.
- F6: the build leg's `Resolve CmdStan version` step lacks two guards. The
  publish job's copy of the same grep carries `set -euo pipefail` and an empty
  check. A reformatted `ARG` line therefore passes an empty override and burns
  four builds before the publish job catches it. Added both guards.
- F20: `SMOKE_PKG` is interpolated into R source unquoted, so a value holding a
  quote runs arbitrary R in the container. It now passes through the
  environment instead.

**Rejected, with reason.**

- F16, which blame lens item 2 also raises. The claim was that the exec-form
  HEALTHCHECK lets raw `wget` exit codes reach Docker, where 2 is reserved.
  Refuted against the implementation. A probe image carried the exec-form
  healthcheck against a dead port. `wget` exited 4, and Docker marked the
  container `unhealthy` after its retries. Docker treats non-zero codes alike.
- F4: the publish loop calls `imagetools create` once per variant, so a registry
  error between the two leaves one variant tagged. The DESIGN convention this
  branch adds says both lists are assembled and checked before either variant's
  tags attach, which is what the code does. Two registry calls cannot be made
  atomic, so this is inherent rather than introduced. Logged as a known issue.
- F10: the "every ref pushes by digest" comment is accurate about the push step,
  which no longer carries a branch guard. The trigger list is a separate fact.
- F19: the 0.05 theta tolerance is about one posterior standard deviation, and
  control (e) sits ten away. AC1 states 0.05, and the plan gate recorded
  flakiness as the reason. Tightening it at review reinterprets a criterion.
- F15, F17, F21, F22 and F24 are minor or cosmetic. `inputs.test_mode` works
  for every trigger this workflow has. A host port collision reports an image
  defect. A stray blank line prints. An empty log header prints when the
  container never started. The post-publish `imagetools inspect` prints its
  output without asserting on it.
- F25 and blame items 3 and 4: the matrix redesign justifies the cache-scope
  rename. The reviewer marked the other two as non-defects itself.

**Deferred to candidate rows.**

- F2: `retry-on-failure` now re-runs genuine smoke failures, and `no-cache` is
  true for `schedule`, so nothing restores from cache. A deterministic weekly
  failure rebuilds all four legs three times over. The work-log entry that left
  the job unchanged assumed cached layers make a rerun cheap. That premise does
  not hold for the scheduled run GP8 names.
- F3 and F12: phase 2 asserts that `library()` works and that `dpkg -s` finds
  the apt package. It never asserts that the package arrived during this run. A
  pre-installed `r-cran-praise` passes with bspm fully broken. The compile
  control fails at stanc parse time, so no control covers a broken C++
  toolchain.
- F7: digest files are named by digest alone and merged into one flat directory,
  so two legs building byte-identical images collapse to one file. The guard
  then blocks publishing with a message naming a cause that did not occur.
- F8: nothing runs `test_publish_guard.sh`, and `.github/tests/**` is absent
  from the push paths filter. This is the drift condition the implement gate
  recorded. It belongs to M002, which owns the pre-merge lane.
- F9: the push paths filter includes `.github/smoke-test.sh` and the fixtures,
  but `.dockerignore` excludes `.github` from the build context. A comment typo
  therefore rebuilds four legs and re-points `latest` at an identical image.
- F13: the manifest guard compares the architecture list against the exact
  string `amd64 arm64`. AC5 asks that the index name both. An index naming a
  third architecture as well satisfies AC5 and is still refused.
- F14: nothing asserts that a leg's digest was built from the base tag its
  variant claims. A matrix edit setting `base_tag: noble` on a resolute row
  passes every gate and ships noble bytes under the resolute tag.
- F18: phase 1 uses the container's own healthcheck, which requests
  `localhost:8787` from inside. The published host port is never touched on the
  path the real image takes.
- F23: the cleanup trap fires on EXIT only, so a cancelled run leaves the
  container holding the port.
- Blame item 1: every branch dispatch now pushes four untagged manifests to the
  production Docker Hub repository, and nothing prunes them. This is the storage
  cost the plan gate named as its own falsification condition.
