# M017: Check CmdStan matches the version tag

- **Status:** in-progress
- **Priority:** low
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3, GP8, IP4
- **Resolves:** —
- **Surface tier:** user-facing — a publish gate whose failure holds back the tags users pull
- **Branch/PR:** m017-cmdstan-version-check

## Goal

Smoke phase 3 fails when the image's CmdStan is not the version that the Dockerfile pins.

## Scope

**In:** `.github/smoke-test.sh` reads an expected CmdStan version at start,
before its Stan-file check. The value is `SMOKE_CMDSTAN_VERSION` when that is
set and non-empty, else the `ARG CMDSTAN_VERSION="x.y.z"` line of the
Dockerfile in the parent of the script's own directory, read with the `sed`
pattern of `.github/tests/test_cmdstan_pin.sh`. A value that is not `x.y.z`
fails the run before any container starts, and a bad env value never falls
back to the Dockerfile. Phase 3 compares that value, by exact string after
trimming whitespace, with the version that `cmdstanr::cmdstan_version()`
returns in the phase 1 container. The comparison runs in bash on the parsed
output, with its own FAIL line. The header comment and DESIGN.md describe the
check.

**Out:**
- `docker.yml` and `pr-ci.yml` stay as they are. Both run the script from a
  checkout whose Dockerfile built the image, so the script reads the same pin
  that docker.yml greps for the build arg and the tag. No test-mode dispatch
  runs; `pr-ci.yml` runs the changed script on the PR.
- A pre-release pin (such as `2.36.0-rc1`) fails the read, as it already
  fails `test_cmdstan_pin.sh`. Supporting one is not planned; no row holds it.
- Host-port probe → candidate row "Probe the host port in smoke phase 1".

## Acceptance criteria

- [ ] AC1: With `SMOKE_CMDSTAN_VERSION` unset and port 8787 free,
      `bash .github/smoke-test.sh rocker-bayes:dev`, run from the repo root
      against a local build of the branch's Dockerfile, exits 0, and its
      phase 3 PASS line names the CmdStan version that phase compared, which
      equals the Dockerfile's `ARG CMDSTAN_VERSION` value.
- [ ] AC2: Against the same image, two mismatch runs each exit non-zero,
      print a `FAIL: phase 3 (cmdstan)` line that names the expected version
      and the version `cmdstanr::cmdstan_version()` reported, and print no
      `PASS: phase 3` line: (a) `SMOKE_CMDSTAN_VERSION=2.39.0`; (b)
      `SMOKE_CMDSTAN_VERSION` unset, with a copy of `.github/` run beside a
      copy of the Dockerfile whose pin reads `2.39.0`, both in a directory
      inside the repo checkout.
- [ ] AC3: Two bad-pin runs each exit non-zero with a FAIL line saying the
      expected CmdStan version could not be read or is not `x.y.z`, and print
      no `==> booting` line: (a) `SMOKE_CMDSTAN_VERSION` unset, with a copy of
      the script in a directory whose parent holds no Dockerfile; (b)
      `SMOKE_CMDSTAN_VERSION=2.40`.
- [ ] AC4: In phase 3, the image's version is the value that
      `cmdstanr::cmdstan_version()` returns in the phase 1 container. Phase
      3 reads no container environment variable and does not parse the
      version from `cmdstan_path()`, as a read of the phase 3 block shows.
- [ ] AC5: The header comment of `.github/smoke-test.sh` lists
      `SMOKE_CMDSTAN_VERSION` and its default among the other `SMOKE_*`
      variables, and its phase 3 text says the phase fails when the reported
      version differs from the expected one. DESIGN.md's CI paragraph says
      phase 3 fails when cmdstanr's CmdStan version differs from the
      Dockerfile pin.
- [ ] AC6: `docker build -t rocker-bayes:dev .` succeeds, and
      `koalaman/shellcheck:v0.11.0` (the version `lint.yml` pins) at
      `-S info` reports nothing for `.github/smoke-test.sh`.

## Coverage

- AC1 → T2, T3
- AC2 → T2, T3
- AC3 → T1, T3
- AC4 → T2
- AC5 → T1, T4
- AC6 → T3

## Tasks

- [x] T1: In `.github/smoke-test.sh`, read the expected version before the
      Stan-file check (lines 67-68): env value, else the Dockerfile at
      `${SCRIPT_DIR}/../Dockerfile`; fail on a missing or non-`x.y.z` value
      with a FAIL line naming the cause. List `SMOKE_CMDSTAN_VERSION` in the
      header (lines 33-45) and extend the phase 3 description (lines 11-21).
- [x] T2: In phase 3 (lines 240-256), capture the `cmdstan_version()` output,
      trim it, and compare it in bash with the expected version. Print its
      own FAIL line naming both values, and add the version to the phase 3
      PASS line (line 420). Keep R comments inside the single-quoted
      `Rscript -e` free of apostrophes.
