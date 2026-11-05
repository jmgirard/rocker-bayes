<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M012: Alert on a failed docker.yml push build

- **Status:** in-progress
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP8
- **Resolves:** —
- **Surface tier:** user-facing — it edits the publish job that moves the tags users pull
- **Branch/PR:** m012-alert-failed-push-build

## Goal

A failed `docker.yml` push build reports through the `ci-failure` issue, and a stale run no longer closes that issue or counts as a rebuild.

## Scope

**In:** Candidate row "Alert on a failed docker.yml push build", in full. The `notify` job also runs on push builds, with its own issue wording. A green push build writes nothing to the issue. A stale run neither opens, comments on, nor closes the issue, and `last-success.sh` does not count it. From candidate row "Fix notify on cancels and dispatches", the cancel clause only: a run cancelled before `notify` starts reports nothing, because this milestone would otherwise add the same false alert for a cancelled push build.

**Out:**
- A green push build closing the issue: not wanted, by the user's answer at the question set. A scheduled run still closes it.
- A push run that fails at startup, such as invalid workflow YAML, starts no job, so `notify` cannot report it: new parked row "Alert on a docker.yml startup failure".
- An older push build that fails after a newer push fixed the problem still alerts, and costs a close by hand: new parked row "Quiet alerts from superseded push builds".
- The dispatch clauses of "Fix notify on cancels and dispatches" stay in that row.
- "Make alert scripts fail loudly" and "Stop false gap alerts from keepalive" stay in their own rows.
- The `docker.yml` push `paths` filter does not change (D-003).

## Acceptance criteria

- [ ] AC1: A `docker.yml` push run whose results include any value other than `success` or `cancelled` reports through the `ci-failure` issue. With no open issue it opens one titled `Push build failed: <failed jobs>`, or with the script's generic text where no job concluded `failure`. With an open issue it comments on the oldest one. Evidence: `test_ci_failure_issue.sh` cases for a failed build with a failed publish, a failed publish alone, a cancelled build beside a skipped publish, and an open issue; and one real push-event run on the drill branch with a planted failure that opens the issue.
- [ ] AC2: A push run whose `build` and `publish` jobs both succeeded writes nothing to the issue, whether or not one is open. `keepalive`'s skip on a push run does not count as a failure. A `docker.yml` run cancelled before `notify` starts also writes nothing. Evidence: a `test_ci_failure_issue.sh` case for each open state; one real push-event run on the drill branch, made under T5's temporary edits, whose `notify` job passes and leaves the drill's open issue unchanged; and one real dispatch with `notify` set, cancelled while a leg builds, whose `notify` job shows `skipped` or `cancelled` with no step run.
- [ ] AC3: Scheduled runs and dispatches with `notify` set keep their rule and wording. With `RUN_EVENT` unset, `schedule`, or `workflow_dispatch`, a failed job opens or comments on the issue with the `Weekly run failed` wording, and a fully green fresh run closes it. Evidence: the existing `test_ci_failure_issue.sh` cases passing unedited; new cases for the `schedule` and `workflow_dispatch` values; and one real forced-fresh `test_mode` dispatch with `notify` set on the drill branch that closes the drill's issue.
- [ ] AC4: A run whose `fresh` step reads `stale` and whose `publish` job succeeded attaches no tag, ends green, and neither opens, comments on, nor closes the issue. If `keepalive` failed in that run, the failure reports as usual. Evidence: `test_ci_failure_issue.sh` cases for `success stale success` and `success stale failure`; and one real `test_mode` dispatch with `notify` set on the milestone branch, whose publish log shows the stale verdict, whose "Attach the tags" step shows `skipped`, and which leaves the drill's open issue unchanged.
- [ ] AC5: For runs after this change, `last-success.sh` prints the date of the newest successful scheduled run whose "Attach the tags" step succeeded, so a stale run does not count as a rebuild. A readable job listing with no such step does not count, and the script goes on to the next older run. A job listing it reaches and cannot read makes it print `unknown`. Evidence: `test_last_success.sh` cases with a stubbed `gh`; and one real `rebuild-gap.yml` dispatch on the milestone branch that prints a date looked up from the real run history.
- [ ] AC6: A run whose verdict is `fresh` runs its "Attach the tags" step: in test mode the step prints its test-mode line, and otherwise it attaches the tags. Evidence: the forced-fresh `test_mode` dispatch of AC3, whose step shows `success` and prints the test-mode line.
- [ ] AC7: These sites state the rules above: `cairn/DESIGN.md`'s alert and stale-run bullets; the comments in `docker.yml` and `rebuild-gap.yml`; the `notify` input description in `docker.yml`; and the headers of `ci-failure-issue.sh`, `last-success.sh`, and `test_last_success.sh`. The `ci-failure` label description names push builds. Evidence: a read of each site in the diff; `gh label list` after AC1's drill; and `pr-ci.yml`'s script suites and `lint.yml` passing on the pull request.

