<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M008: Pass CMDSTAN_VERSION to R via Sys.getenv

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** high   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP3   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — people build the image with `--build-arg CMDSTAN_VERSION=…`   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m008-cmdstan-version-env   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

The CmdStan version reaches R as an environment variable, so no value can change the R code that installs CmdStan.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** `scripts/install_bayes.sh` moves its CmdStan step into a function that
takes the version as its first argument, falls back to the environment, stops
early on an empty value, exports `CMDSTAN_VERSION`, and calls R with
`version = Sys.getenv("CMDSTAN_VERSION")`. The script's main body runs only
when the script is executed, not sourced. A new offline suite
`.github/tests/test_install_cmdstan.sh` runs in `pr-ci.yml`'s `script-tests`
job. `cairn/DESIGN.md` lists the suites that job runs.

**Out:** a smoke check that the installed CmdStan matches the version tag
→ a ROADMAP candidate row added at this plan's gate. A build with a
non-default `--build-arg CMDSTAN_VERSION` → not run; AC4 covers the default
pin only. Version-format validation (x.y.z) → not planned, since CmdStan
release candidates use other forms.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [x] AC1: In `scripts/install_bayes.sh`, the CmdStan step is a function that
      takes the version as its first argument, falls back to the
      environment's `CMDSTAN_VERSION`, and exports `CMDSTAN_VERSION`. The R
      code it runs calls `cmdstanr::install_cmdstan()` with
      `version = Sys.getenv("CMDSTAN_VERSION")`, and the script's main body
      calls the step only when the script is executed, not sourced.
- [x] AC2: For each of ten values (`2.40.0`, and one value each holding a
      double quote, a single quote, a backslash, a backtick, `$(...)`, a
      space, a `*`, a newline, and a trailing space), the CmdStan step calls
      `R` with argument lists identical to those of the `2.40.0` call, and
      the environment `R` starts with holds `CMDSTAN_VERSION` equal to the
      value byte for byte. This holds when the value comes from the
      environment and when it comes as the step's first argument with
      `CMDSTAN_VERSION` unset. Evidence: `.github/tests/test_install_cmdstan.sh`
      passes offline.
- [x] AC3: With `CMDSTAN_VERSION` empty, and again with it unset, and no first
      argument, the CmdStan step exits non-zero before it calls `R` and prints
      a line on stderr containing `CMDSTAN_VERSION is empty`. Evidence: the
      AC2 suite asserts both conditions for each of the two cases.
- [x] AC4: A noble image built from the branch on this Mac's architecture with
      `docker build -t rocker-bayes:dev .` passes
      `.github/smoke-test.sh rocker-bayes:dev`, and its phase 3 output
      contains `cmdstan version: 2.40.0`, the version the Dockerfile `ARG`
      pins.
- [x] AC5: `hadolint Dockerfile` reports no violations, and shellcheck 0.11.0
      run as `shellcheck -x -S info` reports nothing on
      `scripts/install_bayes.sh` and `.github/tests/test_install_cmdstan.sh`.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T2
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T4
- AC5 → T4

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits) -->

- [x] T1: Write `.github/tests/test_install_cmdstan.sh` in the style of
      `test_cmdstan_pin.sh` (`set -uo pipefail`, count failures). Put
      executable stubs for `R`, `mkdir`, and `chown` in a temporary
      directory, and run each case in a subshell that sources the script
      with `PATH` set to that directory only, so any other command fails
      as "not found" and nothing touches the host. The `R` stub, a child
      process, writes its argument list and `CMDSTAN_VERSION` to files.
      Compare those files byte for byte, never through `$(...)`, which drops
      trailing newlines. Only the first-argument case with the variable
      unset proves the script's own export, so the test exports nothing
      there. Show the suite red against the current script.
