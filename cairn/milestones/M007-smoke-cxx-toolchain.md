# M007: Cover a broken C++ toolchain in smoke

- **Status:** review
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP8
- **Resolves:** —
- **Surface tier:** internal — a CI check over the built image that no user of the image runs
- **Branch/PR:** m007-smoke-cxx-toolchain

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

- [x] AC1: In phase 3 of `.github/smoke-test.sh`, the R block creates the model
      with `cmdstan_model(..., compile = FALSE)`, runs `$check_syntax()`, and
      then runs `$compile()`. Each of the two calls sits in its own `tryCatch`
      that prints its own stage marker. The shell maps the two markers to two
      FAIL lines: one names stanc and one names the C++ build. The two lines
      differ from each other and from the other phase 3 FAIL lines in the
      script.
- [x] AC2: Against an image built from this branch, a run with no `SMOKE_*`
      variables set exits 0 with the three phase PASS lines.
- [x] AC3: Against the same image, a run with `SMOKE_STAN_FILE` set to
      `.github/smoke-fixtures/does-not-compile.stan` exits 1 with the AC1
      stanc FAIL line.
- [x] AC4: Against an image derived from the AC2 image in which the C++
      compiler that CmdStan calls exits non-zero, a run with no `SMOKE_*`
      variables set exits 1 with the AC1 C++ build FAIL line and not the AC1
      stanc FAIL line.
- [x] AC5: The `verify` slot is clean. `hadolint Dockerfile` reports nothing,
      and the branch image builds. Shellcheck 0.11.0 at `-S info` reports
      nothing on `.github/smoke-test.sh`.

## Coverage

- AC1 → T1, T3
- AC2 → T2, T3
- AC3 → T3
- AC4 → T2, T3
- AC5 → T1, T2

## Tasks

- [x] T1: In `.github/smoke-test.sh` phase 3 (the R block near lines 241-287),
      replace the single `cmdstan_model(stan)` call with
      `cmdstan_model(stan, compile = FALSE)`, a `$check_syntax()` call under a
      `stage:stanc` marker, and a `$compile()` call under a `stage:cxx` marker.
      Replace the `stage:compile` case in the shell with two FAIL lines, one
      for each marker. Update the header comment and the comment above the R
      block. Run shellcheck 0.11.0 at `-S info` in a container against the
      file inside the repo checkout. Run the script under macOS bash 3.2 as
      well as bash 5 where the two differ.
- [x] T2: Start Docker Desktop, run `hadolint Dockerfile` in a container, and
      build `rocker-bayes:dev` from the branch (arm64). Inside it, find the
      file that `g++` resolves to and the compiler CmdStan's make calls. Build
      a derived image that replaces that file with a stub that prints a fixed
      message to stderr and exits 1. Use a Dockerfile passed on stdin, not a
      committed file. Confirm `stanc` still runs in the derived image.
- [x] T3: Run the AC2 pass case, the AC3 control, and the AC4 control. Log each
      exit status and FAIL or PASS line. Check each failure's identity, not
      the line alone: AC3 fails on the stanc error at the `no_such_type`
      declaration, and AC4's output carries the stub's message.