- [x] T3: Build `rocker-bayes:dev`, run AC1, AC2 (a, b), and AC3 (a, b), and
      run shellcheck 0.11.0 through its image on the script. Put the copies
      for AC2 (b) and AC3 (a) in a directory inside the checkout, because
      Docker Desktop does not share `/tmp`, and remove them after.
- [x] T4: Add the check to DESIGN.md's CI paragraph (`cairn/DESIGN.md:55-75`).

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: not run — work named at the question set.
- 2026-11-05: question set: what to work on — "Check CmdStan matches the version tag" (the three normal-rung rows change rstudio2u and stay for that repo's plan).
- 2026-11-05: idea vet: gap — the row says the pin is "passed in from CI"; reading taken: the script reads the Dockerfile itself with an env override, which gives the same user-visible result (a mismatched leg fails and holds the tags). No flaw.
- 2026-11-05: collision check: absorbs candidate row "Check CmdStan matches the version tag" (M008 plan gate); M008, M014, M015, D-002, D-006 checked, none overlaps or rejects. Inbox sweep: 0 open issues, 0 open PRs.
- 2026-11-05: lessons used: 2026-11-05 (M011) docker exec passes no host variable and an empty list must fail; 2026-10-20 (M007) no apostrophes in R comments inside single quotes; 2026-09-12 (M002) run containerized linters on files inside the checkout.
- 2026-11-05: plan gate chose the script reading the Dockerfile pin, with `SMOKE_CMDSTAN_VERSION` as an override, over docker.yml passing the pin in, because it is the same file at the same commit and needs no untested workflow edit or test-mode dispatch; falsified by a CI lane that runs the smoke test from a checkout whose Dockerfile did not build the image.
- 2026-11-05: criteria audit (full mode, fresh Opus reader): 8 findings. Fixed: AC4 failed as written (phase 4 reads `CMDSTAN_VERSION` at line 502) and checked a grep, so it now states the phase 3 property and is read from the block; AC3 used the cwd and hit the Stan-file FAIL first, so the pin read moves before that check and the marker is `==> booting`; AC2 gained a Dockerfile-path mismatch and AC3 a non-`x.y.z` env value; AC5 now covers DESIGN.md; AC6 names the shellcheck image and drops hadolint (Dockerfile unchanged); the parser and pre-release limits are in Scope; T2 compares in bash on trimmed output. No finding on AC1 beyond port 8787 being free, now stated.
- 2026-11-05: no test-mode dispatch of docker.yml: the script runs from the same checkout layout in pr-ci.yml, and a dispatch pushes four untagged manifests to Docker Hub.
- 2026-11-05: no offline suite added; the control runs in AC2 and AC3 show the check can fail. No changelog (D-002: release notes live in the GitHub release, and this changes no recipe).
- 2026-11-05: implement started on branch m017-cmdstan-version-check.
- 2026-11-05: T1 done: the script reads the expected version before the Stan-file check, from `SMOKE_CMDSTAN_VERSION` or the Dockerfile ARG via the `test_cmdstan_pin.sh` sed pattern, and fails on a missing Dockerfile or a non-`x.y.z` value; header lists the variable. Shellcheck 0.11.0 clean; `SMOKE_CMDSTAN_VERSION=2.40` printed the not-x.y.z FAIL line.
- 2026-11-05: T2 done: phase 3 captures the first R block's output, parses and trims the `cmdstan version:` line in bash, and fails on an empty value or a mismatch with a line naming both versions and the source; the PASS line names the version. The output now prints after the block ends rather than as it runs. Shellcheck 0.11.0 clean.
- 2026-11-05: T3 done: `docker build -t rocker-bayes:dev .` exit 0. AC1 run exit 0, phase 3 PASS names CmdStan 2.40.0 and the Dockerfile pin. AC2 (a) env 2.39.0 and (b) a `.github/` copy beside a Dockerfile copy pinned 2.39.0 each exit 1 with "cmdstanr reports CmdStan 2.40.0, but <source> expects 2.39.0" and no phase 3 PASS. AC3 (a) no Dockerfile and (b) env `2.40` each exit 1 with their FAIL line and no `==> booting`. Copies lived in `.m017-tmp/` in the checkout, removed after. cmdstanr's `cmdstan_version()` returns the value `read_cmdstan_version()` parses from the tree's `makefile` (read in the image).
- 2026-11-05: T4 done: DESIGN.md's CI paragraph says phase 3 first fails on a version different from the pin or `SMOKE_CMDSTAN_VERSION`, and that a missing or non-`x.y.z` expected version stops the script before boot.

## Decisions

## Review
