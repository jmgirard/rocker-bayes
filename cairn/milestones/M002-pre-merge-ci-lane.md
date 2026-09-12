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

- [ ] AC1: A pull request that touches `Dockerfile`, `scripts/**`,
      `.github/workflows/**`, or `.github/*.sh` runs a job that builds the
      noble amd64 image with `load: true` and then runs
      `.github/smoke-test.sh` against the loaded tag. A pull request run shows
      the build step and the smoke PASS lines.
- [ ] AC2: The pre-merge lane pushes nothing and reads no registry
      credential. A `grep` over `.github/workflows/pr-ci.yml` finds no login
      action, no `push=true`, and no `secrets.` reference, and the output of
      that `grep` is recorded.
- [ ] AC3: `hadolint Dockerfile` runs in the pre-merge lane. A branch that
      plants a violation turns the run red, and the same branch turns green
      once the violation is removed.
- [ ] AC4: The lint workflow builds its file list from one `git ls-files`
      call covering `*.sh` and `*.command`. An empty list fails the run. The
      workflow runs `shellcheck -x -S info` over the list. A branch that plants an unquoted
      variable in one `.sh` file and one `.command` file turns the run red,
      and the run names both files.
- [ ] AC5: `hadolint Dockerfile` reports no violations and `docker build`
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
