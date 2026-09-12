# M001: Smoke-test gate before any tag moves

**Status:** done (2026-09-12, PR #3 https://github.com/jmgirard/rocker-bayes/pull/3)

**Goal:** Every tag `.github/workflows/docker.yml` attaches points at an image
that was booted and exercised first.

**Outcome:** `.github/smoke-test.sh` boots an image and runs three phases. It
checks RStudio Server health. It asserts a bspm install landed as an apt
`r-cran-*` binary, through `dpkg -s`. It samples the conjugate Bernoulli
fixture in `.github/smoke-fixtures/` against its analytic mean. Each of the
four build legs pushes untagged, pulls the digest back, asserts
`{{.Architecture}}` and `uname -m`, smoke-tests it, then uploads it. One
publish job needs all four digests and checks both manifest lists with
`.github/publish-guard.sh`, driven locally by `tests/test_publish_guard.sh`.
A `test_mode` input runs the lane and attaches nothing.

**Decisions:** all-or-nothing publishing across four legs under GP4. Untagged
digests on every ref. A conjugate fixture, the guard as a locally tested
script, and the fixture in the repo rather than the image.

**Review:** three lenses, 29 findings, none meeting the return floor. Eleven
became candidates. Five were fixed: `always()` to `!cancelled()`, a guarded
health read, `set -euo pipefail` on the CmdStan grep, `SMOKE_PKG` out of R
source, and `needs: [build, publish]` on the inert `retry-on-failure`.