## Coverage

- AC1 → T1, T2, T5
- AC2 → T1, T2, T5
- AC3 → T1, T5
- AC4 → T1, T2, T5
- AC5 → T3, T5
- AC6 → T2, T5
- AC7 → T1, T3, T4, T5

## Tasks

- [x] T1: In `.github/ci-failure-issue.sh`, read `RUN_EVENT`, tests first. On `push`, a failure uses the `Push build failed` wording, and a success writes nothing and prints a line. Unset or any other value keeps today's wording. Add a `stale` result: it counts as a failure beside a failed job, and otherwise opens and closes nothing. Update the header and the label description.
- [x] T2: In `.github/workflows/docker.yml`: give `publish` a job output carrying the verdict; add a step-level `if` on the verdict to "Attach the tags" and remove the step's own stale branch; change the `notify` gate to `!cancelled()` and add `push`; pass `RUN_EVENT`; drop `keepalive` from `RESULTS` on a push run; pass `stale` for `publish` only when the verdict is `stale` and `needs.publish.result` is `success`. Update the comments and the `notify` input description.
- [x] T3: In `.github/last-success.sh`, walk the successful scheduled runs newest first and read each one's job listing with `gh run view` until one has "Attach the tags" at `success`, tests first. In `rebuild-gap.yml`, add `databaseId` to the run list. Update the headers and comments. The existing `test_last_success.sh` cases gain a stub.
- [x] T4: Update `cairn/DESIGN.md`'s bullets "No tag moves back to an older recipe" and "A failed or missing rebuild opens an issue", including the startup-failure limit.
- [ ] T5: Run the drills, finished before the scheduled run of Monday 2026-11-09, which could close the drill issue. Use a throwaway branch `m012-drill`, never merged, with a temporary `push` trigger for that branch. Temporary edits for a green push run: widen `publish`'s `if` to admit the branch, hard-code `verdict=fresh`, and replace "Attach the tags" with an echo, because a push run has no `test_mode` and an unblocked step moves real tags. A drill run may stub the build legs and publish gates, because it tests the `notify` wiring. In order: (a) a planted-failure push run opens the issue, then read the label with `gh label list`; (b) a green push run leaves the issue; (c) a dispatch with `notify` set is cancelled while a leg builds; (d) a real `test_mode` dispatch with `notify` set on the milestone branch reads stale and leaves the issue; (e) a real `rebuild-gap.yml` dispatch on the milestone branch prints a date; (f) a forced-fresh `test_mode` dispatch with `notify` set closes the issue, with a real "Attach the tags" step. Then delete the drill branch and make sure that no moving tag changed.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: milestone — a change to running CI with a design choice, not a restore of documented behavior.
- 2026-11-05: idea vet: gap, the close rule: the question set chose scheduled runs only. gap, `keepalive`'s skip reads as a failure on a push run: reading taken drops it from the results on push. gap, a cancelled push run would raise a false alert: reading taken uses `!cancelled()`. gap, a startup failure starts no job: reading taken leaves it out, in a parked row. gap, an older failed push after a newer fix still alerts: reading taken accepts it, in a parked row. No flaw.
- 2026-11-05: lessons used: 2026-09-12 (M001) `always()` runs on a cancel; 2026-09-12 (M001, corrected M002) branch evidence needs a dispatch with `test_mode`; 2026-09-13 (M003) temporary branch push trigger; 2026-09-13 (M004) bash 3.2 and empty arrays.
- 2026-11-05: collision: M003, M004, and M005 are done and this extends them. Absorbed the row "Alert on a failed docker.yml push build" in full and the cancel clause of "Fix notify on cancels and dispatches". D-003 stands. Not the checker-regress shape, because the scripts report on CI runs and verify no repo-internal artifact.
- 2026-11-05: inbox sweep: 0 open issues, 0 open pull requests.
- 2026-11-05: evidence for the row: push run of `e32d2a6` on 2026-10-21 failed at the resolute amd64 build, `publish` failed its digest count, and `notify` was skipped, so no issue opened.
- 2026-11-05: question set: what closes the issue after a failed push build — a scheduled run only.
- 2026-11-05: question set: may the work run real drills on GitHub, with a throwaway branch, one real ci-failure issue opened and closed, and untagged images on Docker Hub — allowed, before the Monday 2026-11-09 scheduled run.
- 2026-11-05: criteria audit (full mode, fresh Opus reader): AC2's drill could not reach a green `publish` on a branch, fixed by T5's named temporary edits. "No failed job" conflicted with the skipped-is-failure rule, fixed by rewording AC1 and AC2 on results. AC3's "unedited" needs unset `RUN_EVENT` to act as scheduled and left dispatches unstated, both added. AC4 needs `needs.publish.result` beside the output, added. AC5 now states the pre-change limit and the no-such-step case. The cancel wording became "before `notify` starts". The site list gained `rebuild-gap.yml`, the input description, and the test header. Added AC6 for a fresh run still attaching. Cancel criterion folded into AC2 to keep seven.
- 2026-11-05: plan gate chose extending `notify` over a separate `workflow_run` alert workflow because `notify` and its test suite exist and the run's results are already in scope; falsified by a push build startup failure going unreported in practice.
- 2026-11-05: plan gate chose a step-level `if` on "Attach the tags", read through the job listing, over a marker in the run title or an artifact because the listing already carries step conclusions and `rebuild-gap.yml` already has `actions: read`; falsified by a stale run whose attach step reads anything but `skipped`.
- 2026-11-05: AC6 cannot show a real tag attach before merge. Review hygiene reads the merge's push build for attached tags and an untouched issue.
- 2026-11-05: T1 done. `ci-failure-issue.sh` reads `RUN_EVENT` and takes a `stale` result. The new suite cases failed (11 assertions) before the script change. A green push build returns before any `gh` call, so it does not even read the list.
- 2026-11-05: T2 done. `docker.yml` gives `publish` a `verdict` output, skips "Attach the tags" on a stale verdict, runs `notify` on push under `!cancelled()`, and leaves `keepalive` out of `RESULTS` on push. Offline, this is a YAML parse only; T5's runs test it.
- 2026-11-05: correction to the T2 line: the parse in that commit failed because PyYAML is missing, and the commit went in unparsed. The T3 commit's `ruby -ryaml` parse read the `if`, `RESULTS`, `outputs`, and step `if` as intended. The `notify` `if` is now flat, because folded YAML keeps line breaks on deeper-indented lines.
- 2026-11-05: T3 done. `last-success.sh` validates every candidate's `createdAt`, then walks newest first with `gh run view`. `rebuild-gap.yml` adds `databaseId`. Ten new assertions failed before the script change, and the suite passes under macOS bash 3.2. A real scheduled run's listing reads "Attach the tags" as `success`. `shellcheck` is not installed locally, so `lint.yml` on the pull request is its first run.
- 2026-11-05: T4 done. `cairn/DESIGN.md`'s stale-run and alert bullets state the rules, and the alert bullet is renamed "A failed build or a missing rebuild opens an issue".

## Decisions

## Review
