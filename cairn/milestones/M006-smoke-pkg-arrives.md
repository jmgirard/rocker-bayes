# M006: Assert smoke packages arrive this run

- **Status:** in-progress
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP8
- **Resolves:** —
- **Surface tier:** internal — a CI check over the built image that no user of the image runs
- **Branch/PR:** m006-smoke-pkg-arrives

## Goal

Smoke phase 2 passes only when the probe package was absent from the image before bspm installed it.

## Scope

**In:** two absence checks in phase 2 of `.github/smoke-test.sh`, run before the
install: a `dpkg -s r-cran-<pkg>` read and a `find.package()` read in the root R
session that runs the install. A new phase 2 FAIL line names which check found
the package. The header comment and the phase 2 PASS line say what phase 2 now
asserts. The DESIGN.md CI / publish bullet says the same in one clause. A probe
package already in the image fails the run. There is no fallback list.

**Out:** a broken C++ toolchain control in smoke (its own candidate row). A host
port probe in phase 1 and smoke container cleanup on cancel (their own candidate
rows). A `SMOKE_PKG` input in the workflows (not needed: the controls run
locally).

## Acceptance criteria

- [ ] AC1: Before phase 2 of `.github/smoke-test.sh` installs `SMOKE_PKG`, it
      runs two absence checks: `dpkg -s r-cran-<pkg>` reports no installed
      entry, and `find.package()` returns no path across `.libPaths()` in the
      same root Rscript session that runs the install. When either check finds
      the package, the script exits 1 with a FAIL line that names phase 2, says
      the package was already in the image, and names which check found it.
      That line differs from the two existing phase 2 FAIL lines.
- [ ] AC2: Against an image built from this branch, a run with `SMOKE_PKG`
      unset exits 0 with the three phase PASS lines, and its phase 2 PASS line
      says `praise` was absent from the image before the install.
- [ ] AC3: Against the same image, a `SMOKE_PKG` that `dpkg -s` shows installed
      exits 1 with the AC1 FAIL line naming the dpkg check. A `SMOKE_PKG` that
      `installed.packages()` lists but `dpkg -l 'r-cran-*'` does not exits 1
      with the AC1 FAIL line naming the R library check.
- [ ] AC4: Against the same image, `SMOKE_PKG=oolong` (absent from the image,
      no r2u binary) passes the AC1 absence checks and then exits 1 with the
      existing "did not install as an apt binary" FAIL line.
- [ ] AC5: The `verify` slot is clean: `hadolint Dockerfile` reports nothing,
      the branch image builds, and shellcheck 0.11.0 at `-S info` reports
      nothing on `.github/smoke-test.sh`.

## Coverage

- AC1 → T1, T3
- AC2 → T2, T3
- AC3 → T2, T3
- AC4 → T3
- AC5 → T1, T2

## Tasks

- [ ] T1: In `.github/smoke-test.sh` phase 2, add the dpkg absence read before
      the install, guarded so a failing read cannot end the script under
      `set -e` before its FAIL line prints. Add the `find.package()` check at
      the top of the existing root Rscript block, with a stage marker so the
      shell prints a FAIL line distinct from the install failure line. Update
      the header comment and the PASS line. Run shellcheck 0.11.0 at `-S info`
      in a container against the file inside the repo checkout (no local
      shellcheck; Docker Desktop does not share the scratchpad). Run the script
      under macOS bash 3.2 as well as bash 5 where the two differ.
- [ ] T2: Start Docker Desktop, run `hadolint Dockerfile` in a container, and
      build `rocker-bayes:dev` from the branch (arm64). In that image, compare
      `installed.packages()` with `dpkg -l 'r-cran-*'`. Planned controls:
      `brms` for the dpkg case and `cmdstanr` for the R library case. If a read
      shows either is not of its kind, pick a package of that kind from the
      comparison and log the swap. If `praise` is already in the image, change
      the default probe to an absent package with an r2u binary and log it.
- [ ] T3: Run the AC2 default case and the AC3 and AC4 controls against
      `rocker-bayes:dev`. Log each exit status and FAIL or PASS line, and check
      each failure's identity (which check fired), not the line alone.
- [ ] T4: Update the DESIGN.md CI / publish bullet in one clause to say phase 2
      asserts the probe package was absent before the install.

## Work log

- 2026-10-20: created by /milestone-plan.
- 2026-10-20: tier check: milestone — a change to running CI code with a design decision (fail or fall back when the probe is present).
- 2026-10-20: absorbed candidate row "Assert smoke packages arrive this run" (M001 review F3, F12, split 2026-10-20). Collision sweep: M001 shipped phase 2 (archive), no D-entry overlaps, sibling smoke rows stay separate. Inbox: 0 open issues, 0 open PRs.
- 2026-10-20: checker-regress shape judged not to fire: the smoke test checks the built image, the repo's external deliverable, not a repo-internal artifact.
- 2026-10-20: lessons surfaced: the praise/oolong probe pair, guarded reads under `set -e`, macOS bash 3.2 vs bash 5, Docker Desktop not sharing the scratchpad.
- 2026-10-20: criteria audit (reduced mode, fresh Opus reader) returned 3 findings, all fixed by narrowing: AC1 R check scoped to the root session's `.libPaths()`; AC3 restated as script behavior per kind of present package, with the brms and cmdstanr picks moved to T2; AC4 limited to the oolong run. AC5 added after the audit as the profile's verify slot; its promise covers two named files, so the three reduced-audit questions find nothing.
- 2026-10-20: question set: probe already in the image — fail the run, no fallback list.
- 2026-10-20: question set: verification — local arm64 build with Docker Desktop on this Mac, granted.
- 2026-10-20: plan gate chose failing the run over a fallback probe list because a fallback hides the case it exists to catch and adds parsing; falsified by roster churn making the default probe present more than once a year.
- 2026-10-20: plan gate chose local control runs over CI control branches because the workflows pass no `SMOKE_PKG` and each CI control costs a build; falsified by a control that passes locally and fails on amd64 CI.
- 2026-10-20: no release notes: a CI-only change with no recipe change gets no release under D-002.
- 2026-10-20: implement started; branch m006-smoke-pkg-arrives cut from main at eeeab0d. Docker Desktop started; `rocker-bayes:dev` build running in the background.
- 2026-10-20: T1 choice: the R library check signals through Rscript exit status 3 rather than a stdout stage marker, so install output still streams live; the dpkg check counts only a `Status: install ok installed` line.
- 2026-10-20: question set (implement stop): download koalaman/shellcheck:v0.11.0 and hadolint/hadolint:v2.12.0 for local lint — granted.
- 2026-10-20: T1 checkpoint: absence checks, new FAIL lines, header comment, and PASS line in `.github/smoke-test.sh`. shellcheck 0.11.0 `-S info` exit 0, hadolint exit 0, `bash -n` clean. The bash 3.2 and bash 5 runs wait for the image (T3); T1 stays open until then.

## Decisions

## Review
