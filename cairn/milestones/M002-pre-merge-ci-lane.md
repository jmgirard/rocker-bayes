# M002: Pre-merge CI lane and lint

- **Status:** planned
- **Priority:** normal
- **Depends on:** M001
- **Driving RR:** —
- **Principles touched:** GP8
- **Resolves:** —
- **Surface tier:** internal. It is developer tooling, and nothing it produces
  is published.
- **Branch/PR:** —

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

- [ ] T1: Write `.github/workflows/pr-ci.yml` with the paths filter AC1
      names. Build noble amd64 with `load: true` and no registry login. Reuse
      the build cache scope that M001's publish lane writes.
- [ ] T2: Add the smoke-test step and the hadolint step to that lane. Give the
      smoke step a timeout that covers a cold CmdStan compile.
- [ ] T3: Write `.github/workflows/lint.yml`. Pin the shellcheck release by
      version and SHA256 rather than taking the runner's package. Follow
      `rstudio2u/.github/workflows/lint.yml:21-46`.
- [ ] T4: Add `.github/dependabot.yml` for the github-actions ecosystem on a
      monthly schedule. The current pins in `docker.yml` are several major
      versions behind, so the first batch of update pull requests is expected.
- [ ] T5: Run the planted-defect branches for AC3 and AC4 and record the red
      and green runs.
- [ ] T6: Note the pre-merge lane in the CI/publish family of
      `cairn/DESIGN.md`. Run the verify slot.

## Work log

- 2026-09-11: created by /milestone-plan.
- 2026-09-11: plan chose one amd64 noble build before merge over all four legs. Reason: the publish lane already boots all four, and a full matrix on every pull request costs minutes for little added signal. Falsified by a breakage that reaches the publish lane and that an arm64 or resolute pre-merge build catches first.
- 2026-09-11: plan chose Dependabot over a one-time hand bump of the pinned actions. Reason: the bumps recur, and the pins here are already several versions behind. Falsified by Dependabot pull requests going unreviewed and piling up.
- 2026-09-11: criteria audit ([O], reduced mode) flagged three drafted criteria. The no-push promise was unbounded. The trigger paths left out the lane's own scripts. The lint file list asserted only that it was non-empty. A fourth criterion bound a property of Dependabot's own status page rather than of this repo. The first three were reworded above and the fourth became a task with no criterion.

## Decisions

## Review
