<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M015: Smoke a threaded CmdStan build in CI

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4, GP8
- **Resolves:** —
- **Surface tier:** internal — a CI smoke check; the image's contents do not change
- **Branch/PR:** m015-threaded-cmdstan-smoke

## Goal

Smoke phase 3 fails when the `rstudio` user cannot run a threaded CmdStan build.

## Scope

**In:** `.github/smoke-test.sh` phase 3 builds the bundled fixture a second
time with `stan_threads` on, as `rstudio`, after the existing unthreaded run,
and samples it with 2 threads per chain. A failed threaded build and a failed
threaded sample each get their own FAIL line. The script's header and
`cairn/DESIGN.md`'s CI / publish bullet describe the new step. A one-time local
control proves the step goes red when `/opt/cmdstan` loses its group write bit.

**Out:**
- Running the planted no-group-write control in CI on every pull request: a
  one-time local control, as M007 did. A CI control would join the parked row
  "Run the broken compiler control in CI".
- Testing a second user made through `USERID`: that user writes through the
  same `staff` group as `rstudio`. M010 checked it by hand.
- Comparing the CmdStan version with the tag: stays the candidate row "Check
  CmdStan matches the version tag".
- Making files a session writes into `/opt/cmdstan` writable to other users:
  stays the parked row "Keep CmdStan runtime files writable".
- Matching stage markers as whole lines: stays the parked row "Anchor smoke
  stage markers to lines". The new markers are chosen so that no marker is a
  substring of another.

## Acceptance criteria

- [ ] AC1: A run of `.github/smoke-test.sh` against an image built from the
      branch (`docker build -t rocker-bayes:dev .`) exits 0, and its phase 3
      output shows, after the existing unthreaded run, a build with
      `stan_threads` on as the `rstudio` user that wrote
      `src/cmdstan/main_threads.o` under `cmdstan_path()` and then sampled
      with `threads_per_chain = 2`.
- [ ] AC2: Against an image built `FROM rocker-bayes:dev` with
      `RUN chmod -R g-w /opt/cmdstan`, the script exits non-zero, its FAIL
      line is the new phase 3 threaded-build line rather than the existing
      "passed stanc but the C++ build failed" line, and the output above it
      shows a permission error on `main_threads.o`.
- [ ] AC3: A `docker.yml` dispatch on the branch with `test_mode=true` passes
      the smoke step on all four legs (noble and resolute, each on amd64 and
      arm64), and each leg's smoke log shows the threaded build's output from
      AC1.
- [ ] AC4: The phase 3 description in the header comment of
      `.github/smoke-test.sh` and the CI / publish bullet of `cairn/DESIGN.md`
      each say that phase 3 also builds and samples a threaded model as
      `rstudio`, and that this build fails when `rstudio` cannot write
      `main_threads.o` into the CmdStan tree.
- [ ] AC5: The profile's verify slot is clean: `hadolint Dockerfile` reports
      nothing and `docker build` succeeds; shellcheck at the version
      `.github/workflows/lint.yml` pins reports nothing on
      `.github/smoke-test.sh`.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T3
- AC3 → T5
- AC4 → T4
- AC5 → T2, T6

## Tasks

- [x] T1: In `.github/smoke-test.sh` phase 3 (lines 234-341), after the mean
      check, copy the fixture into a second work directory and build it with
      `cpp_options = list(stan_threads = TRUE)`. Record whether
      `file.path(cmdstan_path(), "src/cmdstan/main_threads.o")` exists before
      the build and after it. Print that the build wrote the file when it was
      absent before and present after, print that the file was already
      present when it was, and fail the build stage when it is absent after.
      Sample with `threads_per_chain = 2`. Give the build and the sample their
      own stage markers, none a substring of another marker, and their own
      FAIL lines in the `case`. Print make's `stderr` on a build failure as
      the `stage:cxx` handler does. No apostrophes in the R comments (M007
      lesson). Update the PASS line.
