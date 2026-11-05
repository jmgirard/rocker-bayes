<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M015: Smoke a threaded CmdStan build in CI

- **Status:** review
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

- [x] AC1: A run of `.github/smoke-test.sh` against an image built from the
      branch (`docker build -t rocker-bayes:dev .`) exits 0, and its phase 3
      output shows, after the existing unthreaded run, a build with
      `stan_threads` on as the `rstudio` user that wrote
      `src/cmdstan/main_threads.o` under `cmdstan_path()` and then sampled
      with `threads_per_chain = 2`.
- [x] AC2: Against an image built `FROM rocker-bayes:dev` with
      `RUN chmod -R g-w /opt/cmdstan`, the script exits non-zero, its FAIL
      line is the new phase 3 threaded-build line rather than the existing
      "passed stanc but the C++ build failed" line, and the output above it
      shows a permission error on `main_threads.o`.
- [x] AC3: A `docker.yml` dispatch on the branch with `test_mode=true` passes
      the smoke step on all four legs (noble and resolute, each on amd64 and
      arm64), and each leg's smoke log shows the threaded build's output from
      AC1.
- [x] AC4: The phase 3 description in the header comment of
      `.github/smoke-test.sh` and the CI / publish bullet of `cairn/DESIGN.md`
      each say that phase 3 also builds and samples a threaded model as
      `rstudio`, and that this build fails when `rstudio` cannot write
      `main_threads.o` into the CmdStan tree.
- [x] AC5: The profile's verify slot is clean: `hadolint Dockerfile` reports
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
- [x] T3: Build a throwaway image `FROM rocker-bayes:dev` with
      `RUN chmod -R g-w /opt/cmdstan`, run the script against it, and record
      the FAIL line and the permission error line. Remove the throwaway tag
      afterward.
- [x] T4: Update the phase 3 text in the script's header comment and the
      "Its CmdStan phase" sentence of `cairn/DESIGN.md`'s CI / publish bullet,
      written from the T2 and T3 output.
- [x] T5: Push the branch and dispatch `docker.yml` on it with
      `test_mode=true`. Record the run URL and each leg's threaded output
      line. Compare each leg's smoke step time with the last green scheduled
      run and log the difference.
- [x] T6: Run `hadolint` and shellcheck 0.11.0 in containers against files in
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
- 2026-11-05: T3: image `FROM rocker-bayes:dev` + `RUN chmod -R g-w /opt/cmdstan`: exit 1, the unthreaded run passed (theta 0.3988), then make printed "Fatal error: can't create src/cmdstan/main_threads.o: Permission denied" and the FAIL line was the new threaded-build line. The log also showed a denied write under `model_header.hpp.gch`, so the FAIL line and comment now name the precompiled header too, and the control was rerun on that text with the same result. Throwaway tag removed. The passing path did not change, so T2 was not rerun.
- 2026-11-05: T4: the script header's phase 3 entry and DESIGN.md's "Its CmdStan phase" sentence now say that phase 3 builds and samples a threaded model as `rstudio` and that the build fails when `rstudio` cannot write `main_threads.o` into the CmdStan tree, as T2 and T3 showed.
- 2026-11-05: T5: docker.yml dispatch with `test_mode=true` at df22016, https://github.com/jmgirard/rocker-bayes/actions/runs/42115360063, concluded success; each of the four legs logged "threaded build: wrote /opt/cmdstan/cmdstan-2.40.0/src/cmdstan/main_threads.o", "threaded sample: 1 chain, threads_per_chain = 2", and the phase 3 PASS line. Smoke step times against scheduled run 41486476474: noble amd64 2:33 (was 0:41), noble arm64 2:38 (0:44), resolute amd64 2:05 (0:42), resolute arm64 2:35 (0:59), about 1.5 to 2 minutes more per leg; docker.yml sets no step timeout and pr-ci.yml's smoke step allows 25 minutes.
- 2026-11-05: T6: `hadolint` (container, Dockerfile unchanged) and shellcheck 0.11.0 (the version lint.yml pins) report nothing; `docker build -t rocker-bayes:dev .` succeeded at T2.
- 2026-11-05: claim audit: not owed — internal tier.
- 2026-11-05: step-7 approval: m015-threaded-cmdstan-smoke approved for merge

## Decisions

## Review

