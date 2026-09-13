# M003: Unattended-rebuild alerts and schedule keepalive

**Status:** done (2026-09-13, PR #11 https://github.com/jmgirard/rocker-bayes/pull/11)

**Goal:** A weekly rebuild that fails, and a weekly rebuild that silently stops
happening, both report themselves.

**Outcome:** `docker.yml` gains a `notify` job that runs `.github/ci-failure-issue.sh`
on every scheduled attempt (or a dispatch with `notify`). It opens, comments on,
or closes one `ci-failure` issue. `.github/workflows/rebuild-gap.yml` runs
Tuesdays and raises the issue past an 8-day gap (`.github/rebuild-gap.sh`). A
`keepalive` job pushes an empty commit with the `KEEPALIVE_DEPLOY_KEY` deploy key
after 50 quiet days (`.github/keepalive.sh`, `.github/date-lib.sh`). No job grants
`contents: write`. `retry-on-failure` is removed, because GitHub refuses a rerun
requested from inside the same run. `pr-ci.yml` runs the three suites.

**Decisions:** a temporary branch push trigger for the gap runs, 8-day gap bound,
permanent `keepalive_threshold` and `notify` dispatch inputs. AC5 narrowed at
return 1 to drop the retry, by user decision.

**Review:** two passes. Pass 1 returned on AC5 (the rerun GitHub refuses). Pass 2
had three lenses and 19 findings, none on the return floor. N2 (DESIGN suite count)
was fixed. The retry row was promoted with N1. Three new candidate rows cover
keepalive, quiet alert failures, and dispatch side effects. N5 and P2 joined
existing rows. S1 and N8 were rejected. The M001 rerun lesson was corrected.
