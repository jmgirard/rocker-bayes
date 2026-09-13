# M005: Superseded CI runs stop acting

**Status:** done (2026-09-13, PR #14 https://github.com/jmgirard/rocker-bayes/pull/14)

**Goal:** A CI run that a newer commit made obsolete stops acting: an older
`docker.yml` run attaches no tag over a newer recipe, and an older pull
request run is cancelled.

**Outcome:** `.github/publish-guard.sh` gained `paths`, which prints a workflow's
push `paths` filter. It also gained `fresh`, which fetches the default branch
tip at depth 1 and diffs it with the run's commit over those paths. The `docker.yml` publish job
runs `fresh` before "Attach the tags", and reads the branch name from
`git ls-remote --symref origin HEAD`. A difference attaches no tag, warns, and
ends green. A fetch failure or an empty branch name fails the job.
`.dockerignore` joined the push filter. `pr-ci.yml` and `lint.yml` cancel older
runs per pull request, and `script-tests` runs `test_publish_guard.sh`.
DESIGN.md records the rule as an exception to GP2.

**Decisions:** a publish-time check, not a concurrency group or a retry
decline. A refusal ends green. Superseded push builds are not cancelled.

**Review:** two passes, three lenses each. Pass 1 O1 was a defect return,
fixed as T7. The step read the branch name from `github.event.repository`,
which reports say is empty on scheduled runs. O2 to O7 and pass 2 Q1, Q3, Q4 went to candidate rows. O8 and Q2
were rejected. No lesson was retired.
