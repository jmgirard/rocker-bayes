# M004: Rerun a weekly build that failed on the r2u mirror

- **Status:** review
- **Priority:** high
- **Depends on:** M003
- **Driving RR:** —
- **Principles touched:** GP4, GP8
- **Resolves:** —
- **Surface tier:** user-facing — it decides whether the moving tags get the
  weekly rebuild when a mirror blip fails one leg.
- **Branch/PR:** m004-weekly-leg-retry

## Goal

A scheduled rebuild reruns its failed jobs once, unattended, when its first
attempt failed only because a build leg could not reach the r2u mirror.

## Scope

**In:** `.github/retry-decision.sh`, which holds the rerun rule and makes the
`gh run rerun` call. Its offline suite, `.github/tests/test_retry_decision.sh`.
A `.github/workflows/rebuild-retry.yml` that `workflow_run` starts when
`docker.yml` completes. The suite added to the `script-tests` job in
`pr-ci.yml`. A branch drill that proves a failed-jobs rerun reassembles
cleanly. The retry comment in `scripts/install_bayes.sh`, the `notify` comment
in `docker.yml`, and DESIGN.md, brought in line with the retry.

**Out:** Proof that the live `workflow_run` trigger fires. Only a merged
workflow can give it, so it goes to a candidate row added with this plan.
Retries for pushes to main, dispatches, and non-mirror failures are not
wanted (plan gate 2026-09-13). Holding the ci-failure issue back while a rerun
is pending is not wanted (plan gate). Quiet alert failures and the dispatch
side effects of `notify` stay in their existing candidate rows.

## Acceptance criteria

- [x] AC1: `.github/tests/test_retry_decision.sh` shows
      `.github/retry-decision.sh` returning a rerun decision when six
      conditions hold. (1) The run's event is `schedule`. (2) Its attempt is 1.
      (3) Its conclusion is `failure`. (4) At least one build leg failed.
      (5) Every failed build leg failed at its
      `Build <variant> (<arch>) and push by digest` step, and that leg's log
      contains `Command still failing after`. (6) Every other failed job is
      `publish`, failing at its `Require all four verified digests` step and
      at no other step. The suite shows the rerun decision for one qualifying
      leg of each of the four legs, and for two qualifying legs. The suite
      shows the no-rerun decision, with the broken condition named in the
      output, for each of these inputs: a `push` event, attempt 2, the run
      conclusions `success`, `cancelled`, and `timed_out`, a listing with no
      failed job, and a build leg whose own conclusion is `cancelled`. It also
      shows it for one input per other step of the `build` and `publish` jobs.
      The suite reads those step names from `docker.yml` when it runs, with
      the matrix values filled in per leg. The last no-rerun inputs are a
      failed `Set up job` step, a failed `Post` step, a qualifying leg beside a
      leg whose log lacks the line, and a failed `keepalive` and a failed
      `notify`, each beside a qualifying leg.
- [x] AC2: If the event, attempt, and conclusion checks pass, the script reads
      the jobs listing and each failed build leg's log with `gh`. If those
      checks fail, the script makes no `gh` call. On a rerun decision, it calls
      `gh run rerun <run-id> --failed` exactly once for the run it received.
      On a no-rerun decision, it makes no `gh run rerun` call. When every `gh`
      call succeeds, it exits 0 on either decision. When the listing or a log
      is unreadable, or the rerun call fails, it exits non-zero. The suite
      asserts the stubbed `gh` call log and the exit status for these inputs:
      the rerun case, each no-rerun case in AC1, `gh` exiting non-zero on the
      listing and on a log, a zero-byte listing, an unparseable listing, and
      `gh run rerun` exiting non-zero.
- [x] AC3: At the review commit, `.github/workflows/rebuild-retry.yml` has
      `workflow_run` with `types: [completed]` as its only trigger. Its
      `workflows:` entry equals the `name:` value of `docker.yml`, shown by
      extracting both with grep and comparing them. Its top-level
      `permissions:` block grants only `actions: write` and `contents: read`.
      Its step passes `github.event.workflow_run.id`, `event`, `run_attempt`,
      and `conclusion` to `.github/retry-decision.sh`.
