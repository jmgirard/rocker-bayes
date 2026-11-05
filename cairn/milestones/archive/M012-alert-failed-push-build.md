# M012: Alert on a failed docker.yml push build

**Status:** done (2026-11-05, PR #26 https://github.com/jmgirard/rocker-bayes/pull/26)

**Goal:** A failed `docker.yml` push build reports through the `ci-failure` issue, and a stale run no longer closes that issue or counts as a rebuild.

**Outcome:** `notify` runs on push under `!cancelled()`, with `keepalive` left out of `RESULTS` on push and the event passed as `RUN_EVENT`. `.github/ci-failure-issue.sh` titles a push failure `Push build failed: <jobs>`, and a green push build makes no `gh` call. `publish` has a `verdict` output, and `notify` passes `stale` when that output is stale and the job succeeded. The script opens and closes nothing on `stale`. "Attach the tags" has a step-level `if` on the verdict, so it is skipped on a stale run. `.github/last-success.sh` walks successful scheduled runs newest first with `gh run view`, and counts the first whose "Attach the tags" step succeeded. A listing it cannot read prints `unknown`. Stale runs from before this change show that step as a success and still count. A push run that fails at startup starts no job, so `notify` cannot report it.

**Decisions:** extend `notify` over a separate `workflow_run` alert workflow. Read the step conclusion through the job listing over a run-title marker or an artifact. Only a scheduled run or a `notify` dispatch closes the issue, by the user's answer at the question set.

**Review:** two passes, four lenses each, 74 findings: 29 fixed, 11 to follow-up, 34 rejected, 4 of those `edge`. One return, on AC5: a malformed listing printed a date or `none`. A throwaway run with a one-minute leg timeout showed `notify` still runs and the alert stays. Real runs on `m012-drill` covered each criterion. The merge's push run 42036438318 read `fresh`, attached the tags, and wrote nothing to the issue.

Graduated "Alert on a failed docker.yml push build". Narrowed "Fix notify on cancels and dispatches" to its dispatch clauses. New parked rows: "Alert on a docker.yml startup failure", "Quiet alerts from superseded push builds", "Report a cancelled publish job". Lessons evicted by rank at the 25 limit: 2026-09-12 (M001) on `gh run rerun` from inside a run, 2026-09-12 (M001) on `set -e` and command substitution. Pruned the M009 row.
