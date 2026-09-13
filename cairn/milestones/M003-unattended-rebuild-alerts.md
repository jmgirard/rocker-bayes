# M003: Unattended-rebuild alerts and schedule keepalive

- **Status:** review
- **Priority:** normal
- **Depends on:** M001, M002
- **Driving RR:** —
- **Principles touched:** GP2, GP8
- **Resolves:** —
- **Surface tier:** user-facing. It protects the weekly rebuild that publishes
  the moving tags.
- **Branch/PR:** m003-unattended-rebuild-alerts

## Goal

A weekly rebuild that fails, and a weekly rebuild that silently stops
happening, both report themselves.

## Scope

**In:** ports of `.github/ci-failure-issue.sh`, `.github/keepalive.sh`,
`.github/rebuild-gap.sh`, and `.github/date-lib.sh` from rstudio2u, with their
three unit-test suites. A `notify` job and a `keepalive` job in `docker.yml`.
A new `.github/workflows/rebuild-gap.yml`. A step in M002's pre-merge lane
that runs the three suites. A dispatch input on the gap workflow that supplies
the last-success date, so the alert path can be driven on demand. The removal
of the `retry-on-failure` job, because GitHub refuses a rerun started from
inside the run it reruns.

**Out:** the publish gate goes to M001. The pre-merge lane itself goes to
M002. The Docker Hub description sync stays a candidate row. A retry started
from a separate `workflow_run` workflow stays a candidate row.

## Acceptance criteria

- [x] AC1: If any job result is neither success nor cancelled,
      `.github/ci-failure-issue.sh` opens one `ci-failure` issue. With an
      issue already open, it comments on that issue instead of opening a
      second one. With results that are unanimously successful, it closes the
      open issue. The ported suite drives all three branches and passes.
- [x] AC2: `.github/keepalive.sh` makes exactly two git calls, one empty
      commit and one push, at an age at or past the threshold. Below the
      threshold it makes no git call at all. The ported suite intercepts `git`
      on `PATH` to count the calls. It drives the threshold and the day either
      side of it. It also drives five rejection cases: a malformed date, an
      impossible calendar date, a commit date in the future, a non-integer
      threshold, and an over-wide threshold.
- [x] AC3: `.github/rebuild-gap.sh` raises the alert only at a gap strictly
      greater than the threshold. The ported suite drives the gap at the
      threshold, one day under, and one day over. It also drives the `none`
      and `unknown` sentinels and asserts that each takes its own branch
      rather than the measured-age branch.
- [x] AC4: With no `ci-failure` issue open, a run of `rebuild-gap.yml` on the
      milestone branch whose last-success date is more than the threshold days
      before the run's UTC date opens a `ci-failure` issue whose title gives
      the measured gap and that date. A second such run comments on that same
      issue. A run whose last-success date is within the threshold opens and
      comments nothing. The workflow reads the last-success date from one
      variable, which the dispatch input sets and the `gh run list` lookup
      fills when the input is empty, and one of the three runs takes its date
      from that lookup. At review, the file has no `push` trigger.
- [x] AC5: `docker.yml` gains a `notify` job whose `needs` list and `RESULTS`
      string name every other job in the file. It runs whatever those jobs'
      results are, on scheduled runs and when the `notify` dispatch input is
      set, and no step in it skips the report for a later attempt. The file has
      no `retry-on-failure` job and no `gh run rerun` call, shown by a recorded
      `grep`. A `test_mode` run with no `ci-failure` issue open and
      every build and publish job green, in which the keepalive job is forced
      to fail, opens the issue with a failed-job list of exactly `keepalive`.
- [x] AC6: The keepalive job pushes its empty commit with a repository deploy
      key. A dispatch with the threshold at 0 lands the commit. The same
      dispatch with the key secret cleared fails to push. No job in
      `docker.yml` grants `contents: write`, shown by a recorded `grep` over
      the file.
- [x] AC7: `hadolint Dockerfile` reports no violations and `docker build`
      succeeds from a clean context. This is the profile's verify slot.

## Coverage

- AC1 → T2, T6
- AC2 → T3, T6
- AC3 → T4, T6
- AC4 → T5, T7
- AC5 → T6, T8
- AC6 → T1, T9
- AC7 → T10

## Tasks

- [x] T1: Create a write-enabled deploy key on the repository and store it as
      the `KEEPALIVE_DEPLOY_KEY` secret. This task is the user's to run, and
      the rest of the milestone does not wait on it.
