# M002: Pre-merge CI lane and lint

**Status:** done (2026-09-12, PR #6 https://github.com/jmgirard/rocker-bayes/pull/6)

**Goal:** A pull request builds the image, boots it, and lints the Dockerfile
and the shell files before anyone merges it.

**Outcome:** `.github/workflows/pr-ci.yml` triggers on the Dockerfile,
`.dockerignore`, `scripts/**`, the workflows, and the smoke test and its
fixtures. It runs hadolint, builds noble amd64 with `load: true` and
`pull: true`, and runs `.github/smoke-test.sh` on the loaded tag. It never logs
in, pins `contents: read`, and reads the `noble-amd64` cache without writing
it. `.github/workflows/lint.yml` runs a SHA256-pinned shellcheck 0.11.0 at
`-S info` over one `git ls-files` list, and an empty list fails.
`.github/dependabot.yml` groups action bumps monthly. The new linter found an
unquoted `CMDSTAN_VERSION` in `scripts/install_bayes.sh`, now quoted.

**Decisions:** one noble amd64 build before merge rather than four legs.
Dependabot over a hand bump. The SC2086 fixed, not suppressed. New workflows
pinned at `docker.yml`'s existing action versions.

**Review:** three lenses, 24 findings, none meeting the return floor. Six fixed:
trigger paths for fixtures and `.dockerignore`, `contents: read`, a smoke step
timeout, `pull: true`, `curl --fail`, and an overstated DESIGN bullet. Six
became candidates. A misstated work-log line was superseded.
