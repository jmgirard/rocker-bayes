# M003: Unattended-rebuild alerts and schedule keepalive

- **Status:** in-progress
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
the last-success date, so the alert path can be driven on demand.

**Out:** the publish gate goes to M001. The pre-merge lane itself goes to
M002. The Docker Hub description sync stays a candidate row.

## Acceptance criteria

- [ ] AC1: If any job result is neither success nor cancelled,
      `.github/ci-failure-issue.sh` opens one `ci-failure` issue. With an
      issue already open, it comments on that issue instead of opening a
      second one. With results that are unanimously successful, it closes the
      open issue. The ported suite drives all three branches and passes.
- [ ] AC2: `.github/keepalive.sh` makes exactly two git calls, one empty
      commit and one push, at an age at or past the threshold. Below the
      threshold it makes no git call at all. The ported suite intercepts `git`
      on `PATH` to count the calls. It drives the threshold and the day either
      side of it. It also drives five rejection cases: a malformed date, an
      impossible calendar date, a commit date in the future, a non-integer
      threshold, and an over-wide threshold.
- [ ] AC3: `.github/rebuild-gap.sh` raises the alert only at a gap strictly
      greater than the threshold. The ported suite drives the gap at the
      threshold, one day under, and one day over. It also drives the `none`
      and `unknown` sentinels and asserts that each takes its own branch
      rather than the measured-age branch.
- [ ] AC4: A dispatch of `rebuild-gap.yml` that supplies a last-success date
      older than the threshold opens a `ci-failure` issue naming this repo's
      rebuild lane. A second such dispatch comments on that same issue. A
      dispatch supplying a recent date opens and comments nothing. The three
      issue URLs and run URLs are recorded.
- [ ] AC5: `docker.yml` gains a `notify` job whose `needs` list and `RESULTS`
      string name every other job in the file. A run in which one job is
      forced to fail shows the issue opened and the failed job named in the
      issue body.
- [ ] AC6: The keepalive job pushes its empty commit with a repository deploy
      key. A dispatch with the threshold at 0 lands the commit. The same
      dispatch with the key secret cleared fails to push. No job in
      `docker.yml` grants `contents: write`, shown by a recorded `grep` over
      the file.
- [ ] AC7: `hadolint Dockerfile` reports no violations and `docker build`
      succeeds from a clean context. This is the profile's verify slot.

## Coverage

- AC1 → T2, T6
- AC2 → T3, T6
- AC3 → T4, T6
- AC4 → T5, T7
- AC5 → T8
- AC6 → T1, T9
- AC7 → T10

## Tasks

- [ ] T1: Create a write-enabled deploy key on the repository and store it as
      the `KEEPALIVE_DEPLOY_KEY` secret. This task is the user's to run, and
      the rest of the milestone does not wait on it.
- [ ] T2: Port `.github/ci-failure-issue.sh` and its suite. Adjust the job-name
      pattern to this repo's job names.
- [x] T3: Port `.github/date-lib.sh`, `.github/keepalive.sh`, and the keepalive
      suite.
- [ ] T4: Port `.github/rebuild-gap.sh` and its suite.
- [ ] T5: Write `.github/workflows/rebuild-gap.yml`. Point it at this repo's
      `docker.yml` schedule. Set the threshold to a whole number of weeks,
      because a weekly watchdog can only see gaps in multiples of a week. Add
      the last-success-date dispatch input that AC4 drives.
- [ ] T6: Add a step to M002's pre-merge lane that runs the three suites, and
      add `scripts/tests/**` to that lane's paths filter.
- [ ] T7: Run the three dispatches of AC4 and record the URLs.
- [ ] T8: Add the `notify` job to `docker.yml`, scoped to scheduled runs, with
      its `needs` list covering every other job. Drive one forced failure.
- [ ] T9: Add the `keepalive` job to `docker.yml` with two `actions/checkout`
      steps. One takes the workflow's own ref for the script. One takes the
      default branch for the write.
      Keep the job's permissions read-only. Record the accepted exposure: a
      dispatch against a branch runs that branch's copy of the script while
      the deploy key is in scope.
- [ ] T10: Record the alert lanes and the keepalive threshold in
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
- re-audit: AC4 (full) — Push runs have no inputs context, so "the dispatch input sets" cannot hold on them. The lookup clause is never exercised. "The three runs set that variable" and "the merged file" bind the evidence method. "Run date" should be the UTC date.
- re-audit: AC5 (full) — failure() still sees keepalive through notify. A bare needs check gets an implicit success(). notify's if is unstated. The attempt rule leaves mixed failures, attempts past 3, and cancelled results unspecified. The cap would live in two places. "No other job named" should read the failed-job list. Further wording goes to the user.
- 2026-09-12: T2 port committed earlier. AC1's rule for a skipped job beside a cancelled one now opens the issue, as AC1 states, where rstudio2u ignored it. shellcheck 0.11.0 clean.
- 2026-09-12: T3 done. `.github/date-lib.sh` now refuses a threshold wider than seven digits (exit 2), where rstudio2u read it as fresh, so AC2's over-wide case is a rejection. Keepalive suite 102 assertions pass. Planted defects (boundary, future date, width, calendar, dropped push) each turn it red, as do three plants in the ci-failure suite.

## Decisions

## Review
