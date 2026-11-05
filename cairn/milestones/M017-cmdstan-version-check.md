# M017: Check CmdStan matches the version tag

- **Status:** review
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

- [x] AC1: With `SMOKE_CMDSTAN_VERSION` unset and port 8787 free,
      `bash .github/smoke-test.sh rocker-bayes:dev`, run from the repo root
      against a local build of the branch's Dockerfile, exits 0, and its
      phase 3 PASS line names the CmdStan version that phase compared, which
      equals the Dockerfile's `ARG CMDSTAN_VERSION` value.
- [x] AC2: Against the same image, two mismatch runs each exit non-zero,
      print a `FAIL: phase 3 (cmdstan)` line that names the expected version
      and the version `cmdstanr::cmdstan_version()` reported, and print no
      `PASS: phase 3` line: (a) `SMOKE_CMDSTAN_VERSION=2.39.0`; (b)
      `SMOKE_CMDSTAN_VERSION` unset, with a copy of `.github/` run beside a
      copy of the Dockerfile whose pin reads `2.39.0`, both in a directory
      inside the repo checkout.
- [x] AC3: Two bad-pin runs each exit non-zero with a FAIL line saying the
      expected CmdStan version could not be read or is not `x.y.z`, and print
      no `==> booting` line: (a) `SMOKE_CMDSTAN_VERSION` unset, with a copy of
      the script in a directory whose parent holds no Dockerfile; (b)
      `SMOKE_CMDSTAN_VERSION=2.40`.
- [x] AC4: In phase 3, the image's version is the value that
      `cmdstanr::cmdstan_version()` returns in the phase 1 container. Phase
      3 reads no container environment variable and does not parse the
      version from `cmdstan_path()`, as a read of the phase 3 block shows.
- [x] AC5: The header comment of `.github/smoke-test.sh` lists
      `SMOKE_CMDSTAN_VERSION` and its default among the other `SMOKE_*`
      variables, and its phase 3 text says the phase fails when the reported
      version differs from the expected one. DESIGN.md's CI paragraph says
      phase 3 fails when cmdstanr's CmdStan version differs from the
      Dockerfile pin.