- [x] T2: Port `.github/ci-failure-issue.sh` and its suite. Adjust the job-name
      pattern to this repo's job names.
- [x] T3: Port `.github/date-lib.sh`, `.github/keepalive.sh`, and the keepalive
      suite.
- [x] T4: Port `.github/rebuild-gap.sh` and its suite.
- [x] T5: Write `.github/workflows/rebuild-gap.yml`. Point it at this repo's
      `docker.yml` schedule. Set the threshold to 8 days: a weekly watchdog
      sees gaps in multiples of a week, so 8 alerts on the second missed
      rebuild with a day of slack for a late run. Add the last-success-date
      dispatch input that AC4 drives.
- [x] T6: Add a step to M002's pre-merge lane that runs the three suites, and
      add `.github/tests/**` to that lane's paths filter.
- [x] T7: Add a temporary `push` trigger scoped to the milestone branch, with
      the date committed alongside it. Make the three runs of AC4, one with an
      empty date so the lookup fills it. Record the issue URL and the run
      URLs, then remove the trigger.
- [x] T8: Add the `notify` job and the `notify` dispatch input to
      `docker.yml`. Remove `retry-on-failure`, `.github/retry-decision.sh`, its
      suite, and its step in `pr-ci.yml`. Drive one forced keepalive failure in
      test mode, and repeat the run if a build or publish job fails. Record the
      run and issue URLs.
- [x] T9: Add the `keepalive` job to `docker.yml` with two `actions/checkout`
      steps. One takes the workflow's own ref for the script. One takes the
      default branch for the write.
      Keep the job's permissions read-only. Record the accepted exposure: a
      dispatch against a branch runs that branch's copy of the script while
      the deploy key is in scope.
- [x] T10: Record the alert lanes and the keepalive threshold in
      `cairn/DESIGN.md` under Conventions. Run the verify slot.

## Work log