- [x] AC4: A rerun of only the failed jobs assembles and checks both manifest
      lists through the existing gates. The drill is a branch
      `workflow_dispatch` run with `test_mode=true`. In it, a temporary step
      placed before the build step fails the noble amd64 leg on attempt 1,
      gated on `github.run_attempt == 1 && matrix.variant == 'noble' &&
      matrix.arch == 'amd64'`. Then `gh run rerun <id> --failed` produces an
      attempt 2 in which that leg is the only build leg that runs again. In
      attempt 2, the four-digest guard of the `publish` job and both
      manifest-list checks pass. The temporary step is absent from the branch
      at the review commit.
- [x] AC5: The retry comment in `scripts/install_bayes.sh` names
      `rebuild-retry.yml` and its rule of one rerun for scheduled runs only.
      `git grep -n retry-on-failure -- ':!cairn/'` returns no hit. In
      DESIGN.md, the Unattended-rebuild alerts entry names `rebuild-retry.yml`
      and `retry-decision.sh`. The Pre-merge checks entry names
      `test_retry_decision.sh` and counts four suites. The alerts convention
      states the rule (one rerun, scheduled runs only, mirror symptom only) and
      states that a rerun works only while the 1-day digest artifacts exist.
- [ ] AC6: The `script-tests` job in `pr-ci.yml` runs
      `.github/tests/test_retry_decision.sh`. The `pr-ci.yml` and `lint.yml`
      runs on the milestone pull request pass.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T3
- AC4 → T4
- AC5 → T5
- AC6 → T3, T6

## Tasks

- [x] T1: Write `.github/tests/test_retry_decision.sh` first, in the style of
      the existing suites (stubbed `gh`, call log, exit status). Shape the jobs
      fixtures on a real listing (`gh run view 34127399018 --json jobs`). Read
      the step names from `docker.yml` with the matrix values filled in. Run it
      with no script and see it fail.
- [x] T2: Write `.github/retry-decision.sh` (arguments: run id, event,
      attempt, conclusion) until the suite passes. Run shellcheck at `-S info`
      and get no findings.
- [x] T3: Add `.github/workflows/rebuild-retry.yml` per AC3. Add the suite to
      the `script-tests` job in `pr-ci.yml`.
- [x] T4: Run the drill on the branch. Add the temporary failing step,
      dispatch `docker.yml` with `test_mode=true`, and run
      `gh run rerun <id> --failed`. Record the job list and publish log of
      attempt 2. If attempt 2 cannot read the digests of attempt 1, fix the
      download in `docker.yml` and repeat. Remove the step.
- [x] T5: Update `scripts/install_bayes.sh:11-16`, the `notify` comment in
      `docker.yml`, and DESIGN.md per AC5. Write each against the T2 and T4
      results.
- [x] T6: Before review, run the profile verify slot (`hadolint Dockerfile`,
      `docker build`) and all four suites locally.

## Work log

