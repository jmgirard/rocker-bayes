# M002: Pre-merge CI lane and lint

- **Status:** review
- **Priority:** normal
- **Depends on:** M001
- **Driving RR:** —
- **Principles touched:** GP8
- **Resolves:** —
- **Surface tier:** internal. It is developer tooling, and nothing it produces
  is published.
- **Branch/PR:** `m002-pre-merge-ci-lane`

## Goal

A pull request builds the image, boots it, and lints the Dockerfile and the
shell files before anyone merges it.

## Scope

**In:** a new `.github/workflows/pr-ci.yml` that builds the noble amd64 image
locally and runs `.github/smoke-test.sh` against it. A new
`.github/workflows/lint.yml` that runs shellcheck over the tracked shell
files. A hadolint step in the pre-merge lane. A
`.github/dependabot.yml` for the github-actions ecosystem.

**Out:** the publish gate itself goes to M001. The unit-test suites and the
step that runs them go to M003. The arm64 and resolute legs stay unbuilt
before merge, because M001's publish lane boots all four.

## Acceptance criteria

- [x] AC1: A pull request that touches `Dockerfile`, `scripts/**`,
      `.github/workflows/**`, or `.github/*.sh` runs a job that builds the
      noble amd64 image with `load: true` and then runs
      `.github/smoke-test.sh` against the loaded tag. A pull request run shows
      the build step and the smoke PASS lines.
- [x] AC2: The pre-merge lane pushes nothing and reads no registry
      credential. A `grep` over `.github/workflows/pr-ci.yml` finds no login
      action, no `push=true`, and no `secrets.` reference, and the output of
      that `grep` is recorded.
- [x] AC3: `hadolint Dockerfile` runs in the pre-merge lane. A branch that
      plants a violation turns the run red, and the same branch turns green
      once the violation is removed.
- [x] AC4: The lint workflow builds its file list from one `git ls-files`
      call covering `*.sh` and `*.command`. An empty list fails the run. The
      workflow runs `shellcheck -x -S info` over the list. A branch that plants an unquoted
      variable in one `.sh` file and one `.command` file turns the run red,
      and the run names both files.
- [x] AC5: `hadolint Dockerfile` reports no violations and `docker build`
      succeeds from a clean context. This is the profile's verify slot.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T5
- AC3 → T2, T5
- AC4 → T3, T5
- AC5 → T6

## Tasks

- [x] T1: Write `.github/workflows/pr-ci.yml` with the paths filter AC1
      names. Build noble amd64 with `load: true` and no registry login. Reuse
      the build cache scope that M001's publish lane writes.
- [x] T2: Add the smoke-test step and the hadolint step to that lane. Give the
      smoke step a timeout that covers a cold CmdStan compile.
- [x] T3: Write `.github/workflows/lint.yml`. Pin the shellcheck release by
      version and SHA256 rather than taking the runner's package. Follow
      `rstudio2u/.github/workflows/lint.yml:21-46`. Also fix the one
      pre-existing SC2086 the pinned level reports, so the lane starts green.
- [x] T4: Add `.github/dependabot.yml` for the github-actions ecosystem on a
      monthly schedule. The current pins in `docker.yml` are several major
      versions behind, so the first batch of update pull requests is expected.
- [x] T5: Run the planted-defect branches for AC3 and AC4 and record the red
      and green runs.
- [x] T6: Note the pre-merge lane in the CI/publish family of
      `cairn/DESIGN.md`. Run the verify slot.

## Work log

- 2026-09-11: created by /milestone-plan.
- 2026-09-11: plan chose one amd64 noble build before merge over all four legs. Reason: the publish lane already boots all four, and a full matrix on every pull request costs minutes for little added signal. Falsified by a breakage that reaches the publish lane and that an arm64 or resolute pre-merge build catches first.
- 2026-09-11: plan chose Dependabot over a one-time hand bump of the pinned actions. Reason: the bumps recur, and the pins here are already several versions behind. Falsified by Dependabot pull requests going unreviewed and piling up.
- 2026-09-11: criteria audit ([O], reduced mode) flagged three drafted criteria. The no-push promise was unbounded. The trigger paths left out the lane's own scripts. The lint file list asserted only that it was non-empty. A fourth criterion bound a property of Dependabot's own status page rather than of this repo. The first three were reworded above and the fourth became a task with no criterion.

