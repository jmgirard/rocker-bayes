<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M012: Alert on a failed docker.yml push build

- **Status:** review
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

- [x] AC1: A `docker.yml` push run whose results include any value other than `success` or `cancelled` reports through the `ci-failure` issue. With no open issue it opens one titled `Push build failed: <failed jobs>`, or with the script's generic text where no job concluded `failure`. With an open issue it comments on the oldest one. Evidence: `test_ci_failure_issue.sh` cases for a failed build with a failed publish, a failed publish alone, a cancelled build beside a skipped publish, and an open issue; and one real push-event run on the drill branch with a planted failure that opens the issue.
- [x] AC2: A push run whose `build` and `publish` jobs both succeeded writes nothing to the issue, whether or not one is open. `keepalive`'s skip on a push run does not count as a failure. A `docker.yml` run cancelled before `notify` starts also writes nothing. Evidence: a `test_ci_failure_issue.sh` case for each open state; one real push-event run on the drill branch, made under T5's temporary edits, whose `notify` job passes and leaves the drill's open issue unchanged; and one real dispatch with `notify` set, cancelled while a leg builds, whose `notify` job shows `skipped` or `cancelled` with no step run.
- [x] AC3: Scheduled runs and dispatches with `notify` set keep their rule and wording. With `RUN_EVENT` unset, `schedule`, or `workflow_dispatch`, a failed job opens or comments on the issue with the `Weekly run failed` wording, and a fully green fresh run closes it. Evidence: the existing `test_ci_failure_issue.sh` cases passing unedited; new cases for the `schedule` and `workflow_dispatch` values; and one real forced-fresh `test_mode` dispatch with `notify` set on the drill branch that closes the drill's issue.
- [x] AC4: A run whose `fresh` step reads `stale` and whose `publish` job succeeded attaches no tag, ends green, and neither opens, comments on, nor closes the issue. If `keepalive` failed in that run, the failure reports as usual. Evidence: `test_ci_failure_issue.sh` cases for `success stale success` and `success stale failure`; and one real `test_mode` dispatch with `notify` set on the milestone branch, whose publish log shows the stale verdict, whose "Attach the tags" step shows `skipped`, and which leaves the drill's open issue unchanged.
- [x] AC5: For runs after this change, `last-success.sh` prints the date of the newest successful scheduled run whose "Attach the tags" step succeeded, so a stale run does not count as a rebuild. A readable job listing with no such step does not count, and the script goes on to the next older run. A job listing it reaches and cannot read makes it print `unknown`. Evidence: `test_last_success.sh` cases with a stubbed `gh`; and one real `rebuild-gap.yml` dispatch on the milestone branch that prints a date looked up from the real run history.
- [x] AC6: A run whose verdict is `fresh` runs its "Attach the tags" step: in test mode the step prints its test-mode line, and otherwise it attaches the tags. Evidence: the forced-fresh `test_mode` dispatch of AC3, whose step shows `success` and prints the test-mode line.
- [ ] AC7: These sites state the rules above: `cairn/DESIGN.md`'s alert and stale-run bullets; the comments in `docker.yml` and `rebuild-gap.yml`; the `notify` input description in `docker.yml`; and the headers of `ci-failure-issue.sh`, `last-success.sh`, and `test_last_success.sh`. The `ci-failure` label description names push builds. Evidence: a read of each site in the diff; `gh label list` after AC1's drill; and `pr-ci.yml`'s script suites and `lint.yml` passing on the pull request.

## Coverage

- AC1 → T1, T2, T5
- AC2 → T1, T2, T5
- AC3 → T1, T5
- AC4 → T1, T2, T5
- AC5 → T3, T5, T6
- AC6 → T2, T5
- AC7 → T1, T3, T4, T5, T6

## Tasks