- 2026-09-11: created by /milestone-plan.
- 2026-09-11: gate chose to include the keepalive job over leaving it out. Reason: without it a quiet repo loses the weekly rebuild and the watchdog together. Falsified by GitHub dropping the 60-day rule, or by the deploy key proving unacceptable.
- 2026-09-11: plan chose porting the three unit suites over testing these scripts only through live runs. Reason: the audit found that every offline rule here was otherwise unverified. Falsified by the suites proving unable to fail on a planted defect.
- 2026-09-11: plan chose a last-success-date dispatch input over driving the gap alert with a threshold of 0. Reason: at threshold 0 a same-day success still produces a gap of 0 and raises nothing, so that evidence is not reproducible. Falsified by the input proving to bypass the code path it is meant to drive.
- 2026-09-11: criteria audit ([O], full mode) flagged all five drafted criteria. It found an overclaim against the ported script's cancelled branch, and three rules with no tests anywhere in the plan. It also found a promise about message wording rather than about the decision. It found a threshold-0 trigger that does not fire reliably. It found a repo-wide permissions claim backed by one job, and no probe of the claim that the push needs the deploy key. All were fixed above. The missing notify wiring became AC5.
- 2026-09-12: implement gate chose a temporary branch push trigger for AC4's runs (GitHub refuses to dispatch a workflow not yet on main), retry-on-failure after notify with notify silent while a retry will follow, a gap threshold of 8 days, and permanent `keepalive_threshold` and `notify` dispatch inputs for AC5 and AC6.
- 2026-09-12: minor amendment: the three suites live in `.github/tests/` beside the publish-guard suite, not `scripts/tests/`, because the Dockerfile copies `scripts/` into the image. T6's paths filter entry follows.
- re-audit: AC4 (full) — No open-issue precondition. "Naming this repo's rebuild lane" is not decidable from the title. "Older than" is looser than the strict comparison. The variable clause binds a trigger removed before review. The URL-recording clause binds a recording act.
- re-audit: AC5 (full) — Retry cannot read build or publish results through notify alone. A last-attempt-only gate never reports a keepalive failure. The open-issue precondition clashes with AC4. Publish is skipped on a branch dispatch without test_mode. One live failure cannot probe the attempt axis, so the gate rule belongs in the script under AC1's suite.
- 2026-09-12: mini gate accepted fixed AC4 and AC5 wording (not yet written to the file) pending a second reader.
- re-audit: AC4 (full) — Push runs have no inputs context, so "the dispatch input sets" cannot hold on them. The lookup clause is never exercised. "The three runs set that variable" and "the merged file" bind the evidence method. "Run date" must say the UTC date.
- re-audit: AC5 (full) — failure() still sees keepalive through notify. A bare needs check gets an implicit success(). notify's if is unstated. The attempt rule leaves mixed failures, attempts past 3, and cancelled results unspecified. The cap would live in two places. "No other job named" must refer to the failed-job list. Further wording goes to the user.
- 2026-09-12: T2 port committed earlier. AC1's rule for a skipped job beside a cancelled one now opens the issue, as AC1 states, where rstudio2u ignored it. shellcheck 0.11.0 clean.
- 2026-09-12: T3 done. `.github/date-lib.sh` now refuses a threshold wider than seven digits (exit 2), where rstudio2u read it as fresh, so AC2's over-wide case is a rejection. Keepalive suite 102 assertions pass. Planted defects (boundary, future date, width, calendar, dropped push) each turn it red, as do three plants in the ci-failure suite.
- 2026-09-12: amendment (user decision after the second re-audit): AC4 and AC5 take the wording above, and Scope In adds `.github/retry-decision.sh` with its suite. AC5's retry rule moved out of `ci-failure-issue.sh` so AC1 stays true as written. Coverage AC5 gains T6. Minor task edits: T5 threshold 8 days, T6 four suites under `.github/tests/**`, T7 temporary push trigger, T8 retry script.
- 2026-09-12: T2 done. The build-leg parse matches `build (` only, because `publish` is one job here and is named by itself. ci-failure suite 99 assertions pass.
- 2026-09-12: T4 done. Issue subjects name `docker.yml`. The over-wide threshold is refused, as in keepalive. Suite 131 assertions pass at the 8-day bound, shellcheck clean. Plants (boundary, `none` into the measured branch, `unknown` wording, future date) each turn it red.
- 2026-09-12: T8 and T9 (partial): `.github/retry-decision.sh` and its suite (35 assertions; plants on the cap, the attempt, publish, the wait rule, and a skipped job each turn it red). docker.yml gains the `keepalive_threshold` and `notify` inputs, workflow env `RETRY_CAP`, the `keepalive` and `notify` jobs, and `retry-on-failure` rewired to need notify and read the script. actionlint 1.7.7 clean. Live runs pending.
- 2026-09-12: T5 done. `rebuild-gap.yml` runs Tuesdays 07:00 UTC, a day after the Monday rebuild, because recent scheduled runs were created up to 8 hours after their cron time. `LAST_SUCCESS` is the one date variable: the dispatch input sets it, and the lookup fills it when empty. Threshold 8.
- 2026-09-12: T6 done. `pr-ci.yml` gains a `script-tests` job running the four suites, and `.github/tests/**` joins its paths filter. The four suites pass under bash 3.2. The two jq-free suites also pass under Linux bash 5.2.
- 2026-09-12: T7 done. No ci-failure issue was open at the start. Run https://github.com/jmgirard/rocker-bayes/actions/runs/34717240302 (date 2026-08-01) opened https://github.com/jmgirard/rocker-bayes/issues/8 titled "No successful scheduled docker.yml rebuild in 42 days (since 2026-08-01)". Run https://github.com/jmgirard/rocker-bayes/actions/runs/34717259419 (empty date, lookup gave 2026-08-31) commented on #8 with a 12-day gap. Run https://github.com/jmgirard/rocker-bayes/actions/runs/34717295150 (date 2026-09-10) printed "within the 8-day bound; no alert", and #8's comment count stayed at 1. The trigger commit is reverted, and the file is identical to the T5 commit.
- 2026-09-12: closed test issue #8 by hand so AC5's run starts with no ci-failure issue open. Its lookup comment reports a real gap: the last successful scheduled rebuild was 2026-08-31.
- 2026-09-12: T8 done. Dispatch https://github.com/jmgirard/rocker-bayes/actions/runs/34717363489 on the branch (test_mode, notify, keepalive_threshold 0, no deploy key yet): all four build legs and publish succeeded, keepalive failed, retry-on-failure printed retry=false wait=false and did not rerun, and notify opened https://github.com/jmgirard/rocker-bayes/issues/9 titled "Weekly run failed: keepalive" with body "The scheduled run failed in: keepalive".
- 2026-09-12: T9 (partial), AC6's no-key case: in that same run keepalive committed at age 0, then `git push` failed with "Permission to jmgirard/rocker-bayes.git denied to github-actions[bot]" and HTTP 403, exit 128. `grep -c 'contents: write' .github/workflows/docker.yml` prints 0, and the three `contents:` lines all read `read`.
- 2026-09-12: T10 done. DESIGN gains a Function Families entry and two Conventions bullets. Verify slot: `hadolint Dockerfile` (hadolint 2.12.0) exits 0, and `docker build` from a `git archive HEAD` context succeeds.
- 2026-09-12: blocked on T1, the user's task: create a write-enabled deploy key and store its private half as the `KEEPALIVE_DEPLOY_KEY` secret. AC6's landing dispatch (threshold 0) waits on it.
- 2026-09-13: T1 done by the user. `gh repo deploy-key list` shows `KEEPALIVE_DEPLOY_KEY` read-write, and `gh secret list` shows the secret set 2026-09-13. Status back to in-progress.
- 2026-09-13: T9 done. Dispatch https://github.com/jmgirard/rocker-bayes/actions/runs/34770877387 on the branch (test_mode, notify, keepalive_threshold 0, key set): keepalive logged a tip dated 2026-09-12, committed at age 1, and pushed `d19bc56..b444cd2 main -> main` over `git@github.com`. b444cd2 is empty and authored by github-actions[bot]. All four legs, publish, notify, and retry-on-failure succeeded, and notify closed #9. The no-key case is the 2026-09-12 run above. `grep -c 'contents: write' .github/workflows/docker.yml` prints 0.
- 2026-09-13: merged origin/main (the empty b444cd2 only) into the branch. Verify: hadolint 2.12.0 (container image) on Dockerfile exits 0. The Dockerfile is unchanged since T10's local build, and the run above built all four legs. The four suites pass locally.
- claim audit: 160 claims read, 15 corrected — .github/ci-failure-issue.sh, .github/date-lib.sh, .github/keepalive.sh, .github/rebuild-gap.sh, .github/retry-decision.sh, .github/workflows/docker.yml, .github/workflows/rebuild-gap.yml, .github/tests/test_ci_failure_issue.sh, .github/tests/test_keepalive.sh, .github/tests/test_rebuild_gap.sh, .github/tests/test_retry_decision.sh
- 2026-09-13: [O] claim-audit reader, fresh context. Edits are prose only: comments, the `ci-failure` label description, and two dispatch-input descriptions. After them the five suites pass and actionlint 1.7.7 is clean. Status set to review.
- 2026-09-13: review return 1 (defect): AC5 fails. GitHub refuses `gh run rerun` from `retry-on-failure` while that job runs (scheduled runs 34127399018 and 32007984150). No retry fires, and `notify` with `wait=true` leaves a failed build leg unreported. AC1-AC4, AC6, AC7 verified. 16 review findings logged in Review, untriaged. Status back to in-progress.
- 2026-09-13: amendment (user decision, narrowing after return 1): AC5 drops the retry. notify names every other job, reports every attempt, and the file has no `retry-on-failure` job or `gh run rerun` call. Scope In removes `.github/retry-decision.sh` and adds the job's removal. Scope Out adds a `workflow_run` retry as a candidate row. AC5 already has two re-audit lines, so no reader ran and the wording went to the user. T8 reopened and T6 now names three suites. The other 15 findings stay for the review gate.
- 2026-09-13: T8 (partial): removed `retry-on-failure`, `RETRY_CAP`, notify's wait branch, `.github/retry-decision.sh`, its suite, and its `pr-ci.yml` line. Comments in `docker.yml` and `rebuild-gap.yml`, DESIGN, the M001 rerun lesson (corrected), and the F2 retry candidate row follow. Run 34127399018's log reads "cannot be rerun; This workflow is already running". actionlint 1.7.7, shellcheck 0.11.0 and hadolint 2.12.0 exit 0, the four remaining suites pass, and the `grep -cE 'retry-on-failure|gh run rerun'` over `docker.yml` prints 0. Live run pending.
- 2026-09-13: T8 done. No ci-failure issue was open. Dispatch https://github.com/jmgirard/rocker-bayes/actions/runs/34772606155 on 541300a (test_mode, notify, keepalive_threshold `fifty`): all four legs and publish succeeded, and publish logged the test-mode no-tag line. keepalive exited 2 on "not a non-negative integer: 'fifty'". notify succeeded and opened https://github.com/jmgirard/rocker-bayes/issues/10 titled "Weekly run failed: keepalive" with body "The scheduled run failed in: keepalive". #10 is left open. Claim audit not re-run: its one pass ran before the return, and the return added only comment lines in `docker.yml` and `rebuild-gap.yml`. Status set to review.
- 2026-09-13: re-review on abf0f84: AC1-AC7 verified again, AC5 ticked, consistency gate clean, three reviewers ran, 19 findings triaged at the gate.
- step-7 approval: m003-unattended-rebuild-alerts approved for merge