- 2026-09-13: created by /milestone-plan, promoting the retry candidate row (M001 review F2, M003 review O1, N1).
- 2026-09-13: criteria audit (full mode, fresh [O] reader, two passes) returned 13 findings, then 8, all fixed. The main ones: a real mirror failure also fails `publish` at its digest count, and a drill step gated only on attempt 1 fails all four legs.
- 2026-09-13: plan chose a separate `workflow_run` workflow over a longer in-script retry in `install_bayes.sh`. Both in-script tries of the 2026-08-17 and 2026-09-07 failures failed on the same runner. Falsified by a mirror failure that a longer wait on the same runner recovers.
- 2026-09-13: plan gate chose the build-step-plus-log-line symptom over any failed build step. The recent weekly failures all carried the line, and a real compile break needs no rebuild. Falsified by a scheduled mirror failure without that line.
- 2026-09-13: plan gate chose scheduled runs only over scheduled runs plus pushes, because the person who merged watches a push build. Falsified by a push build that fails on the mirror and goes unnoticed.
- 2026-09-13: plan gate chose letting attempt 1 open the issue and a green rerun close it over holding `notify` on attempt 1. Holding it hides a failure for a week if the retry never starts. Falsified by the open-then-close emails proving a burden in practice.
- 2026-09-13: plan gate chose a branch rerun drill plus a post-merge candidate row over keeping M004 in review until a real failure, which can block work for weeks. Falsified by a qualifying scheduled failure that starts no retry run.
- 2026-09-13: implement started; branch m004-weekly-leg-retry cut from main at faf75d7.
- 2026-09-13: implement gate chose reading leg logs through the job-log API (`gh api repos/{owner}/{repo}/actions/jobs/<id>/logs`) over `gh run view --log-failed`, which can print nothing when it cannot map step log files to steps.
- 2026-09-13: implement gate chose starting the retry job on every docker.yml completion and letting the script decide, over a job-level `if` that would duplicate the event rule.
- 2026-09-13: T1 done: `test_retry_decision.sh` builds fixtures from docker.yml step names; with no script it fails 85 assertions.
- 2026-09-13: T2 done: `retry-decision.sh` passes the suite (139 assertions) and shellcheck 0.11.0 `-x -S info` (run through Docker, none installed locally). Mutating the log check, the build-step check, the publish-step check, the attempt check, or `--attempt` each fails the suite.
- 2026-09-13: T2 found that gh 2.97.0 and later refuse to print a job log holding terminal escape sequences; the log call passes `--allow-escape-sequences`, and the suite asserts it. With it, the failed 2026-09-07 leg's log (job 101759190487) reads and holds the mirror line. Runner image ubuntu-24.04 lists gh 2.100.0.
- 2026-09-13: T3 done: `rebuild-retry.yml` added (only trigger `workflow_run` completed, `actions: write` + `contents: read`, the four payload fields passed through env); `pr-ci.yml` script-tests runs the new suite, job name kept. actionlint 1.7.12 is clean on rebuild-retry.yml, pr-ci.yml, and docker.yml; the `workflows:` entry and docker.yml `name:` extract to the same string.
- 2026-09-13: T4 drill started: temporary step pushed, branch dispatch run 34775210635 (`test_mode=true`); T5 begun in parallel with the `install_bayes.sh` retry comment (DESIGN.md and the `notify` comment wait on the drill result). Local hadolint (hadolint/hadolint image) is clean; local `docker build` running.
- 2026-09-13: T4 attempt 1 of run 34775210635 concluded failure: noble amd64 failed at the drill step, publish at `Require all four verified digests`, the other legs and keepalive green, notify skipped. Local `docker build -t rocker-bayes:dev .` exited 0. `gh run rerun 34775210635 --failed` started attempt 2.
- 2026-09-13: T4 attempt 2 of run 34775210635 concluded success. Only `build (noble, amd64)` started again (18:45:27Z; the other legs and keepalive keep their 18:37Z attempt-1 start); publish (job 103773956618) downloaded four `digests-*` artifacts, printed "found all 4 verified digests", then "the noble manifest list names both architectures: amd64 arm64" and the same for resolute; notify was rerun as a dependent and skipped on its condition. No `docker.yml` download fix was needed. Drill step removed.
- 2026-09-13: T5 done: `notify` comment in docker.yml names rebuild-retry.yml and that a failed-jobs rerun reruns notify (seen in T4 attempt 2); DESIGN.md alerts entry names both files, Pre-merge checks names the four suites, new convention states the one-rerun, scheduled-only, mirror-symptom rule and the 1-day digest-artifact limit. `git grep -n retry-on-failure -- ':!cairn/'` returns no hit.
- 2026-09-13: T6 done: hadolint clean, `docker build -t rocker-bayes:dev .` exits 0, all five `.github/tests/` suites (the four named plus test_publish_guard.sh) exit 0, pinned shellcheck 0.11.0 `-x -S info` clean over every tracked `*.sh`/`*.command`, actionlint 1.7.12 clean over all workflows. AC6's PR-run half waits for the review-step PR.
- 2026-09-13: delegated the claim audit to a fresh [O] reader (read-only); its 7 corrections were applied by the author and re-read once by the same reader, all holding.
- claim audit: 32 claims read, 7 corrected — .github/retry-decision.sh, .github/tests/test_retry_decision.sh, .github/workflows/pr-ci.yml, .github/workflows/rebuild-retry.yml
- 2026-09-13: status set to review. Open for review: the `script-tests` job name still reads "alert and keepalive script suites" (kept so a required-check name cannot break); `test_publish_guard.sh` is still unrun in CI, already a candidate row.

