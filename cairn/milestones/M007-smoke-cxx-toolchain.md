# M007: Cover a broken C++ toolchain in smoke

- **Status:** planned
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP8
- **Resolves:** —
- **Surface tier:** internal — a CI check over the built image that no user of the image runs
- **Branch/PR:** —

## Goal

Smoke phase 3 fails on its own C++ build line when the image's C++ compiler is broken.

## Scope

**In:** phase 3 of `.github/smoke-test.sh` runs stanc through cmdstanr's
`$check_syntax()` before it runs the C++ build through `$compile()`. Each step
gets its own stage marker and its own FAIL line, which replace the one "did not
compile" line. The header comment says what phase 3 now reports. The DESIGN.md
CI / publish bullet says the same in one clause. One local control run against
an image with a disabled C++ compiler shows the new C++ build line, and one
against `does-not-compile.stan` shows the new stanc line.

**Out:** a broken-compiler control that runs on every pull request (declined at
the plan gate, parked as the candidate row "Run the broken compiler control in
CI"). A host port probe in phase 1 and smoke container cleanup on cancel (their
own candidate rows).

## Acceptance criteria

- [ ] AC1: In phase 3 of `.github/smoke-test.sh`, the R block creates the model
      with `cmdstan_model(..., compile = FALSE)`, runs `$check_syntax()`, and
      then runs `$compile()`. Each of the two calls sits in its own `tryCatch`
      that prints its own stage marker. The shell maps the two markers to two
      FAIL lines: one names stanc and one names the C++ build. The two lines
      differ from each other and from the other phase 3 FAIL lines in the
      script.
- [ ] AC2: Against an image built from this branch, a run with no `SMOKE_*`
      variables set exits 0 with the three phase PASS lines.
- [ ] AC3: Against the same image, a run with `SMOKE_STAN_FILE` set to
      `.github/smoke-fixtures/does-not-compile.stan` exits 1 with the AC1
      stanc FAIL line.
- [ ] AC4: Against an image derived from the AC2 image in which the C++
      compiler that CmdStan calls exits non-zero, a run with no `SMOKE_*`
      variables set exits 1 with the AC1 C++ build FAIL line and not the AC1
      stanc FAIL line.
- [ ] AC5: The `verify` slot is clean. `hadolint Dockerfile` reports nothing,
      and the branch image builds. Shellcheck 0.11.0 at `-S info` reports
      nothing on `.github/smoke-test.sh`.

## Coverage

- AC1 → T1, T3
- AC2 → T2, T3
- AC3 → T3
- AC4 → T2, T3
- AC5 → T1, T2

## Tasks

- [ ] T1: In `.github/smoke-test.sh` phase 3 (the R block near lines 241-287),
      replace the single `cmdstan_model(stan)` call with
      `cmdstan_model(stan, compile = FALSE)`, a `$check_syntax()` call under a
      `stage:stanc` marker, and a `$compile()` call under a `stage:cxx` marker.
      Replace the `stage:compile` case in the shell with two FAIL lines, one
      for each marker. Update the header comment and the comment above the R
      block. Run shellcheck 0.11.0 at `-S info` in a container against the
      file inside the repo checkout. Run the script under macOS bash 3.2 as
      well as bash 5 where the two differ.
- [ ] T2: Start Docker Desktop, run `hadolint Dockerfile` in a container, and
      build `rocker-bayes:dev` from the branch (arm64). Inside it, find the
      file that `g++` resolves to and the compiler CmdStan's make calls. Build
      a derived image that replaces that file with a stub that prints a fixed
      message to stderr and exits 1. Use a Dockerfile passed on stdin, not a
      committed file. Confirm `stanc` still runs in the derived image.
- [ ] T3: Run the AC2 pass case, the AC3 control, and the AC4 control. Log each
      exit status and FAIL or PASS line. Check each failure's identity, not
      the line alone: AC3 fails on the stanc error at the `no_such_type`
      declaration, and AC4's output carries the stub's message.
- [ ] T4: Update the DESIGN.md CI / publish bullet in one clause to say phase
      3 prints separate FAIL lines for a program stanc rejects and for a
      failed C++ build.

## Work log

- 2026-10-20: created by /milestone-plan.
- 2026-10-20: tier check: milestone — a change to running CI code with a design decision (one FAIL line or two for the compile step).
- 2026-10-20: absorbed candidate row "Cover a broken C++ toolchain in smoke" (M001 review F3, F12, split 2026-10-20). Collision sweep: M001 shipped phase 3 and its stanc-time control, M006 shipped the phase 2 half of the split row (both archived), no D-entry overlaps, sibling smoke rows stay separate. Inbox: 0 open issues, 0 open PRs.
- 2026-10-20: checker-regress shape judged not to fire: the smoke test checks the built image, the repo's external deliverable, not a repo-internal artifact.
- 2026-10-20: lessons surfaced: guarded reads under `set -e`, macOS bash 3.2 vs bash 5, Docker Desktop not sharing the scratchpad (run shellcheck on files in the checkout), `praise` as the phase 2 probe for the pass case.
- 2026-10-20: criteria audit (reduced mode, fresh Opus reader) returned 2 findings, both fixed by narrowing. AC4 bound the control image (how the stub is built, its message in the output); it now promises the smoke test's FAIL line only, and the stub message moved to T3 as failure-identity evidence. A drafted AC6 for a CI control bound where its Dockerfile lives; AC6 was not written after the question set. AC1, AC2, AC3, AC5: none.
- 2026-10-20: question set: broken-compiler control — once, locally, recorded as evidence.
- 2026-10-20: question set: compile failure lines — two lines, stanc and C++ build.
- 2026-10-20: question set: verification — local arm64 build with Docker Desktop on this Mac, granted.
- 2026-10-20: plan gate chose a one-time local control over a CI control step because it matches the M001 and M006 controls and adds no CI time; falsified by a later smoke-test change that breaks the C++ build FAIL line and ships unnoticed.
- 2026-10-20: plan gate chose two FAIL lines over one because a single line cannot show that the control caught the compiler rather than a Stan error; falsified by `$check_syntax()` passing a program that `$compile()` then rejects in stanc.
- 2026-10-20: plan chose replacing the resolved `g++` file over shadowing it on `PATH` because CmdStan's make may call the compiler by full path or through `/usr/bin`; falsified by a control run whose output lacks the stub's message.
- 2026-10-20: no release notes: a CI-only change with no recipe change gets no release under D-002.

## Decisions

## Review