## Decisions

## Review

Evidence gathered 2026-09-13 on 8ab46f9, which already contains origin/main (`git log HEAD..origin/main` is empty).

- AC1: `bash .github/tests/test_ci_failure_issue.sh` exits 0, 99 `ok` lines, none failing. Case 1 (failure, none open) asserts `issue create` with the `ci-failure` label. Case 2 (failure, #41 and #57 open) asserts `issue comment 41` and no `issue create`. Case 3 (unanimous success, two open) asserts a comment and `issue close` on each. Cases 6a, 6b (cancelled only) assert no gh call. Cases 6c to 6h assert that skipped, unknown, and empty results never close. Two plants in a scratch copy turn the suite red. A comment on the newest open issue gives 11 failures. A `cancelled` result read as success gives 3 failures.
- AC2: `bash .github/tests/test_keepalive.sh` exits 0, 102 `ok` lines. A `git` stub first on `PATH` logs each call. If the stub is not the `git` the suite finds, the suite fails at once. At 50 days against 50, and at 51, `assert_call_log` requires exactly two logged calls, an empty commit then a push. At 49 days `assert_no_git` requires an empty log. Each rejection case asserts exit 2 and no git call. Case 7 drives malformed dates. Case 8 drives 2026-02-30, 2026-02-29, 2026-04-31, 2026-13-01 and 2026-00-10. Case 9 drives a commit dated after today. Case 10 drives thresholds such as `5.5` and `fifty`. Case 11 drives thresholds of 8, 19 and 32 digits. Two plants turn it red: `<=` at the boundary gives 6 failures, and a dropped push gives 6 failures.
- AC3: `bash .github/tests/test_rebuild_gap.sh` exits 0, 131 `ok` lines. Against an 8-day bound, 7 days (case 1) and 8 days (case 2) assert no gh call. 9 days (case 3) asserts `issue create` titled "No successful scheduled docker.yml rebuild in 9 days (since 2026-01-01)". Cases 5 and 6 drive `none` and `unknown` at thresholds 8 and 0. Each asserts its own title and output line, and asserts that the measured-age title and output are absent. Two plants turn it red: `<` in place of `<=` at the bound, and `none` sent into the measured branch (7 failures).
- AC4: read again with `gh` on 2026-09-13. `gh issue list --label ci-failure --state all` lists only #8 and #9, so no `ci-failure` issue was open before the first run. Run 34717240302 (push, branch, f2bb815) logs "last-success date supplied: 2026-08-01", today 2026-09-12 UTC, 42 days past the 8-day bound. Issue #8 was created at 20:29:32Z with the title "No successful scheduled docker.yml rebuild in 42 days (since 2026-08-01)". Run 34717259419 (03d1eb1, `LAST_SUCCESS` left empty) logs "looked up: 2026-08-31", and #8 gains its one bot comment at 20:30:08Z. Run 34717295150 (2bc94a4, date 2026-09-10) logs "2 day(s) ago, within the 8-day bound; no alert". The next comment on #8 is the maintainer's hand close at 20:31:46Z, after that run ended at 20:30:36Z. At each of the three commits, `LAST_SUCCESS` is the one date variable. At HEAD, `grep -cE '^\s*push:' .github/workflows/rebuild-gap.yml` prints 0. `git diff 2bc94a4 HEAD` on the file shows only the trigger removal, the date literal removal, and one input description edit.
- AC5: a PyYAML read of `docker.yml` lists the jobs `build`, `publish`, `keepalive`, `notify` and `retry-on-failure`. `notify` needs `build`, `publish` and `keepalive`, and its `RESULTS` names the same three. Its `if` is `always()` joined to the schedule event or a dispatch with `inputs.notify`. `retry-on-failure` needs `build`, `publish` and `notify`, and both jobs call `.github/retry-decision.sh` with `RETRY_CAP`. `bash .github/tests/test_retry_decision.sh` exits 0, 35 `ok` lines. It drives attempts 1 to 4 against a cap of 3 for six shapes. They are a build failure, a publish failure, a keepalive failure, keepalive beside build, a cancelled build, and all green. Three plants turn it red: `<=` at the cap (4 failures), a wait that ignores other jobs (4), and `publish` dropped from the retry set (6). Run 34717363489, attempt 1, was a branch dispatch with `test_mode` true in the build logs. All four legs and `publish` succeeded, and `keepalive` failed. `retry-on-failure` printed `retry=false` and `wait=false` and did not rerun. `notify` logged "opened a ci-failure issue for: keepalive" at 20:39:05Z. #9 was created at that second with the title "Weekly run failed: keepalive". No `ci-failure` issue was open, because #8 was closed at 20:31:46Z.
- AC6: `gh repo deploy-key list` shows `KEEPALIVE_DEPLOY_KEY` read-write, and `gh secret list` shows the secret set 2026-09-13T17:10:15Z. Key run 34770877387 (8e01724, threshold 0) sets `core.sshCommand` with the key and a `git@github.com` remote. It logs "1 day(s) old, at or past the 0-day threshold" and then `d19bc56..b444cd2  main -> main`. `git show b444cd2` is an empty commit by github-actions[bot], and origin/main contains it. The no-key run 34717363489 ran at 54a0f29, before the secret existed. `git diff 54a0f29 8e01724` on `docker.yml` is empty, so the job was the same. It logs "denied to github-actions[bot]", HTTP 403 over https, and exit code 128. `grep -c 'contents: write' .github/workflows/docker.yml` prints 0. The file's three `contents:` lines read `read`, and it has no workflow-level `permissions`. The repository default workflow permission is `read` (`gh api .../actions/permissions/workflow`).
- AC7: `hadolint/hadolint:v2.12.0` reads `Dockerfile` from stdin and exits 0 with no output. `docker build --no-cache` from a `git archive` of 8ab46f9 (no `.git`, no untracked files) exits 0 in 2 min 21 s on Docker 29.5.2. It builds arm64 image `sha256:2d155fe3a90a`.

Consistency gate, 2026-09-13:

- `cairn_validate.py` exits 0, and every check passes. No IP or GP text changed in `cairn/DESIGN.md`, so `cairn_impact` was not run.
- `rhysd/actionlint:1.7.7` over the repository exits 0. `koalaman/shellcheck:v0.11.0 -x` over `.github/*.sh` and `.github/tests/*.sh` exits 0. `test_publish_guard.sh` passes too (14 `ok`).
- The base image is `jmgirard/rstudio2u:${BASE_TAG}` with `BASE_TAG=noble`. That is an explicit tag, not `latest`, and the diff does not touch it. The Dockerfile has no `ENV` or `--build-arg` that carries a token or key. `.dockerignore` excludes `.git`, `.github` and `cairn`. The diff touches neither the Dockerfile, `scripts/`, nor `.dockerignore`.
- The changelog slot is none (D-002), so no changelog entry is due. This milestone changes CI only, so it needs no recipe release.

AC5 retracted, 2026-09-13. The AC5 evidence above covers the decision script and a run with no retryable failure. It never exercised a rerun. Scheduled runs 34127399018 (2026-09-07) and 32007984150 (2026-08-17) each had one failed amd64 build leg. Every other job had finished, and `retry-on-failure` logged "cannot be rerun; This workflow is already running" and exited 1. Both runs stayed at attempt 1. GitHub refuses the rerun because the calling job is itself in flight. This diff keeps the rerun inside the run. AC5 promises a retry when `build` fails below the cap, and that retry does not fire. `notify` then prints `wait=true` and reports nothing. The weekly failure goes unreported until `rebuild-gap` sees the second missed week. The AC5 box is unticked.

Independent review findings, 2026-09-13. Three fresh-context reviewers ran: [O] diff, [S] blame history, [S] prior reviews. The review returned before the approval gate, so the maintainer has not triaged any finding yet. Each line gives the rank order within its lens.

- O1 (floor return): notify waits on a rerun that GitHub refuses, so a failed build leg goes unreported. Confirmed by the two run logs above.
- O2: cancelling a scheduled run gives `cancelled skipped success`, and notify opens an issue. Case 6e of the suite asserts this on purpose, for a timed-out leg.
- O3: a branch dispatch with `notify` set and `test_mode` off skips `publish`, and notify opens an issue.
- O4: `ci-failure-issue.sh` reads `gh issue list` through process substitution, so a failed list reads as "none open". A failure run then opens a duplicate issue, and a green run leaves the real issue open.
- O5: a green dispatch with `notify` set closes a real scheduled-failure or gap issue. The issue body says only a scheduled run closes it.
- O6: the keepalive comment understates the deploy key's exposure. Any workflow pushed to any branch can read a repository secret.
- O7: a keepalive failure alone marks the run failed. `rebuild-gap` then reports no successful rebuild although tags moved.
- O8: the 50-day threshold leaves one weekly chance before the 60-day cutoff.
- O9: a kept comment says reruns restore from the build cache, but scheduled builds set `no-cache`.
- O10: the retry comment says finishing after the other jobs makes the rerun possible, which O1 shows false.
- O11: a `rebuild-gap.sh` refusal (exit 2, for example a future `createdAt`) fails the job and raises no issue.
- S1: `docker.yml`'s push paths filter does not list the four new scripts it runs, against the M002 trigger-path lesson.
- S2: `retry-on-failure` now starts on every run, not only on failure. This is documented, and it adds one short job per run.
- P1: `notify` uses `always()`, the construct the M001 cancel lesson warns about. The script ignores an all-cancelled list, but O2's shape still reports.
- P2: `pr-ci.yml` gains a job with no concurrency group, which widens an open M002 candidate row.
- P3: `retry-on-failure` reads `retry-decision.sh` without the guard that `notify` uses. The script writes its error to stderr first, so the failure is not silent.

Re-review after return 1, evidence gathered 2026-09-13 on abf0f84. `git log HEAD..origin/main` is empty, and no PR exists for the branch.

- AC1: `.github/ci-failure-issue.sh` and its suite are unchanged since 8ab46f9 (`git diff --stat` empty). The suite exits 0 with 99 `ok` lines and no `FAIL`. A plant in a scratch copy that reads `cancelled` as success turns it red with 3 failures, and the restored copy passes.
- AC2: `.github/keepalive.sh`, `.github/date-lib.sh` and the suite are unchanged since 8ab46f9. The suite exits 0 with 102 `ok` lines. A plant of `age <=` at the threshold gives 6 failures, and the restored copy passes.
- AC3: `.github/rebuild-gap.sh` and its suite are unchanged since 8ab46f9. The suite exits 0 with 131 `ok` lines. A plant of `gap <` at the bound gives 3 failures, and the restored copy passes.
- AC4: the run and issue evidence above stands, and `gh issue list --label ci-failure --state all` still shows #8 created 20:29:32Z and closed 20:31:47Z. Its comments are the bot's at 20:30:08Z and the maintainer's at 20:31:46Z. At abf0f84, `grep -cE '^\s*push:'` over `rebuild-gap.yml` prints 0. `git diff 2bc94a4 HEAD` on the file shows the trigger removal, the date literal removal, one input description edit, and one comment that no longer mentions a rerun. `LAST_SUCCESS` is still the one date variable (line 51).
- AC5: a PyYAML read lists the jobs `build`, `publish`, `keepalive` and `notify`, and workflow `env` holds only `IMAGE`. `notify` needs `build`, `publish` and `keepalive`, and its `RESULTS` names the same three. Its `if` is `always()` joined to the schedule event or a dispatch with `inputs.notify`. Its one run step has no `exit` and no condition on the attempt, and it reads `GITHUB_RUN_ATTEMPT` only to list that attempt's jobs. `grep -cE 'retry-on-failure|gh run rerun'` over `docker.yml` prints 0. Run 34772606155 was a `workflow_dispatch` at 541300a, and `git diff --stat 541300a HEAD` outside `cairn/` is empty. Its publish logged `TEST_MODE: true` and the no-tag line, all four legs and publish succeeded, and keepalive failed. notify logged "opened a ci-failure issue for: keepalive" at 17:54:21Z. #10 was created at 17:54:21Z with the `ci-failure` label, the title "Weekly run failed: keepalive", and the body "The scheduled run failed in: keepalive". No `ci-failure` issue was open at the run: #8 closed 2026-09-12 and #9 closed 17:19:31Z.
- AC6: a PyYAML comparison finds the `keepalive` job at abf0f84 equal to the job at key run 8e01724, so the key run and the no-key run above still describe this job. `gh repo deploy-key list` shows `KEEPALIVE_DEPLOY_KEY` read-write, and `gh secret list` shows the secret. `git branch -r --contains b444cd2` lists origin/main. `grep -c 'contents: write' .github/workflows/docker.yml` prints 0, and the two `contents:` lines read `read`. `build` and `publish` set no permissions, and the file has no workflow-level `permissions`. The repository default workflow permission is `read`.
- AC7: `hadolint/hadolint:v2.12.0` reads `Dockerfile` from stdin and exits 0 with no output. `docker build --no-cache` from a `git archive` of abf0f84 (no `.git`) exits 0 in 206 s on Docker 29.5.2. It builds arm64 image `sha256:a131d2035587`.

Consistency gate, 2026-09-13 on abf0f84: `cairn_validate.py` exits 0 with every check passing. No IP or GP line changed in `cairn/DESIGN.md`, so `cairn_impact` was not run. actionlint 1.7.7 and shellcheck 0.11.0 over `.github/*.sh` and `.github/tests/*.sh` exit 0. `git diff main...HEAD` touches neither `Dockerfile`, `scripts/` nor `.dockerignore`, so the base-image pin (`jmgirard/rstudio2u:${BASE_TAG}`, `BASE_TAG=noble`), the no-secrets check and the `.dockerignore` check stand as recorded above. The changelog slot is none.

Independent review on abf0f84, 2026-09-13. Three fresh-context reviewers ran: [O] diff, [S] blame history, [S] prior reviews. Status of the first pass at HEAD: O1, O9, O10, S2 and P3 are gone with the retry. O2, O3, O4, O5, O6, O7, O8, O11, P1 and P2 still apply. S1 now covers three scripts, and push runs skip both jobs that read them. The prior-review lens called O6 addressed, but `git diff 8ab46f9 HEAD` leaves that comment unchanged, so O6 stands. New findings, ranked by the [O] lens:

- N1: `scripts/install_bayes.sh:13-16` says the build fails fast so that "the workflow's retry-on-failure job" reruns the leg, and that job is gone. The in-script retry stays at 2 tries 20 s apart, so one amd64 mirror blip fails the week's rebuild.
- N2: `cairn/DESIGN.md:65` says `script-tests` runs "the four alert and keepalive suites", but `pr-ci.yml` runs three.
- N3: a `keepalive` failure alone fails the run, and `rebuild-gap.yml` counts only `--status success` runs. A deleted deploy key would make the second week raise a false "no successful rebuild" alert while tags move.
- N4: a manual rerun of a failed scheduled run keeps the `schedule` event, so its green notify closes the issue. This is a note, not a defect.
- N5: `.github/tests/test_publish_guard.sh` runs in no workflow, and T6's list of three suites leaves it out.
- N6: a `ci-failure-issue.sh` that fails in `notify` raises no issue, only GitHub's failure email.
- N7: `sed 's/^[a-z-]*=//' | xargs` in `notify` drops an empty result, so a job named in `needs` but misspelled in `RESULTS` vanishes and an otherwise green list closes the issue.
- N8: `cairn/DESIGN.md:111-114` has two lines past the usual width.

No finding shows an acceptance criterion failing.

Triage at the approval gate, 2026-09-13, accepted by the maintainer as proposed:

- Fix now: N2. `cairn/DESIGN.md` now says "the three alert and keepalive suites".
- Follow-up, retry candidate row: N1. A change under `scripts/` rebuilds and republishes the image on merge, so the comment waits. The row already carries M001 and M003 findings, so post-merge hygiene poses its disposition first.
- Follow-up, new keepalive candidate row: N3, O7, O8, O6.
- Follow-up, new candidate row for alerts that fail quietly: O4, O11, N6, N7.
- Follow-up, new `[low]` candidate row for dispatch and cancel side effects: O2, P1, O3, O5, N4.
- Follow-up, existing rows: N5 joins the publish-guard suite row, and P2 joins the concurrency row.
- Reject: S1, because push runs skip `keepalive` and `notify`, so a paths entry for their scripts tests nothing. N8, because line width changes no behavior.
- Gone at HEAD, no action: O1, O9, O10, S2, P3.