- 2026-09-12: gate chose fixing the pre-existing SC2086 in `scripts/install_bayes.sh` over a disable directive. Reason: AC4 fixes the level at `-S info`, and adding a linter implies making the tree pass it. The quoting bug is real for a version string carrying a space.
- 2026-09-12: gate chose pinning the new workflows at `docker.yml`'s existing action versions over current latest. Reason: one coherent Dependabot batch across all three workflows beats running two majors of the same action side by side.
- 2026-09-12: T1 wrote `.github/workflows/pr-ci.yml`. It takes no build args, because the Dockerfile already defaults `BASE_TAG` to noble and pins `CMDSTAN_VERSION`. It reads the `noble-amd64` cache scope and never writes it, so a pull request cannot poison the cache the publish lane builds from. actionlint clean, and the AC2 grep finds nothing.

- 2026-09-12: T2 added the hadolint step and the smoke step. hadolint runs before the build, so a lint violation reports in seconds rather than after a CmdStan compile. The job takes `timeout-minutes: 45`, which covers a cold compile when a Dockerfile change invalidates the cached layer. There is no hadolint pin in `docker.yml` to match, so the action takes the current v3.5.0, which is also what rstudio2u runs.
- 2026-09-12: AC1 asks for a pull request run showing the build step and the smoke PASS lines. This milestone's own pull request supplies it, because the paths filter includes `.github/workflows/**`. No early push is needed.

- 2026-09-12: T3 wrote `.github/workflows/lint.yml`. It enumerates once with `git ls-files -z` into a file and reads that file for both the count and the lint, because enumerating twice would let the two disagree. The shellcheck 0.11.0 tarball SHA256 was verified by downloading the release, not copied from rstudio2u.
- 2026-09-12: T3 fixed the SC2086 in `scripts/install_bayes.sh:73`. Verified by printing what the shell assembles: `version = "2.39.0",` for a normal value, and a value carrying spaces now stays one R string. `docker build` exit 0, hadolint exit 0, and the built image reports CmdStan 2.39.0 at `/home/rstudio/.cmdstan/cmdstan-2.39.0`. shellcheck over all nine tracked files now exits 0.
- 2026-09-12: T4 added `.github/dependabot.yml`. It groups every action into one pull request per run, so a batch of major bumps arrives as a single change the pre-merge lane builds and boots once. Parsed with PyYAML.

- 2026-09-12: T5 ran both controls as real pull requests, because both workflows trigger on `pull_request`. PR #4 planted an unquoted expansion in `start_linux.sh` and `start_mac.command`. Its shellcheck job failed in 5s with `linting 9 files`, then SC2086 at `start_linux.sh line 91` and `start_mac.command line 97`, exit 123. PR #5 planted DL3003 in the Dockerfile. Its lane failed in 7s at `Dockerfile:45 DL3003 warning: Use WORKDIR to switch to a directory`, before the build ran. Removing that violation on the same branch turned the lane green in 6m0s, with every step succeeding.
- 2026-09-12: the two controls cross-check each other. PR #5 touched only the Dockerfile and its shellcheck job passed, so the lint workflow is not failing everything it sees. PR #4 touched only shell files and its lane passed, so the hadolint step is not failing everything either.
- 2026-09-12: PR #4's lane supplied the AC1 evidence. It built and loaded noble amd64 and printed the three phase PASS lines plus the summary line, with theta 0.3988 against reference 0.4020, in 5m51s.
- 2026-09-12: both control branches and their pull requests are closed and deleted. Neither merged.

- 2026-09-12: T6 added the pre-merge lane to the DESIGN CI family and a Conventions bullet. hadolint exit 0, actionlint exit 0, shellcheck exit 0 over nine files, the M001 guard suite 14 of 14, and `cairn_validate` all passing.
- 2026-09-12: AC5 verified. `docker build --no-cache` exit 0 from a clean context, and the resulting image reports CmdStan 2.39.0. This is the second clean build of the edited `install_bayes.sh`, so the quoting fix holds with no cached layer behind it.
- 2026-09-12: claim audit: not owed — internal tier.
- 2026-09-12: all six tasks done and the verify slot clean. Status set to review.