- [x] T2: Restructure `scripts/install_bayes.sh` per AC1 and AC3 (the step
      reads `${1:-${CMDSTAN_VERSION:-}}`, so `set -u` cannot pre-empt the
      script's own message). Suite green. Plant each defect and see the
      suite go red, then restore: the old `"'"${CMDSTAN_VERSION}"'"`
      interpolation, the export removed, the empty check removed.
- [x] T3: Add the suite to `pr-ci.yml`'s `script-tests` job. Correct
      `cairn/DESIGN.md` "Pre-merge checks", which says five suites, to the
      list `pr-ci.yml` runs, read from that file.
- [x] T4: Run the pinned shellcheck as `shellcheck -x -S info` (add a
      `# shellcheck source=` directive for the sourced script) and
      `hadolint Dockerfile`. Build noble locally and run the smoke test.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-10-20: created by /milestone-plan.
- 2026-10-20: tier check: milestone — a change to running build code that is not a bug restoring documented behavior.
- 2026-10-20: collision check: absorbed the candidate row "Pass CMDSTAN_VERSION to R via Sys.getenv" (M002 review). D-001..D-003 do not overlap. Inbox: 0 open issues, 0 open PRs.
- 2026-10-20: lessons harvested: bash 3.2 on macOS vs bash 5 on the runner (M004), `set -e` in `run` steps (M005), apostrophes inside single-quoted R code (M007).
- 2026-10-20: criteria audit (full mode, fresh Opus reader) returned 14 findings, all fixed in wording: argument resolved inside the step (AC1); AC2 restated as a script property with named stubs, a stub-only PATH, byte-exact compares, argv over every R call, three more values, and planted export removal; AC3 message must come from the script, both cases named; AC4 "contains" and host architecture; AC5 uses lint.yml's `-x` and a source directive; DESIGN's suite count is already wrong.
- 2026-10-20: AC3 entered after the audit with the audit's two AC3 fixes applied; no second audit run.
- 2026-10-20: question set: empty CMDSTAN_VERSION — fail early with a clear message (AC3).
- 2026-10-20: question set: smoke check that CmdStan matches the version tag — candidate row, not this milestone.
- 2026-10-20: question set: may implement and review build the full image locally on this Mac — yes.
- 2026-10-20: plan gate chose sourcing the script with stubs on a stub-only PATH over a static grep of the R source, because grep checks one spelling and not what R receives; falsified by a defect that changes R's argv or environment while the suite passes.
- 2026-10-20: plan gate chose sourcing with a guard over running the whole script with PATH stubs, because a stub gap would run `rm -rf /tmp/*` and apt-get on the host; falsified by the guard keeping the main body from running in the image build.
- 2026-10-20: plan gate chose an offline suite over image builds with quote-bearing build args, because each build is a cold CmdStan compile; falsified by a stubbed pass whose real build fails on one of the ten values.
- 2026-10-20: implement started on branch m008-cmdstan-version-env; linters run from the local `koalaman/shellcheck:v0.11.0` and `hadolint/hadolint:v2.12.0` images.
- 2026-10-20: T1 done: suite written; against the current script it fails at the baseline with status 127, `apt-get: command not found` (no source guard, so sourcing ran the main body against the stubs). Step function named `install_cmdstan_step`; the suite also asserts the baseline R program contains `Sys.getenv("CMDSTAN_VERSION")`.
- 2026-10-20: T2 code done: step function plus source guard; `main` body re-indented. Suite green on bash 3.2 (macOS) and bash 5.2 (inside rocker-bayes:dev). Plants, each restored: old interpolation → 19 failures (argv differs for all 9 non-baseline values in both modes, and the Sys.getenv check); export removed → 10 failures, every first-argument case; empty check removed → 6 failures, all empty/unset assertions. Shellcheck 0.11.0 `-x -S info` clean after one reasoned SC1003/SC2016 disable on the value list. Tick waits on the local docker build.
- 2026-10-20: T3 done: `pr-ci.yml` script-tests runs the suite; all eight listed suites pass locally. DESIGN "Pre-merge checks" now points at the job's own list instead of a count (minor amendment: a pointer per the derived-claims rule, not a copied list), and "Image build" describes the CmdStan step. The `pr-ci.yml` paths comment that listed six suites now points at the job.
- 2026-10-20: T2 ticked: local `docker build -t rocker-bayes:dev .` (arm64) exited 0; the build log shows the R code with `version = Sys.getenv("CMDSTAN_VERSION")` and the download of `cmdstan-2.40.0-linux-arm64.tar.gz`.
- 2026-10-20: T4 done: hadolint v2.12.0 clean; shellcheck 0.11.0 `-x -S info` clean on both scripts; `.github/smoke-test.sh rocker-bayes:dev` exit 0, all three phases PASS, phase 3 printed `cmdstan version: 2.40.0`.
- 2026-10-20: claim audit: 20 claims read, 2 corrected — .github/tests/test_install_cmdstan.sh (the export claim now says only the first-argument cases prove the script's export; "each value" now says "each value after the first"). Also fixed two stale labels it found outside the added lines: the `script-tests` header comment and job name in `pr-ci.yml`, renamed "offline script suites" (no branch protection or ruleset requires the old name).
- 2026-10-20: implement complete; status → review.

## Decisions
<!-- owner: implement / review · append-only; milestone-local. -->

## Review
<!-- owner: review · exclusive -->

Evidence gathered 2026-10-20 at branch head d47cc11; default branch had not moved (0 commits behind origin/main).

- AC1: `scripts/install_bayes.sh:36` defines `install_cmdstan_step`; line 37 reads `${1:-${CMDSTAN_VERSION:-}}`, line 42 exports `CMDSTAN_VERSION`, line 47 passes `version = Sys.getenv("CMDSTAN_VERSION")`, line 93 calls the step from `main`, and line 106 runs `main` only when `${BASH_SOURCE[0]}` equals `$0`.
- AC2: `bash .github/tests/test_install_cmdstan.sh` exit 0 on macOS bash 3.2, "PASS: 10 values from the environment and as an argument reach R unchanged". Its discrimination was shown at T2 (work log): the old interpolation turns 18 argv checks red, and removing the export turns all 10 first-argument cases red.
- AC3: the same run passes the empty and unset cases: non-zero exit, no R call, and stderr containing `CMDSTAN_VERSION is empty` (the message at `scripts/install_bayes.sh:39`). With the check removed at T2, all 6 of those assertions failed.
- AC4: `docker build -t rocker-bayes:dev .` at d47cc11 exit 0 on arm64, with the `COPY scripts` and `install_bayes.sh` layers CACHED from the T2 build, whose log shows the download of `cmdstan-2.40.0-linux-arm64.tar.gz`. `.github/smoke-test.sh rocker-bayes:dev` exit 0, all three phases PASS, and phase 3 printed `cmdstan version: 2.40.0`.
- AC5: `hadolint/hadolint:v2.12.0` on the Dockerfile exit 0 with no output; `koalaman/shellcheck:v0.11.0 -x -S info scripts/install_bayes.sh .github/tests/test_install_cmdstan.sh` exit 0 with no output.
- gate: `cairn_validate.py` all checks passed. No principle text changed, so `cairn_impact` was skipped. Profile checks: docker build and hadolint clean (AC4, AC5); the diff does not touch the Dockerfile, so the base pin `jmgirard/rstudio2u:${BASE_TAG}` and its layers are unchanged and no secret is added; `.dockerignore` present and excludes `.git`, `.github`, and `cairn`; changelog slot is "none" (release notes go in the GitHub release, D-002).
- spawned: diff-bug, blame-history, prior-review, ripple
- diff-bug #1: the empty-version check runs only after the slow R package install — fix now, fixed 10bf6f8 (check moved to the top of `main` through `resolve_cmdstan_version`; suite asserts `main` stops before R)
- diff-bug #2: no test that the first argument wins over the environment — fix now, fixed 10bf6f8 (`both` case; swapping the precedence turns it red)
- diff-bug #3: the mkdir and chown calls are logged but never asserted — fix now, fixed 10bf6f8 (baseline compares the two calls byte for byte)
- diff-bug #4: the step changes the caller's global `CMDSTAN_VERSION` — reject, false: the only callers are the Dockerfile RUN, whose process ends, and the suite, which runs each case in a subshell
- diff-bug #5: the suite file is mode 100644 — fix now, fixed 10bf6f8 (100755, like five of the other seven suites)
- diff-bug #6: an unset variable also prints "is empty" — fix now, fixed 10bf6f8 (message now says "is empty or unset")
- diff-bug #7: an R startup file could override the value — reject, false: no `Renviron*` or `Rprofile.site` in the image mentions CMDSTAN (grep exit 1), and AC4 printed 2.40.0
- diff-bug #8: the R stub hard-codes `#!/bin/bash` — reject, false: the script under test has the same shebang, and the runner and macOS both have /bin/bash
- diff-bug #9: DESIGN says the step stops "before R starts", but R already ran for packages — fix now, fixed 10bf6f8 (DESIGN now says before the package install)
- blame-history #1: run as `sh install_bayes.sh` on dash, the guard skips the install and exits 0 — reject, false: dash in rocker-bayes:dev stops with "Bad substitution", exit 2
- blame-history #2: the pr-ci comment and DESIGN no longer list the suites by name — reject, planned change: the copied list had already drifted (five named, seven run), so it became a pointer
- prior-review #1: the empty-version check runs after the package install — fix now, fixed 10bf6f8 (same fix as diff-bug #1)
- prior-review #2: the guard means `main` never runs except by direct execution — reject, false: `bash scripts/install_bayes.sh` runs `main`, dash fails loudly, and skipping on `source` is the plan
- prior-review #3: the suite file is not executable — fix now, fixed 10bf6f8 (same fix as diff-bug #5)
- prior-review #4: renaming the job may break a required status check — reject, false: `gh api` reports main unprotected and no rulesets
- ripple #1: the ROADMAP candidate row still says the script interpolates — reject, planned change: post-merge hygiene removes the row
- ripple #2: DESIGN "these scripts" (Conventions, alerts bullet) could read as excluding the new suite — reject, false: the sentence is in the alerts bullet and names the alert scripts
- planted after the fixes, each restored: `main` without its early check → 2 failures (R called in `main` empty and unset); precedence swapped to `${CMDSTAN_VERSION:-$1}` → 1 failure (the `both` case).