- [x] T4: Update the DESIGN.md CI / publish bullet in one clause to say phase
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
- 2026-10-20: implement started on branch m007-smoke-cxx-toolchain, cut from main at fa3fed2; tree clean.
- 2026-10-20: T1 split phase 3's compile into `cmdstan_model(compile = FALSE)` plus `$check_syntax()` under `stage:stanc`, then `$compile()` under `stage:cxx`, wrapped in `invisible()` so the model object does not print. FAIL lines: "stanc rejected <file>" and "<file> passed stanc but the C++ build failed". Shellcheck 0.11.0 `-S info` clean, `/bin/bash` 3.2 parses the file. The edited lines add no bash 3.2 vs 5 difference (no arrays, no new `set -u` reads).
- 2026-10-20: T2 `hadolint Dockerfile` (hadolint/hadolint container) exit 0 with no output. `rocker-bayes:dev` built from the branch, arm64, created 2026-10-21T01:53Z UTC, base layers from cache. In it `g++` resolves to `/usr/bin/aarch64-linux-gnu-g++-13`, and CmdStan 2.40.0's `make print-CXX` gives `CXX = g++`. `rocker-bayes:dev-broken-cxx` (Dockerfile on stdin) overwrites the resolved file with a stub that prints "smoke control: C++ compiler disabled" and exits 1. In it `g++ --version` printed the stub message and exited 1, and `bin/stanc --version` printed `stanc3 v2.40.0` and exited 0.
- 2026-10-20: T3 first AC4 run exited 1 on the C++ build line, but its output lacked the stub message: cmdstanr 0.9.0 keeps the failed make's stderr on the condition (`e$stderr`) and does not print it. The `stage:cxx` handler now prints `e$stderr` before its marker. Shellcheck 0.11.0 `-S info` still clean, `/bin/bash` 3.2 still parses the file.
- 2026-10-20: T3 runs on the final script, no `SMOKE_*` variables in the environment. AC2 against `rocker-bayes:dev`: exit 0, three phase PASS lines, theta mean 0.3988 against 0.4020. AC3 (`SMOKE_STAN_FILE=.github/smoke-fixtures/does-not-compile.stan`): exit 1, "FAIL: phase 3 (cmdstan) - stanc rejected does-not-compile.stan", after `stage:stanc` and a stanc syntax error at line 6 (`no_such_type theta;`). AC4 against `rocker-bayes:dev-broken-cxx`: exit 1, "FAIL: phase 3 (cmdstan) - bernoulli.stan passed stanc but the C++ build failed", after "Stan program is syntactically correct", `stage:cxx`, and the stub message. Make stopped at `make/program:20` because Stan Math's `compiler_flags` reads `CXX_VERSION` from `$(CXX) -dumpversion`, which the stub broke.
- 2026-10-20: T3 extra control beyond AC4, so the C++ build line is shown for a failed compile and not only for the version probe: `rocker-bayes:dev-broken-cxx2` keeps `-dumpversion` working and fails every other compiler call. Exit 1 with the same C++ build FAIL line, after the stub message for the model compile and `make: *** [make/program:83: .../model-*.o] Error 1`.
- 2026-10-20: T4 added one sentence to the DESIGN.md CI / publish bullet: the CmdStan phase runs stanc before the C++ build and prints a separate FAIL line for each.
- 2026-10-20: claim audit: not owed — internal tier.
- 2026-10-20: all tasks done; verify slot clean (hadolint exit 0, branch image built, shellcheck 0.11.0 `-S info` exit 0); status set to review.
- 2026-10-20: review: four lenses, 11 findings. 7 fixed in fe308fc (5 distinct changes), 1 to a candidate row, 3 rejected. Two apostrophes in new R comments ended the shell's single-quoted R block before the fix landed; shellcheck caught both, and the R comments now avoid apostrophes. After fe308fc, shellcheck 0.11.0 `-S info` exit 0, `/bin/bash` 3.2 parses the file, and AC2 to AC4 were rerun.

## Decisions

## Review

Evidence gathered 2026-10-20 on the working tree that the review fix commit below carries, main unmoved since the cut (fa3fed2). Images rebuilt from the branch (arm64), no `SMOKE_*` variables in the environment. A first evidence pass at d555551 gave the same exit statuses; the AC1 to AC4 lines below are from the rerun after the review fixes.