- 2026-09-12: correction, superseding the 2026-09-12 cross-check line above. That line said PR #5 "touched only the Dockerfile" and PR #4 "touched only shell files". Both are false. Each control branch also carried the three new workflow files, and `git diff --name-only origin/main <sha>` confirms it. That is why `pr-ci.yml` triggered on both, through `.github/workflows/**`, rather than through the paths the line named. The conclusion stands: each linter passed on a branch where its own domain was clean, so neither fails everything. The `Dockerfile` and `scripts/**` trigger arms were never exercised in isolation.

## Decisions

## Review

Evidence gathered 2026-09-12 on branch `m002-pre-merge-ci-lane`, in sync with
`origin/main`. The default branch did not move since the branch was cut.

### Acceptance-criterion evidence

- **AC1 verified.** Run 34708307848, a pull request run, built and loaded noble
  amd64 and then ran the smoke test against the loaded tag. It printed one PASS line per phase in 5m51s. Phase 3 reported theta 0.3988
  against reference 0.4020. A fourth line read `PASS: smoke test (server up +
  bspm binary + cmdstan) succeeded`. The `Build noble
  (amd64) and load it` and `Smoke-test noble (amd64)` steps both report
  success. That pull request matched the trigger through `.github/workflows/**`.
- **AC2 verified.** The criterion asks that the grep output be recorded, so it
  is recorded here. Command:
  `grep -nE "login|push=true|secrets\." .github/workflows/pr-ci.yml`. Output:
  none. Exit status 1, which is the no-match status. Re-run after the
  review-side fixes with the same result. The file's only `uses:` lines are
  `actions/checkout@v4`, `hadolint/hadolint-action@v3.5.0`,
  `docker/setup-buildx-action@v3` and `docker/build-push-action@v6`, and the
  build step carries `load: true` with no `push` key.
- **AC3 verified.** On branch `m002-control-hadolint`, commit `cf0197bf42b2`
  planted `RUN cd /tmp` in the Dockerfile. Run 34708318148 failed in 7s at
  `Dockerfile:45 DL3003 warning: Use WORKDIR to switch to a directory`, before
  the build step ran. Commit `9d9ab9669a3c` on the same branch removed that
  line, and run 34708363848 passed in 6m0s with every step succeeding.
- **AC4 verified.** One `git ls-files -z '*.sh' '*.command'` call writes the
  list to a file. Both the count and the lint read that file. On branch `m002-control-shellcheck`, commit
  `b5c762351956` planted an unquoted expansion in `start_linux.sh` and in
  `start_mac.command`. Run 34708307885 failed in 5s. It printed `linting 9
  files`, then SC2086 at `In start_linux.sh line 91` and at `In
  start_mac.command line 97`, and exited 123. Both files are named, as the
  criterion requires. The empty-list branch was driven directly at review. An enumeration
  matching nothing exits 1 and prints `::error::no shell files enumerated, so
  shellcheck would have linted nothing`. It does not pass silently. On the clean tree the same command enumerates 9 files and exits 0,
  which is the silent control.
- **AC5 verified.** `hadolint Dockerfile` exit 0. `docker build --no-cache`
  from a clean context exit 0, ending `Successfully tagged
  rocker-bayes:m002review`, and the built image reports CmdStan 2.39.0.

**Provenance and one limitation.** The commits behind the AC1, AC3 and AC4 runs
were checked by command, not taken on trust. `9d9ab9669a3c` is byte-identical
to the branch across every file outside `cairn/`. `cf0197bf42b2` and
`b5c762351956` differ from it only by their planted defects, 3 lines in the
Dockerfile and 8 across the two launcher files. The limitation: the review-side
fixes below edited both workflow files after those runs. The edits are
additive. `git diff` against the run commits shows four things textually unchanged: the
hadolint step, the `git ls-files` enumeration, the `shellcheck -x -S info`
command, and the build and smoke steps. The recorded behavior is therefore
still this file's behavior. No run has yet exercised the edited files end to end. The pull
request opened for this milestone will run both lanes on the merging head.

