# M004: Rerun a weekly build that failed on the r2u mirror

**Status:** done (2026-09-13, PR #12 https://github.com/jmgirard/rocker-bayes/pull/12)

**Goal:** A scheduled rebuild reruns its failed jobs once, unattended, when its
first attempt failed only because a build leg could not reach the r2u mirror.

**Outcome:** When a `docker.yml` run completes, `workflow_run` starts
`.github/workflows/rebuild-retry.yml`, which runs `.github/retry-decision.sh`.
The script calls `gh run rerun <id> --failed` once for a scheduled attempt 1
that failed. Every failed build leg must fail at its build step with
`Command still failing after` in its job log. The only other allowed failure
is publish at its digest count. `.github/tests/test_retry_decision.sh` tests the rule offline,
and `pr-ci.yml` runs it. A branch drill showed a failed-jobs rerun rebuilds
only the failed leg and passes the publish gates. Comments in
`install_bayes.sh` and `docker.yml` and DESIGN.md describe the rerun.

**Decisions:** a separate `workflow_run` workflow over a longer in-build retry.
The mirror symptom is the build step plus the give-up log line. Scheduled runs
only. Attempt 1 still opens the issue. Leg logs are read through the job-log API.

**Review:** one pass, three lenses, 8 diff findings and 2 history notes, none
on the return floor. O6 (three untested decline branches) was fixed. O1
(no `concurrency` group) is a new candidate row. O2 and O7 joined existing
rows. O3, O4, O5, and O8 were rejected. No lesson was retired.