- [x] T2: Build `rocker-bayes:dev` from the branch and run the script against
      it. Record the phase 3 lines that AC1 names in the work log.
- [ ] T3: Build a throwaway image `FROM rocker-bayes:dev` with
      `RUN chmod -R g-w /opt/cmdstan`, run the script against it, and record
      the FAIL line and the permission error line. Remove the throwaway tag
      afterward.
- [ ] T4: Update the phase 3 text in the script's header comment and the
      "Its CmdStan phase" sentence of `cairn/DESIGN.md`'s CI / publish bullet,
      written from the T2 and T3 output.
- [ ] T5: Push the branch and dispatch `docker.yml` on it with
      `test_mode=true`. Record the run URL and each leg's threaded output
      line. Compare each leg's smoke step time with the last green scheduled
      run and log the difference.
- [ ] T6: Run `hadolint` and shellcheck 0.11.0 in containers against files in
      the checkout (M002 lesson on Docker Desktop mounts), and `docker build`.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: not run — work named at the question set.
- 2026-11-05: idea vet: one gap, no flaw. Gap: the row does not say whether to test a `USERID` user too; reading taken: `rstudio` only, since both write through the `staff` group and CI output is the same either way.
- 2026-11-05: lessons used: 2026-10-20 (M007) apostrophes in `Rscript -e` R comments; 2026-10-20 (M007) cmdstanr keeps make's stderr in `e[["stderr"]]`; 2026-09-12 (M002) run containerized linters on files in the checkout; 2026-09-12 (M001) branch evidence for docker.yml needs a `test_mode` dispatch.
- 2026-11-05: question set: work to plan — "Smoke a threaded CmdStan build in CI"; may the milestone dispatch docker.yml on its branch — yes, with `test_mode=true` only (pushes untagged manifests, attaches no tag).
- 2026-11-05: collision check: absorbs the candidate row "Smoke a threaded CmdStan build in CI". Related rows stay apart: "Check CmdStan matches the version tag", "Keep CmdStan runtime files writable", "Anchor smoke stage markers to lines", "Run the broken compiler control in CI". No D-entry overlaps. Inbox sweep: 0 open issues, 0 open PRs.
- 2026-11-05: plan check: with `chmod -R g-w /opt/cmdstan` on `rocker-bayes:dev`, an unthreaded build of the fixture as `rstudio` passed and a threaded one failed with "can't create src/cmdstan/main_threads.o: Permission denied", so AC2's order holds.
- 2026-11-05: criteria audit (reduced mode, fresh Opus reader): no findings on the bounded-promise, proportionality, or instrument questions. It noted that the unthreaded build might fail first under AC2's plant; the plan check above settled that it does not.
- 2026-11-05: plan gate chose a one-time local control over a CI step that builds the plant image on every pull request because M007 took the same route and a CI plant adds an image build per run; falsified by a smoke-test change that breaks the threaded FAIL line and ships unnoticed.
- 2026-11-05: plan gate chose a second build inside phase 3 over a new phase 5 because the threaded build reuses phase 3's container, fixture, and stage markers; falsified by a phase 3 failure line that cannot tell the threaded build from the unthreaded one.
- 2026-11-05: changelog: none (the profile's changelog slot is none, and this milestone changes no image content).
- 2026-11-05: T1: phase 3 builds a second copy of the fixture with `stan_threads` on and samples 1 chain with `threads_per_chain = 2`, 200+200 iterations; new markers `stage:thread-build` and `stage:thread-sample`; the sample stage also fails on a nonzero chain return code; shellcheck 0.11.0 clean. Chose 1 short chain because the unthreaded run already checks the posterior mean.
- 2026-11-05: T2: `docker build -t rocker-bayes:dev .` (image f34ae1ea, arm64) then the script exited 0 with all four PASS lines; phase 3 printed "theta posterior mean 0.3988", then "threaded build: wrote /opt/cmdstan/cmdstan-2.40.0/src/cmdstan/main_threads.o", then "threaded sample: 1 chain, threads_per_chain = 2".

## Decisions

## Review