### Consistency gate

- `cairn_validate.py` exit 0, every check PASS and every advisory OK.
- No `DESIGN.md` principle text changed in this milestone, so `cairn_impact.py`
  is not owed.
- Toolchain checks from the `docker-image` profile. Build and hadolint are the
  results under AC5. The base image is pinned by explicit tag, never `latest`.
  The only `ENV` is `CMDSTAN_VERSION`, and no credential is baked into a layer.
  `.dockerignore` is present and excludes `.git`, `.github` and `cairn`. The
  changelog slot is `none`. M001's `test_publish_guard.sh` still passes 14 of 14 on this branch.

### Independent review

Three fresh-context lenses ran against the branch diff. They reported 24
findings between them. None meets the return floor, because none demonstrates
an acceptance criterion failing.

**Fixed on the branch.**

- The pre-merge lane did not trigger on `.github/smoke-fixtures/**`, which
  `docker.yml` already watched. A pull request editing `bernoulli.data.json`
  moves the posterior mean the smoke test compares against. Such a pull
  request merged with no build at all. Added, along with `.dockerignore`, which defines the
  build context.
- Neither workflow declared `permissions:`. The lane runs the pull request's
  own copy of `.github/smoke-test.sh`, because `.github/*.sh` is a trigger
  path. The repository default is `read`, read from the API, so this was not a
  live hole. Both workflows now pin `contents: read` rather than resting on a
  setting.
- The smoke step had no timeout of its own, though T2 asked for one.
  `SMOKE_TIMEOUT` bounds phase 1 only. A wedged CmdStan compile therefore ran
  out the 45-minute job budget. It printed none of the `FAIL: phase 3` lines
  the script exists to emit. The step now takes `timeout-minutes: 25`.
- The build step lacked `pull: true`, which `docker.yml` sets deliberately.
  Without it the lane can certify an image built on a cached base while the
  publish build pulls a newer one. Added.
- `curl` lacked `--fail`. A renamed release asset therefore lands in the
  tarball and reports as a checksum mismatch, which reads like a wrong pin or
  tampering. Added, and the download moved to `RUNNER_TEMP` rather than the
  checked-out tree.
- The DESIGN Conventions bullet said every pull request is built and booted
  before merge. A pull request touching only the README or the compose file
  runs nothing. The bullet now names the trigger paths and says so.

**Corrected in the record.** The implement-phase cross-check work-log line
misstated why the control lanes ran. A superseding line above carries the
correction, and the conclusion it supported still stands.

**Rejected, with reason.**

- `branches: [main]` means a stacked pull request gets no checks. This matches
  `docker.yml` and is the repo's existing convention.
- Dependabot covering only `github-actions` is correct. GP2's weekly rebuild
  handles the base image and GP3 requires a hand bump for CmdStan.
- Two observations describe the design rather than a defect. One is
  `cache-from` without `cache-to`. The other is that a fork pull request gets
  an isolated cache namespace.
- The lint workflow's unguarded `n=$(tr ... | wc -c)` echoes a lesson M001
  wrote about command substitution under `set -e`. The inputs here are a file
  `git ls-files` just wrote, and the empty case was driven directly and fires
  the guard. Noted rather than changed.

**Deferred to candidate rows.**

- A `paths` filter plus a required status check leaves a README-only pull
  request waiting forever. Neither workflow runs in a merge queue.
- `CMDSTAN_VERSION` still reaches R source by interpolation, so a value
  carrying a double quote rewrites the call. `smoke-test.sh` states the
  opposite convention for this repo and passes its value through the
  environment.
- The lint pathspec covers `*.sh` and `*.command` only. An extensionless
  script or a `.bash` file is never linted, and the count still reads 9.
- Neither workflow sets a `concurrency` group, so three pushes in five minutes
  start three full builds and none is cancelled.
- `.github/workflows/**` triggers a full noble build on any workflow edit,
  including a comment-only change to the publish lane.
- `.github/dependabot.yml` matches no trigger path and is schema-validated by
  nothing, so an error surfaces only on the Dependabot page.