- [x] AC6: `docker build -t rocker-bayes:dev .` succeeds, and
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
- 2026-11-05: claim audit: 17 claims read, 1 corrected — .github/smoke-test.sh (the comment now says an empty `SMOKE_CMDSTAN_VERSION` counts as unset; the reader's re-read found it holds).
- 2026-11-05: all tasks done; shellcheck 0.11.0 clean after the comment fix; status set to review.
- 2026-11-05: review fix-now: phase 3's capture takes stderr (diff-bug #1), DESIGN.md says "set and non-empty" (diff-bug #2), the Dockerfile's build-arg example names `SMOKE_CMDSTAN_VERSION` (ripple #3); parked row "Vary the stale CmdStan in smoke phase 4" filed. Shellcheck, hadolint, `test_cmdstan_pin.sh` pass; evidence pass 2 running.

## Decisions

## Review

Evidence pass 1, at 0f0b488 (2026-11-05), after a fresh `docker build -t rocker-bayes:dev .`; copies for AC2 (b) and AC3 (a) in `.m017-rev/` in the checkout, removed after.

- AC1: `bash .github/smoke-test.sh rocker-bayes:dev` with the variable unset exit 0; "PASS: phase 3 (cmdstan) - CmdStan 2.40.0 matches the Dockerfile ARG pin, …"; the Dockerfile reads `ARG CMDSTAN_VERSION="2.40.0"`.
- AC2: (a) `SMOKE_CMDSTAN_VERSION=2.39.0` exit 1, "FAIL: phase 3 (cmdstan) - cmdstanr reports CmdStan 2.40.0, but SMOKE_CMDSTAN_VERSION expects 2.39.0", no phase 3 PASS; (b) `.m017-rev/b/.github/smoke-test.sh` beside a Dockerfile pinned 2.39.0, variable unset, exit 1, "… but the Dockerfile ARG pin expects 2.39.0", no phase 3 PASS.
- AC3: (a) `.m017-rev/a/sub/smoke-test.sh` with no Dockerfile in its parent, variable unset, exit 1, "FAIL: phase 3 (cmdstan) - could not read the expected CmdStan version: no Dockerfile at …; set SMOKE_CMDSTAN_VERSION"; (b) `SMOKE_CMDSTAN_VERSION=2.40` exit 1, "… from SMOKE_CMDSTAN_VERSION is not x.y.z (got '2.40')". Neither log holds a `==> booting` line.
- AC4: read of phase 3 (`.github/smoke-test.sh:272-305` and the stan block after it): the compared value is the `cmdstan version:` line that `cmdstanr::cmdstan_version()` prints; the phase's only `Sys.getenv` reads are `STAN_BASE`, `DATA_BASE`, `THETA_REF`, `THETA_TOL`, passed with `-e`; `cmdstan_path()` is read only for the path check and `main_threads.o`, never parsed for a version. cmdstanr's `cmdstan_version()` returns what `read_cmdstan_version()` parses from the tree's `makefile` (read in the image at T3).
- AC5: header lines 11-16 say phase 3 fails when the reported version differs from the expected one; lines 48-52 list `SMOKE_CMDSTAN_VERSION` with its Dockerfile-pin default after `SMOKE_THETA_REF`. `cairn/DESIGN.md:63-66` says the phase fails when cmdstanr's CmdStan version differs from the Dockerfile pin.
- AC6: `docker build -t rocker-bayes:dev .` exit 0; `koalaman/shellcheck:v0.11.0 -S info .github/smoke-test.sh` exit 0, no output.

Evidence pass 2, at d0d3ac5 (after the fix-now commit), fresh build: AC1 exit 0 with the same phase 3 PASS line; AC2 (a) and (b) exit 1 with the same FAIL lines and no phase 3 PASS; AC3 (a) and (b) exit 1 with the same FAIL lines and no `==> booting`; shellcheck and hadolint exit 0; `test_cmdstan_pin.sh` passes (3 README references match 2.40.0).

Consistency gate: `cairn_validate.py` all checks passed. No IP/GP text changed, so `cairn_impact` was skipped. Toolchain: `docker build` exit 0; `hadolint/hadolint:v2.14.0` on the Dockerfile exit 0; base pinned by tag (`jmgirard/rstudio2u:${BASE_TAG}`, default `noble`); no secret in `ENV`/`COPY`; `.dockerignore` present; changelog slot is none (D-002), so no entry is owed.

spawned: diff-bug, blame-history, prior-review, ripple

- diff-bug #1: the capture holds stdout only, so on a failure R's stderr prints before the captured lines — fix now, fixed d0d3ac5.
- diff-bug #2: DESIGN.md says "when that is set" where the code treats an empty value as unset — fix now, fixed d0d3ac5.
- diff-bug #3: the script is a third parser of the ARG line beside `test_cmdstan_pin.sh` and docker.yml's `grep -oP` — reject, planned change (Scope In names reading the Dockerfile with that sed pattern; the drift risk is in the plan's work log).
- diff-bug #4: two matching ARG lines print the not-x.y.z message across two lines without saying there were two — reject, edge (a Dockerfile with two `ARG CMDSTAN_VERSION` lines is outside its documented use; the effect is a failed run with an unclear message).
- diff-bug #5: the pre-boot FAIL lines carry the phase 3 label on a run that never booted — reject, planned change (the existing Stan-file check uses the same label).
- diff-bug #6: phase 4 still takes its expected version from the container's variable — reject, false (phase 4 is unchanged, and phase 3 has already matched the tree to the pin).
- diff-bug #7: a symlinked copy of the script looks for the Dockerfile beside the link — reject, edge (no lane runs the script through a symlink; the effect is a failed run with a "no Dockerfile" line).
- diff-bug #8: an R failure that printed nothing leaves one blank line before the FAIL line — reject, style.
- diff-bug #9: AC boxes unticked at status review — reject, false (review ticks them).
- blame-history #1: phase 3's first R output now prints after the block ends — reject, planned change (recorded at T2; three lines).
- blame-history #2: phase 4 seeds a hard-coded stale `cmdstan-2.36.0`, which stops being stale if the pin is ever 2.36.0 — follow-up, parked row "Vary the stale CmdStan in smoke phase 4" (pre-existing line; the pin moves only forward by GP3).
- blame-history #3: the "same checkout" claim holds only while docker.yml and pr-ci.yml build from that Dockerfile — noted (holds today; the plan's rejected-alternative line names this as its falsifier).
- prior-review #1: the PASS line is long — noted.
- ripple #1, #2: the ROADMAP row still says phase 3 compares with nothing and asks for CI to pass the pin — reject, planned change (the row graduates at post-merge hygiene).
- ripple #3: the Dockerfile's `--build-arg CMDSTAN_VERSION=` example does not say that the smoke test then needs `SMOKE_CMDSTAN_VERSION` — fix now, fixed d0d3ac5.
- ripple #4, #5, #6: sampler-output row, stage-marker row, and "one FAIL line" header — reject, false (the reviewer found each still holds).