- [x] T1: In `.github/ci-failure-issue.sh`, read `RUN_EVENT`, tests first. On `push`, a failure uses the `Push build failed` wording, and a success writes nothing and prints a line. Unset or any other value keeps today's wording. Add a `stale` result: it counts as a failure beside a failed job, and otherwise opens and closes nothing. Update the header and the label description.
- [x] T2: In `.github/workflows/docker.yml`: give `publish` a job output carrying the verdict; add a step-level `if` on the verdict to "Attach the tags" and remove the step's own stale branch; change the `notify` gate to `!cancelled()` and add `push`; pass `RUN_EVENT`; drop `keepalive` from `RESULTS` on a push run; pass `stale` for `publish` only when the verdict is `stale` and `needs.publish.result` is `success`. Update the comments and the `notify` input description.
- [x] T3: In `.github/last-success.sh`, walk the successful scheduled runs newest first and read each one's job listing with `gh run view` until one has "Attach the tags" at `success`, tests first. In `rebuild-gap.yml`, add `databaseId` to the run list. Update the headers and comments. The existing `test_last_success.sh` cases gain a stub.
- [x] T4: Update `cairn/DESIGN.md`'s bullets "No tag moves back to an older recipe" and "A failed or missing rebuild opens an issue", including the startup-failure limit.
- [x] T5: Run the drills, finished before the scheduled run of Monday 2026-11-09, which could close the drill issue. Use a throwaway branch `m012-drill`, never merged, with a temporary `push` trigger for that branch. Temporary edits for a green push run: widen `publish`'s `if` to admit the branch, hard-code `verdict=fresh`, and replace "Attach the tags" with an echo, because a push run has no `test_mode` and an unblocked step moves real tags. A drill run may stub the build legs and publish gates, because it tests the `notify` wiring. In order: (a) a planted-failure push run opens the issue, then read the label with `gh label list`; (b) a green push run leaves the issue; (c) a dispatch with `notify` set is cancelled while a leg builds; (d) a real `test_mode` dispatch with `notify` set on the milestone branch reads stale and leaves the issue; (e) a real `rebuild-gap.yml` dispatch on the milestone branch prints a date; (f) a forced-fresh `test_mode` dispatch with `notify` set closes the issue, with a real "Attach the tags" step. Then delete the drill branch and make sure that no moving tag changed.
- [x] T6: Fix review return 1. In `last-success.sh`, make a listing jq cannot process print `unknown`, with a regression case, and give `gh` no stdin. Apply the fix-now items in the Review section: the attempt-2 text in `docker.yml` and `DESIGN.md`, the `rebuild-gap.yml` wording, the `subject` doc, and the tests the rulebook excludes.

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
- 2026-11-05: T5 (a) run 41985336542, push event, planted failure in all four legs, publish skipped, keepalive skipped: notify opened #25 titled `Push build failed: noble resolute`. `gh label list` shows the new description.
- 2026-11-05: T5 (b) run 41985463784, push event, real four legs and publish gates, verdict forced fresh, attach replaced by an echo: `RESULTS: build=success publish=success`, notify printed its fully-green line, #25 unchanged. keepalive shows skipped.
- 2026-11-05: T5 (c) run 41985502132, dispatch with `notify`, cancelled while the legs built: notify shows `cancelled` with no step run.
- 2026-11-05: T5 (d) run 41985546164, real `test_mode` dispatch with `notify` on the milestone branch: publish logged the stale line, "Attach the tags" shows `skipped`, `RESULTS: build=success publish=stale keepalive=success`, notify printed "the run was stale", #25 had 0 comments and stayed open.
- 2026-11-05: T5 (e) run 41985549613, `rebuild-gap.yml` dispatch on the milestone branch: looked up 2026-11-02, the newest scheduled run, 3 days, no alert.
- 2026-11-05: T5 (f) run 41986937699, forced-fresh `test_mode` dispatch with `notify` and no push trigger: "Attach the tags" shows `success` and printed the test-mode line, and notify closed #25. Its close comment says "The scheduled run was fully green" on a dispatch, the wording the row "Fix notify on cancels and dispatches" keeps.
- 2026-11-05: T5 done. `m012-drill` deleted, never merged. `latest` (`sha256:2511d73a…`) and `resolute` (`sha256:783ea7b6…`) read the same digests before and after the drills. No `ci-failure` issue is open.
- 2026-11-05: claim audit: 75 claims read, 13 corrected — .github/ci-failure-issue.sh, .github/last-success.sh, .github/rebuild-gap.sh, .github/workflows/docker.yml, .github/workflows/rebuild-gap.yml, cairn/DESIGN.md. All 13 were text, no behavior. The issue body now says "scheduled run that moves the tags".
- 2026-11-05: claim audit re-read: all 13 hold. The issue body still omits that a `notify` dispatch can close the issue, left for the row "Fix notify on cancels and dispatches", which already names that text.
- 2026-11-05: review return 1: AC5 fails: a job listing that jq cannot process, `{"jobs":[{"steps":["oops"]}]}`, makes `last-success.sh` go on to the next run and print `none` instead of `unknown` (diff-bug #6). The return also carries the fix-now items in the Review section.
- 2026-11-05: throwaway branch `m012-drill2`, deleted, run 41989546885 settled diff-bug #1: `notify` runs after a leg timeout. Its notify step only echoed, so it wrote no issue.
- 2026-11-05: T6 done. `last-success.sh` reads a listing with one `jq` that stops on anything but a job listing, so `{"jobs":[{"steps":["oops"]}]}` prints `unknown`. `{"jobs":[]}` stays readable with no such step and is passed over: a completed run with no jobs has not been seen. Tests cut per the Review section's fix-now lines; the assertion pinned to the new issue body.
- 2026-11-05: claim audit: 14 claims read, 2 corrected — .github/last-success.sh, cairn/DESIGN.md. The first was a behavior gap: an empty `gh` answer printed nothing from `jq`, and the run was passed over. It now prints `unknown`, with a new case. The re-read is my own run of the suite plus the corrected lines' text, since each is one line and the reader's fix is taken as written.
- 2026-11-05: review return 1 handed back. `rebuild-gap.yml` dispatch 41990064067 on `15c4f73` looked up 2026-11-02 with no alert.

## Decisions

## Review

Pass 1, branch head `1dc7ed0`, 2026-11-05. Since the drills' commit `f2cc9b4`, non-comment changes under `.github` are two message strings in `ci-failure-issue.sh`.

- AC1: `test_ci_failure_issue.sh` passes; cases 7a to 7d cover a failed leg with failed publish, publish alone, a cancelled leg beside a skipped publish, and an open issue. Run 41985336542, push event, opened #25 titled `Push build failed: noble resolute`. Pass.
- AC2: case 7e covers each open state and logs no `gh` call. Run 41985463784, push event: publish and notify `success`, keepalive `skipped`, its log shows `RESULTS: build=success publish=success` and the green line, and #25 stayed open with 0 comments until run 41986937699 closed it. Run 41985502132, dispatch with `notify`, cancelled: notify `cancelled`, no step listed. Pass.
- AC3: the diff of `test_ci_failure_issue.sh` removes only 3 header comment lines, so the existing cases are unedited, and they pass. Case 9 covers `schedule` and `workflow_dispatch`. Run 41986937699, forced-fresh `test_mode` dispatch with `notify`: notify closed #25 (closed 2026-11-05T07:31:19Z). Pass.
- AC4: cases 8a to 8c cover `success stale success`, `success stale` on push, and `success stale failure`. Run 41985546164, `test_mode` dispatch with `notify` on the milestone branch: publish logged the stale line, "Attach the tags" `skipped`, run `success`, `RESULTS: build=success publish=stale keepalive=success`, and #25 kept 0 comments and stayed open. Pass.
- AC5: `test_last_success.sh` passes, cases 7 to 12 with a stubbed `gh` cover a stale run, all stale, no such step, a failed read, an unreadable listing, no run id, and the walk stopping early. Run 41985549613, `rebuild-gap.yml` dispatch on the milestone branch: looked up 2026-11-02, 3 days, no alert. Pass.
- AC6: run 41986937699: "Attach the tags" `success`, printed "test mode: both manifest lists were assembled and checked, and no tag was attached". `latest` (`sha256:2511d73a…`) and `resolute` (`sha256:783ea7b6…`) read the same digests as before the drills. Pass.
- AC7, part read now: each named site states the rules in the diff; `gh label list` shows "Opened when a scheduled run or push build fails, or no scheduled rebuild has succeeded lately". All eight offline suites pass locally, and `shellcheck -x -S info` v0.11.0 over the tracked shell files exits 0 in a container. The box stays open until `pr-ci.yml` and `lint.yml` pass on the pull request, at step 8's CI wait.
- Gate: `cairn_validate` passes; no principle text changed, so `cairn_impact` is skipped; `hadolint Dockerfile` exits 0 (container); base image `jmgirard/rstudio2u:${BASE_TAG}` with `noble`; no secret word in the Dockerfile; `.dockerignore` present; the diff touches no build context file; no changelog file (PROFILE); no snapshot file changed.
- Gate, build: local `docker build` of the branch exits 0.

spawned: diff-bug, blame-history, prior-review, ripple

- diff-bug #1: the timed-out leg path never ran, and `!cancelled()` could lose the alert — reject, false: run 41989546885, a throwaway dispatch with a one-minute leg timeout, shows all four legs `cancelled`, publish `skipped`, notify `success`, results `cancelled skipped success`, which the script reports as a failure.
- diff-bug #2: `DESIGN.md:164` and `docker.yml:452` say a green attempt 2 closes the issue, and a stale one does not — fix now.
- diff-bug #3: `rebuild-gap.yml:5,26,46` and `rebuild-gap.sh` wording still says "last succeeded" — fix now for the `rebuild-gap.yml` comment and input description, which AC7 names; the rest stays, because a stale run is not a rebuild, so "no successful rebuild" still holds.
- diff-bug #4: a `test_mode` dispatch moves no tag yet closes the issue, unlike a stale run — follow-up, absorbed into "Fix notify on cancels and dispatches" (low: AC3 keeps today's dispatch rule).
- diff-bug #5: a cancelled publish on a push run reports nothing — follow-up, new row "Report a cancelled publish job" (parked: needs publish to hit the 6-hour limit after four green legs).
- diff-bug #6: `{"jobs":[{"steps":["oops"]}]}` makes jq fail inside the `if`, so the walk passes over it and prints `none` — fix now, floor return: it shows AC5 failing.
- diff-bug #7: only a run's latest attempt is read — reject, edge: needs a by-hand "rerun all" of a green scheduled run, outside documented use; the effect is a wider measured gap and an alert.
- diff-bug #8: a by-hand `--failed` rerun's reuse of publish's verdict output is undrilled — follow-up, absorbed into "Fix notify on cancels and dispatches" (low: `rebuild-retry` reruns only mirror failures, and a stale run has none).
- diff-bug #9: two overlapping failed push runs can open two issues — follow-up, absorbed into "Quiet alerts from superseded push builds" (parked: a green scheduled run closes both).
- diff-bug #10: one failed read on a Tuesday opens "Could not read" — reject, planned change: AC5 asks for `unknown`.
- diff-bug #11: `gh` inherits the loop's here-string as stdin — fix now, `</dev/null`.
- diff-bug #12: the ROADMAP row still names `always()` — reject, planned change: step 9 narrows that row.
- diff-bug #13: comment wraps — reject, style.
- diff-bug #14: stale with no open issue repeats the stale code path — fix now, remove.
- diff-bug #15: stale on push repeats 8a's path — fix now, remove.
- diff-bug #16: the second `success stale failure` run repeats aggregation — fix now, remove.
- diff-bug #17: the `workflow_dispatch` pass repeats `schedule` — reject, planned change: AC3 names both values.
- diff-bug #18: green push with no open issue repeats the open state — reject, planned change: AC2 names each open state.
- diff-bug #19: publish-only failure repeats 7a's path — reject, planned change: AC1 names it.
- diff-bug #20: a weaker expectation after exact title and body matches — fix now, remove.
- diff-bug #21: the body assertion passes on the old text — fix now, pin "that moves the tags".
- diff-bug #22: "not newest first" passes without the sort — fix now, remove.
- diff-bug #23: case 12 repeats case 1's sort path — fix now, remove.
- diff-bug #24: two inputs reach one `jq` guard — fix now, keep the non-JSON case and add the malformed case from #6.
- diff-bug #25: no-step listing shares a path with skipped-step — reject, planned change: AC5 names it.
- diff-bug #26: the exact-calls check repeats what `expect` proved — fix now, remove it and the stub's log.
- diff-bug #27: the `any_stale` branch is unasserted — fix now, assert the printed line.
- diff-bug #28: `lint.yml` has not run — reject, false for shellcheck: v0.11.0 with `-x -S info` exits 0 over the tracked shell files; `lint.yml` itself runs at step 8 under AC7.
- blame-history #1: a run cancelled after a failed leg reports nothing — reject, planned change: AC2.
- blame-history #2: pre-change stale runs can mask a missing rebuild until they leave the 100-run window — reject, false: the script returns that run's date, and the gap grows from it.
- blame-history #3: the step name is load-bearing — reject, planned change: the header and the `docker.yml` comment state it, and it fails loud.
- blame-history #4: the stale log line left "Attach the tags" — reject, planned change: the `fresh` step's warning says it.
- blame-history #5: a branch dispatch with `notify` and no `test_mode` opens an issue — follow-up, already in "Fix notify on cancels and dispatches".
- blame-history #6: an empty `createdAt` shifts tab-split fields — reject, edge: GitHub returns no such run, and the output is still `unknown`.
- blame-history #7: a push failure stays open up to seven days — reject, planned change: the user's answer at the question set.
- blame-history #8: up to 100 listing reads — reject, edge: only a renamed step walks the whole list; the effect is slow running.
- prior-review #1: a timed-out leg now opens an issue on push — reject, planned change: AC1.
- prior-review #2: `docker.yml`'s paths omit `ci-failure-issue.sh` although `notify` now runs on push — reject, false: each run reads the script from its own commit, and `pr-ci.yml` tests it. A rebuild for a script-only edit would move tags for nothing, the D-003 reasoning.
- prior-review #3: the issue body names only scheduled runs — follow-up, already in "Fix notify on cancels and dispatches".
- prior-review #4: pre-change stale runs still count — reject, planned change: AC5 states it.
- ripple #1: the M012 row describes old behavior — reject, planned change: step 9 graduates it.
- ripple #2: the "Fix notify" row names `always()` — reject, planned change: step 9 narrows it.
- ripple #3: same as diff-bug #2 — fix now.
- ripple #4: same as prior-review #3 — follow-up, already in that row.
- ripple #5: "Stop false gap alerts from keepalive" says only green scheduled runs count — fix now.
- ripple #6: "The scheduled run was fully green" prints on a dispatch — follow-up, already in "Fix notify on cancels and dispatches".
- ripple #7: the `subject` doc names only the weekly wording — fix now.
- ripple #8: same as diff-bug #3 — fix now for the same sites.
- ripple #9: "Quiet alerts" omits that a `notify` dispatch also closes — fix now.
- Pass 1 fix-now lines above: fixed in `15c4f73` and `c266b4f`; pass 1's ROADMAP edits are in `bfae8ac`.

Pass 2, branch head `c266b4f`, 2026-11-05. AC1 to AC4 and AC6 keep their pass 1 runs, because the changes since touch comments, messages, and test cases on those paths.

- AC5, pass 2: `test_last_success.sh` passes with the regression case for `{"jobs":[{"steps":["oops"]}]}`, which fails on the pass 1 script (it printed `2026-09-28`). `rebuild-gap.yml` dispatch 41990325749 on `c266b4f` looked up 2026-11-02, 3 days, no alert. Holds; re-read after this pass's fix below.
- Gate, pass 2: `cairn_validate` passes; `hadolint` and `shellcheck -x -S info` v0.11.0 exit 0; all eight suites pass; `origin/main` is an ancestor of the branch; no open PR, so the feature cap is clear.

spawned: diff-bug, blame-history, prior-review, ripple

- diff-bug #1: T6's `.jobs[]` change has no test, since T6 cut `{"message":"Not Found"}`, and this refutes pass 1's reason for #24 — fix now, restore that case.
- diff-bug #2: `{"jobs":{"a":{"steps":[…success…]}}}` counts as a rebuild, and `{"jobs":{}}` prints `none` — fix now, require `.jobs` to be a list. AC5 holds as written, since jq reads these as listings, so this is not a return.
- diff-bug #3: the "contradiction" warning fires on a timed-out leg, a documented path — fix now, reword the comment and warning.
- diff-bug #4: the `<html>` case runs the same path as the `oops` case — fix now, remove.
- diff-bug #5: `... and closes nothing` pins nothing this change could break — fix now, remove.
- diff-bug #6: `assert_out 'the run was stale'` is close to cosmetic — reject, planned change: the rulebook tests each branch a change adds, and this branch's only effect is that line.
- diff-bug #7: `</dev/null` has no test — reject, false: `gh run view` does not read stdin, so the line is hardening with no defect to regress.
- diff-bug #8: `.steps[]?` is unpinned — reject, edge: no listing with null `steps` has been seen; the effect is an `unknown` alert either way only if GitHub changes shape.
- diff-bug #9: "neither opens nor closes … unless another job failed" reads as though a failure could close — fix now, in `DESIGN.md` and `docker.yml`.
- diff-bug #10: the `docker.yml` comment says last-success reads "skipped", and it looks only for `success` — fix now.
- diff-bug #11: repeated `assert_rc` lines — reject, style: the file's convention.
- diff-bug #12: line wraps — reject, style.
- blame-history #1: "The push build failed again" on an issue a scheduled run opened — fix now, "A push build failed in".
- blame-history #2: a run cancelled after a failed leg reports nothing — reject, planned change: AC2, as pass 1.
- prior-review #1: a timed-out leg on a push opens an issue — reject, planned change: AC1, and the script's case 6e already states the rule.
- prior-review #2: a failed `gh issue list` reads as "none open" on push runs too — follow-up, already in "Make alert scripts fail loudly".
- prior-review #3: M003 S1's reason no longer holds — reject, false: pass 1's prior-review #2 records the current reason.
- prior-review #4: a failed `notify` raises no issue on push runs too — follow-up, already in "Make alert scripts fail loudly".
- prior-review #5: pre-change stale runs can pull the alert's start forward, against pass 1's blame-history #2 — reject, planned change: AC5 states the limit, and that reviewer's read of the last six scheduled runs found no stale line.
- prior-review #6: a keepalive failure hides a run that moved tags — follow-up, already in "Stop false gap alerts from keepalive".
- prior-review #7: a long DESIGN line — reject, style.
- ripple #1: `test_rebuild_gap.sh:199` comment says "no successful scheduled run" — fix now.
- ripple #2: other "succeeded" wording — reject, same reason as pass 1's diff-bug #3.
- ripple #3: the two ROADMAP rows — reject, planned change: step 9.
- ripple #4: `DESIGN.md`'s alert bullet omits a dispatch with `notify` — fix now.
- Pass 2 fix-now lines above: fixed in `b88b9f8`.
- AC5, after the fix: `{"jobs":{}}` and `{"jobs":{"a":…}}` print `unknown`, `{"jobs":[]}` prints `none`, a real-shaped listing prints its date, under a stub. `rebuild-gap.yml` dispatch 41991400832 on `b88b9f8` looked up 2026-11-02, 3 days, no alert. All eight suites pass, and shellcheck exits 0.
- Snapshot files: the list is empty. Amendments: none; the work log carries no substantive amendment.
