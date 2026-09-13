# M004: Rerun a weekly build that failed on the r2u mirror

- **Status:** planned
- **Priority:** high
- **Depends on:** M003
- **Driving RR:** —
- **Principles touched:** GP4, GP8
- **Resolves:** —
- **Surface tier:** user-facing — it decides whether the moving tags get the
  weekly rebuild when a mirror blip fails one leg.
- **Branch/PR:** —

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

- [ ] AC1: `.github/tests/test_retry_decision.sh` shows
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
- [ ] AC2: If the event, attempt, and conclusion checks pass, the script reads
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
- [ ] AC3: At the review commit, `.github/workflows/rebuild-retry.yml` has
      `workflow_run` with `types: [completed]` as its only trigger. Its
      `workflows:` entry equals the `name:` value of `docker.yml`, shown by
      extracting both with grep and comparing them. Its top-level
      `permissions:` block grants only `actions: write` and `contents: read`.
      Its step passes `github.event.workflow_run.id`, `event`, `run_attempt`,
      and `conclusion` to `.github/retry-decision.sh`.
- [ ] AC4: A rerun of only the failed jobs assembles and checks both manifest
      lists through the existing gates. The drill is a branch
      `workflow_dispatch` run with `test_mode=true`. In it, a temporary step
      placed before the build step fails the noble amd64 leg on attempt 1,
      gated on `github.run_attempt == 1 && matrix.variant == 'noble' &&
      matrix.arch == 'amd64'`. Then `gh run rerun <id> --failed` produces an
      attempt 2 in which that leg is the only build leg that runs again. In
      attempt 2, the four-digest guard of the `publish` job and both
      manifest-list checks pass. The temporary step is absent from the branch
      at the review commit.
- [ ] AC5: The retry comment in `scripts/install_bayes.sh` names
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

- [ ] T1: Write `.github/tests/test_retry_decision.sh` first, in the style of
      the existing suites (stubbed `gh`, call log, exit status). Shape the jobs
      fixtures on a real listing (`gh run view 34127399018 --json jobs`). Read
      the step names from `docker.yml` with the matrix values filled in. Run it
      with no script and see it fail.
- [ ] T2: Write `.github/retry-decision.sh` (arguments: run id, event,
      attempt, conclusion) until the suite passes. Run shellcheck at `-S info`
      and get no findings.
- [ ] T3: Add `.github/workflows/rebuild-retry.yml` per AC3. Add the suite to
      the `script-tests` job in `pr-ci.yml`.
- [ ] T4: Run the drill on the branch. Add the temporary failing step,
      dispatch `docker.yml` with `test_mode=true`, and run
      `gh run rerun <id> --failed`. Record the job list and publish log of
      attempt 2. If attempt 2 cannot read the digests of attempt 1, fix the
      download in `docker.yml` and repeat. Remove the step.
- [ ] T5: Update `scripts/install_bayes.sh:11-16`, the `notify` comment in
      `docker.yml`, and DESIGN.md per AC5. Write each against the T2 and T4
      results.
- [ ] T6: Before review, run the profile verify slot (`hadolint Dockerfile`,
      `docker build`) and all four suites locally.

## Work log

- 2026-09-13: created by /milestone-plan, promoting the retry candidate row (M001 review F2, M003 review O1, N1).
- 2026-09-13: criteria audit (full mode, fresh [O] reader, two passes) returned 13 findings, then 8, all fixed. The main ones: a real mirror failure also fails `publish` at its digest count, and a drill step gated only on attempt 1 fails all four legs.
- 2026-09-13: plan chose a separate `workflow_run` workflow over a longer in-script retry in `install_bayes.sh`. Both in-script tries of the 2026-08-17 and 2026-09-07 failures failed on the same runner. Falsified by a mirror failure that a longer wait on the same runner recovers.
- 2026-09-13: plan gate chose the build-step-plus-log-line symptom over any failed build step. The recent weekly failures all carried the line, and a real compile break needs no rebuild. Falsified by a scheduled mirror failure without that line.
- 2026-09-13: plan gate chose scheduled runs only over scheduled runs plus pushes, because the person who merged watches a push build. Falsified by a push build that fails on the mirror and goes unnoticed.
- 2026-09-13: plan gate chose letting attempt 1 open the issue and a green rerun close it over holding `notify` on attempt 1. Holding it hides a failure for a week if the retry never starts. Falsified by the open-then-close emails proving a burden in practice.
- 2026-09-13: plan gate chose a branch rerun drill plus a post-merge candidate row over keeping M004 in review until a real failure, which can block work for weeks. Falsified by a qualifying scheduled failure that starts no retry run.

## Decisions

## Review