## Decisions

## Review

Review run 2026-09-13 on `m004-weekly-leg-retry` at e276ecc. The `main` branch did not move after the branch was cut at faf75d7.

- AC1: `bash .github/tests/test_retry_decision.sh` exits 0 and prints "PASS: all retry-decision assertions". It reads 9 build and 9 publish step names from docker.yml. An independent awk count of `- name:` lines gives the same 9 and 9. The rerun cases are one qualifying leg for each of the four legs, and two legs. Each no-rerun case asserts a `no rerun:` line that names the condition. The no-rerun cases are push, attempt 2, success, cancelled, timed_out, no failed job, and a cancelled leg. They also include the 8 other build steps and the 8 other publish steps. The last are `Set up job`, a `Post` step, a leg log without the line, and a failed keepalive or notify beside a qualifying leg. On a copy of the script without the log check, the suite exits 1 (3 failed assertions). It also exits 1 without the attempt check (4), the publish-step check (17), or the build-step check (21).
- AC2: The same suite run asserts the stubbed `gh` call log and the exit status. For push, attempt 2, success, cancelled, and timed_out, it asserts exit 0 and an empty call log. Each rerun case asserts exit 0, a `run view 555 --attempt 1 --json jobs` call, and the log call for each failed leg. It also asserts exactly one `run rerun 555 --failed` call. Each other no-rerun case in AC1 asserts exit 0 and no `run rerun` call. These inputs each assert a non-zero exit and no rerun call: `gh` failing on the listing, `gh` failing on a log, a zero-byte listing, and an unparseable listing. For `gh run rerun` exiting non-zero, the suite asserts a non-zero exit after one rerun call. On a script copy without the event check, the suite exits 1 (4 failed assertions). On a copy that calls the rerun twice, it exits 1 (7).
- AC3: At e276ecc, the `on:` block of `rebuild-retry.yml` holds one key, `workflow_run`, with `types: [completed]`. The grep-extracted `workflows:` entry and the grep-extracted `name:` of docker.yml compare equal as "Build and push Docker images". The top-level `permissions:` block holds `actions: write` and `contents: read` and nothing else. The step env passes `github.event.workflow_run.id`, `.event`, `.run_attempt`, and `.conclusion` as the four arguments of `.github/retry-decision.sh`.
- AC4: Read again with `gh` at review. Run 34775210635 is a `workflow_dispatch` run on `m004-weekly-leg-retry` at 4aa3c36, and its publish log shows `TEST_MODE: true`. At 4aa3c36, the step `Drill failure on attempt 1` sits before the build step, with `if: github.run_attempt == 1 && matrix.variant == 'noble' && matrix.arch == 'amd64'`. Attempt 1: `build (noble, amd64)` failed at the drill step, and publish failed at `Require all four verified digests`. In attempt 2, only `build (noble, amd64)` has a new start time (18:45:27Z). The other three legs and keepalive keep their attempt-1 start times of 18:37Z. In attempt 2, publish job 103773956618 passed every step. Its log prints "found all 4 verified digests" and a "names both architectures: amd64 arm64" line for noble and for resolute. `git grep -n -i drill HEAD -- .github/workflows/docker.yml` returns no hit.
- AC5: The retry comment at `scripts/install_bayes.sh:11-20` names `.github/workflows/rebuild-retry.yml`. It says a scheduled rebuild gets its failed jobs rerun once, and that push builds, dispatch builds, and a second attempt are not rerun. `git grep -n retry-on-failure -- ':!cairn/'` exits 1 with no output. In DESIGN.md, the Unattended-rebuild alerts entry names `rebuild-retry.yml` and `retry-decision.sh`. The Pre-merge checks entry says "four suites" and names `test_retry_decision.sh`. The new convention "A weekly rebuild that failed on the r2u mirror is rerun once" states one rerun, scheduled runs only, and the mirror symptom. It also states the 1-day limit, which matches `retention-days: 1` at docker.yml:172.
- AC6 (first half): The `script-tests` job in `pr-ci.yml` runs `bash ./.github/tests/test_retry_decision.sh` as its fourth line. The `pr-ci.yml` paths filter admits `.github/*.sh`, `.github/tests/**`, and `.github/workflows/**`. The `lint.yml` filter admits `**.sh`. Both workflows therefore start on this pull request. The second half (both runs pass on the milestone PR) needs the PR, which opens only after merge approval. The box stays open until the CI wait before the merge shows both runs green.

