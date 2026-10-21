<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M008: Pass CMDSTAN_VERSION to R via Sys.getenv

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
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

- [ ] AC1: In `scripts/install_bayes.sh`, the CmdStan step is a function that
      takes the version as its first argument, falls back to the
      environment's `CMDSTAN_VERSION`, and exports `CMDSTAN_VERSION`. The R
      code it runs calls `cmdstanr::install_cmdstan()` with
      `version = Sys.getenv("CMDSTAN_VERSION")`, and the script's main body
      calls the step only when the script is executed, not sourced.
- [ ] AC2: For each of ten values (`2.40.0`, and one value each holding a
      double quote, a single quote, a backslash, a backtick, `$(...)`, a
      space, a `*`, a newline, and a trailing space), the CmdStan step calls
      `R` with argument lists identical to those of the `2.40.0` call, and
      the environment `R` starts with holds `CMDSTAN_VERSION` equal to the
      value byte for byte. This holds when the value comes from the
      environment and when it comes as the step's first argument with
      `CMDSTAN_VERSION` unset. Evidence: `.github/tests/test_install_cmdstan.sh`
      passes offline.
- [ ] AC3: With `CMDSTAN_VERSION` empty, and again with it unset, and no first
      argument, the CmdStan step exits non-zero before it calls `R` and prints
      a line on stderr containing `CMDSTAN_VERSION is empty`. Evidence: the
      AC2 suite asserts both conditions for each of the two cases.
- [ ] AC4: A noble image built from the branch on this Mac's architecture with
      `docker build -t rocker-bayes:dev .` passes
      `.github/smoke-test.sh rocker-bayes:dev`, and its phase 3 output
      contains `cmdstan version: 2.40.0`, the version the Dockerfile `ARG`
      pins.
- [ ] AC5: `hadolint Dockerfile` reports no violations, and shellcheck 0.11.0
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
- [ ] T2: Restructure `scripts/install_bayes.sh` per AC1 and AC3 (the step
      reads `${1:-${CMDSTAN_VERSION:-}}`, so `set -u` cannot pre-empt the
      script's own message). Suite green. Plant each defect and see the
      suite go red, then restore: the old `"'"${CMDSTAN_VERSION}"'"`
      interpolation, the export removed, the empty check removed.
- [x] T3: Add the suite to `pr-ci.yml`'s `script-tests` job. Correct
      `cairn/DESIGN.md` "Pre-merge checks", which says five suites, to the
      list `pr-ci.yml` runs, read from that file.
- [ ] T4: Run the pinned shellcheck as `shellcheck -x -S info` (add a
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

## Decisions
<!-- owner: implement / review · append-only; milestone-local. -->

## Review
<!-- owner: review · exclusive -->