Pass 1, 2026-11-05, branch head 243eca2, no PR yet, Copilot round off.

- AC1: `docker build -t rocker-bayes:dev .` at 243eca2 (arm64, image c9b015572be6), then `SMOKE_PORT=18787 bash .github/smoke-test.sh rocker-bayes:dev` exited 0 with all four PASS lines. Phase 3 printed "theta posterior mean 0.3988" and then "threaded build: wrote /opt/cmdstan/cmdstan-2.40.0/src/cmdstan/main_threads.o" and "threaded sample: 1 chain, threads_per_chain = 2". The script runs phase 3 with `docker exec -u rstudio`.
- AC2: an image from `FROM rocker-bayes:dev` + `RUN chmod -R g-w /opt/cmdstan` (df091536b12c): the script exited 1. The unthreaded run passed (theta 0.3988), make printed "Fatal error: can't create src/cmdstan/main_threads.o: Permission denied", and the FAIL line was "phase 3 (cmdstan) - the threaded build of bernoulli.stan failed; …", not the "passed stanc but the C++ build failed" line. Throwaway tag removed.
- AC3: `gh run view 42115360063` reads success, event workflow_dispatch, head df22016; `git diff --quiet df22016 HEAD -- . ':!cairn'` shows no code change since. The publish job ran on a branch ref, which its `if:` admits only with `inputs.test_mode`, and its fresh check read stale, so no tag was attached. Each of the four build legs (noble and resolute, amd64 and arm64) passed its smoke step and logged the two threaded lines from AC1 and the phase 3 PASS line.
- AC4: `.github/smoke-test.sh` lines 15-19 say that a second build with stan_threads on, as rstudio, compiles and samples with 2 threads per chain, writes main_threads.o into the CmdStan tree, and fails when rstudio cannot write there. `cairn/DESIGN.md` lines 62-64 say the same of the CI / publish bullet's CmdStan phase.
- AC5: `hadolint` (container, stdin Dockerfile) printed nothing; shellcheck 0.11.0 (the `SHELLCHECK_VERSION` in lint.yml) printed nothing on `.github/smoke-test.sh`; `docker build -t rocker-bayes:dev .` succeeded under AC1.
- Gate: `cairn_validate.py` all checks passed. No IP/GP text changed, so `cairn_impact` was skipped. Profile gate: build and hadolint as under AC1 and AC5; the Dockerfile is unchanged, with base `jmgirard/rstudio2u:${BASE_TAG}` (default `noble`, an explicit tag), no secret added, and `.dockerignore` present; changelog slot is none, and the diff changes no image content.
- spawned: diff-bug, blame-history, prior-review, ripple
- diff-bug #1: the threaded sample prints `threads_per_chain` but never asserts it, and cmdstanr runs an unthreaded executable with one thread and only a warning — fix now, fixed 7ebff97 (stage:thread-sample now fails unless the recorded value is 2; a one-off unthreaded build sampled with `threads_per_chain = 2` recorded 1)
- diff-bug #2: when `main_threads.o` already exists the check passes with a note, while the header and DESIGN.md say the build always fails on a read-only tree — fix now, fixed 7ebff97 (both now say the image ships no `main_threads.o`, which is the condition the check rests on)
- diff-bug #3: the copy and model creation sit inside the build stage and `file.copy`'s result is ignored, against the file's own convention — fix now, fixed 7ebff97 (copy checked; model created with `compile = FALSE` outside the stage; `$compile(cpp_options = list(stan_threads = TRUE))` is the stage)
- diff-bug #4: the threaded-build FAIL line blames write permission for any threaded build failure — fix now, fixed 7ebff97 (the permission line prints only when the output holds "Permission denied"; any other threaded build failure gets "the threaded build of <file> failed")
- diff-bug #5: a threaded sample that fails at run time leaves no CmdStan output in the log, since sampling uses `show_messages = FALSE` — follow-up, parked row "Show sampler output when smoke fails" (the unthreaded sample has the same gap, and no failure has needed it)
- diff-bug #6: an error from `metadata()`, `return_codes()`, or the setup calls after the mean check takes the "before it reached a stage marker" line — reject (edge: only a cmdstanr API change or a malformed CSV reaches it, outside documented and common use; the run still fails)
- diff-bug #7: the return-code check can hardly fire with one chain — reject (style: a harmless guard with no wrong result)
- diff-bug #8: "samples with 2 threads per chain" suggests parallel work, but the fixture has no `reduce_sum` — fix now, fixed 7ebff97 (header says no work runs in parallel)
- diff-bug #9: docker.yml's smoke step has no `timeout-minutes`, and the change adds a second compile and chain per leg — follow-up, parked row "Bound the docker.yml smoke step time" (pre-existing; no step has hung)
- diff-bug #10: the new markers join the unanchored `case` match — follow-up, absorbed by the parked row "Anchor smoke stage markers to lines"
- diff-bug #11: one comment line runs past 80 characters — reject (style); the fix rewrapped it
- diff-bug #12, #13: no apostrophes in the R block; no test out of scope — noted
- blame-history #1: same as diff-bug #4, against M007's split FAIL lines — fix now, fixed 7ebff97 (as diff-bug #4)
- blame-history #2: the threaded run checks no posterior mean — reject (planned change: Scope In says the threaded build samples with 2 threads per chain; the mean check stays on the unthreaded run)
- blame-history #3: the threaded build has no separate stanc stage — reject (false: the same program passed `check_syntax()` earlier in the run, so stanc cannot fail here)
- blame-history #4: "(M015)" in DESIGN.md goes against its no-status rule — reject (false: DESIGN.md already cites milestones, such as "corrected M001")
- blame-history #5: same as diff-bug #10 — follow-up, the same parked row
- blame-history #6: same as diff-bug #11 — reject (style)
- blame-history #7: the build writes into the M010 tree — reject (false: the reviewer finds no conflict; the tree is group-writable by design)
- prior-review #1: same as diff-bug #4 — fix now, fixed 7ebff97 (as diff-bug #4)
- prior-review #2: same as diff-bug #10 — follow-up, the same parked row
- prior-review #3: same as diff-bug #2 — fix now, fixed 7ebff97 (as diff-bug #2)
- prior-review #4: same as blame-history #4 — reject (false)
- prior-review #5: the parked row "Keep CmdStan runtime files writable" may now fire through CI — reject (false: that row is about a second user rewriting files a first user wrote; CI builds once as one user on a fresh tree)
- ripple #1: the candidate row "Smoke a threaded CmdStan build in CI" still sits in the backlog — reject (false: post-merge hygiene graduates it)
- ripple #2: the parked marker row does not count the new markers — reject (false: the row names no count, and its mechanism covers them)
- ripple #3, #5: the parked rows on the broken-compiler control and runtime files do not mention M015 — reject (false: the reviewer finds no disagreement)
- ripple #4: GP8 under-describes the gate — reject (false: it is still true as written)
- ripple #6: the FAIL line and comment named a precompiled header that the header and DESIGN.md did not — fix now, fixed 7ebff97 (the FAIL line and comment no longer name it)
- Re-verification after 7ebff97 (code changed, so AC1, AC2, AC5 were rerun and AC3 is a new run): AC1 rerun on rocker-bayes:dev exited 0 with all four PASS lines, "threaded build: wrote /opt/cmdstan/cmdstan-2.40.0/src/cmdstan/main_threads.o" and "threaded sample: 1 chain, threads_per_chain = 2" after "theta posterior mean 0.3988". AC2 rerun on the no-group-write image exited 1 with "can't create src/cmdstan/main_threads.o: Permission denied" and the FAIL line "the threaded build of bernoulli.stan could not write into the CmdStan tree (Permission denied above); check that the rstudio user can write there". AC4 text re-read at 7ebff97: the header (lines 15-21) and DESIGN.md (lines 62-64) say that phase 3 builds and samples a threaded model as rstudio and that the build fails when rstudio cannot write main_threads.o into the tree. AC5: shellcheck 0.11.0 printed nothing; the Dockerfile is unchanged since the hadolint run above.
- AC3 after 7ebff97: https://github.com/jmgirard/rocker-bayes/actions/runs/42118932490, workflow_dispatch at 7ebff97 with test_mode=true, concluded success; all four build legs passed and each logged "threaded build: wrote …/main_threads.o", "threaded sample: 1 chain, threads_per_chain = 2", and the phase 3 PASS line; publish ran on the branch ref (admitted only by test_mode) and attached nothing. No code change between 7ebff97 and the review head.