Consistency gate:

- `cairn_validate.py` exits 0, and every check reads PASS or OK.
- No DESIGN.md principle changed, so `cairn_impact.py` does not apply.
- `docker build -t rocker-bayes:dev .` exits 0. `hadolint Dockerfile` (hadolint/hadolint image) exits 0 with no output.
- The base image is `jmgirard/rstudio2u:${BASE_TAG}` with `BASE_TAG=noble`, a named tag and not `latest`. This line did not change in the milestone.
- No `ENV`, `ARG`, or `COPY` line in the Dockerfile holds a credential. `.dockerignore` exists and excludes `.git`, `.github`, and `cairn`.
- The changelog slot is none, so no entry is due.
- Extra local checks: all five `.github/tests/` suites exit 0. Shellcheck 0.11.0 `-x -S info` over every tracked `*.sh` and `*.command` exits 0. actionlint 1.7.12 over all workflows exits 0.

Independent review (user-facing tier, three lenses). Proposed dispositions go to the merge gate.

- Prior-review lens [S]: no finding. The diff resolves M003 review O1 and N1 and contradicts no archived finding.
- Blame-history lens [S]: no defect. B1: the retry job sets `timeout-minutes: 10` and `persist-credentials: false`, which `rebuild-gap.yml` does not. Proposed: noted. B2: the job sets `GH_REPO`, which the sibling scripts leave to the checkout. Proposed: noted.
- O1 [O]: `docker.yml` has no `concurrency` group. A rerun that finishes after a newer push build publishes the older commit's images to `latest` and `noble`. Proposed: follow-up candidate row.
- O2 [O]: No run shows that GitHub accepts `gh run rerun --failed` with the workflow's own `GITHUB_TOKEN`. The drill used a local login. Proposed: follow-up, added to the existing post-merge live-retry candidate row.
- O3 [O]: The script reads every failed leg's log before any decline check. An unreadable log on a leg that failed at `Set up job` gives exit 1 in place of "no rerun". The test stub reads a missing log file as an empty log. Proposed: reject, because AC2 requires reading each failed leg's log, and the red retry run is visible beside the already open issue.
- O4 [O]: The give-up line prints for any R failure that repeats, so a package error that does not involve the mirror also gets one rerun. Proposed: reject, because the plan gate chose this symptom and recorded its falsification condition.
- O5 [O]: The retry job runs the default branch's script, not the failed run's commit. A step rename that lands during a scheduled run makes a real mirror failure decline. Proposed: reject, because it needs a rename inside a one-hour window and costs one missed retry.
- O6 [O]: Three decline branches have no test: "no build leg failed", "build leg failed with no failed step", and "publish failed with no failed step". Proposed: fix now, with three suite cases.
- O7 [O]: A failed retry job raises no issue comment, so the open issue does not say that the retry failed. Proposed: follow-up, added to the existing quiet-alerts candidate row.
- O8 [O]: The `script-tests` job name still reads "alert and keepalive script suites". Proposed: reject, because the name stays so a required-check name cannot break.
- No finding shows an acceptance criterion failing, so status stays `review`.
