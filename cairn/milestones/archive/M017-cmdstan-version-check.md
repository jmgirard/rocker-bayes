# M017: Check CmdStan matches the version tag

**Status:** done (2026-11-05, PR #32 https://github.com/jmgirard/rocker-bayes/pull/32)

**Goal:** Smoke phase 3 fails when the image's CmdStan is not the version that the Dockerfile pins.

**Outcome:** `.github/smoke-test.sh` reads an expected CmdStan version
before its Stan-file check: `SMOKE_CMDSTAN_VERSION` when set and non-empty,
else the `ARG CMDSTAN_VERSION` line of `${SCRIPT_DIR}/../Dockerfile` (the
`test_cmdstan_pin.sh` sed pattern). A missing Dockerfile or a value that is
not `x.y.z` fails before boot. Phase 3 captures its first R block (stdout and
stderr), parses the trimmed `cmdstan version:` line from
`cmdstanr::cmdstan_version()`, and fails on a mismatch with a line naming
both versions and the source. The PASS line names the version. The header,
DESIGN.md, and the Dockerfile's build-arg example describe the check;
docker.yml and pr-ci.yml are unchanged. Two local passes ran 5 cases.

**Decisions:** the script reads the Dockerfile pin, with an env override,
rather than docker.yml passing the pin in; no test-mode dispatch (plan gate).

**Review:** four lenses, 19 findings: 3 fixed in d0d3ac5 (stderr in the
capture, "set and non-empty" in DESIGN.md, Dockerfile note), 1 follow-up,
2 noted, 13 rejected (2 edge: two ARG lines, a symlinked copy). New parked
row "Vary the stale CmdStan in smoke phase 4". Graduated "Check CmdStan
matches the version tag". Pruned the M014 ROADMAP row.