- **AC1 verified.** `.github/smoke-test.sh` line 257 creates the model with `cmdstan_model(stan, compile = FALSE)`. Line 259 calls `$check_syntax()` inside the `tryCatch` at 258 that prints `stage:stanc` (261). Line 266 calls `$compile()` inside the `tryCatch` at 265 that prints `stage:cxx` (276). The shell maps them at 316 ("stanc failed on $STAN_BASE") and 317 ("$STAN_BASE passed stanc but the C++ build failed"). A grep of `echo "FAIL: phase 3` lists 8 lines (52, 231, 315-320), and the two new lines match none of the other six.
- **AC2 verified.** `bash .github/smoke-test.sh rocker-bayes:dev` exit 0 with the three phase PASS lines and the overall PASS line; theta mean 0.3988 against 0.4020.
- **AC3 verified.** `SMOKE_STAN_FILE=.github/smoke-fixtures/does-not-compile.stan` exit 1 with "FAIL: phase 3 (cmdstan) - stanc failed on does-not-compile.stan". Identity: stanc's syntax error at line 6, columns 2-14 (the `no_such_type` declaration), then `stage:stanc`.
- **AC4 verified.** Against `rocker-bayes:dev-broken-cxx`, rebuilt from the rebuilt `rocker-bayes:dev` with the resolved `g++` file replaced by a stub, exit 1 with "FAIL: phase 3 (cmdstan) - bernoulli.stan passed stanc but the C++ build failed", and no stanc FAIL line. Identity: "Stan program is syntactically correct", then the stub's "smoke control: C++ compiler disabled", then `stage:cxx`.
- **AC5 verified.** `hadolint Dockerfile` (hadolint/hadolint container) exit 0, no output. `docker build -t rocker-bayes:dev .` exit 0. Shellcheck 0.11.0 `-S info` on `.github/smoke-test.sh` exit 0, no output.
- **Consistency gate.** `cairn_validate.py` exit 0, all checks passed. No principle text changed, so `cairn_impact` is skipped. Profile checks: build and hadolint as in AC5. The base image is the explicit tag `jmgirard/rstudio2u:${BASE_TAG}` (default `noble`), not `latest`. The diff touches no Dockerfile, no `ENV`, and no `COPY`. `.dockerignore` is present and excludes `.git` and `.github`. Changelog slot is none (D-002); no user-visible image change.

spawned: diff-bug, blame-history, prior-review, ripple

- diff-bug #1: the `e$stderr` print is dead code under cmdstanr 0.9.0, because `$compile()` streams make's stderr through `message()` and raises a plain error — reject (false): in the stub image (cmdstanr 0.9.0, read with `packageVersion`), `$compile()` fails earlier in `get_cmdstan_flags("STANCFLAGS")`, whose make call raises a `system_command_status_error` carrying the stub message in `e$stderr`; the first AC4 run lacked that message. The reviewer's reproduction failed later, in the build itself, which the `dev-broken-cxx2` control also showed streaming. The comment now names the flags read.
- diff-bug #2: the comment "points at the toolchain" overclaims, since a stanc-valid program can fail the build for other reasons — fix now, fixed fe308fc: the comment says the failure comes from the build step, not from the stanc check.
- diff-bug #3: the stanc `tryCatch` also wraps `cmdstan_model()`, so a failed copy or constructor error prints the stanc line, and a stanc binary that cannot run prints "rejected" — fix now, fixed fe308fc: the constructor moved outside both stages (its failure takes the no-marker line), and the FAIL line reads "stanc failed on <file>".
- diff-bug #4: the shell `case` matches a marker anywhere in the captured output, so a user Stan file quoting `stage:data` near its error would take the wrong line — follow-up: candidate row "Anchor smoke stage markers to lines" (pre-existing since M001).
- diff-bug #5: the `e$stderr` guard prints `NA` for `NA_character_`, drops a vector longer than 1, and `$` partial-matches — fix now, fixed fe308fc: `e[["stderr"]]`, NA and empty entries dropped, every remaining line printed.
- blame-history #1: constructor errors print "stanc rejected" (same as diff-bug #3) — fix now, fixed fe308fc, as diff-bug #3.
- blame-history #2: "passed stanc" is asserted, since `$compile()` reruns stanc and could reject the program — reject (false): the line is printed only after `$check_syntax()` returned, so stanc did pass; diff-bug #2 also judged the FAIL wording accurate. The rerun case is the plan's recorded falsifier for the two-line choice.
- prior-review #1: `.github/smoke-fixtures/does-not-compile.stan` header says the control proves "a compile failure" (same as ripple #1) — fix now, fixed fe308fc, as ripple #1.
- prior-review #2: the "points at the toolchain" comment overclaims (same as diff-bug #2) — fix now, fixed fe308fc, as diff-bug #2.
- ripple #1: `.github/smoke-fixtures/does-not-compile.stan:2-3` says "reports a compile failure", but the phase now prints the stanc line — fix now, fixed fe308fc: the header says the phase reports a stanc failure, before the C++ build. Line count kept, so the stanc error stays at line 6.
- ripple #2: ROADMAP row "Cover a broken C++ toolchain in smoke" states the gap in the present tense — reject (planned change): post-merge hygiene graduates that row.
