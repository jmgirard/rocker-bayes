# M006: Assert smoke packages arrive this run

- **Status:** review
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP8
- **Resolves:** —
- **Surface tier:** internal — a CI check over the built image that no user of the image runs
- **Branch/PR:** m006-smoke-pkg-arrives

## Goal

Smoke phase 2 passes only when the probe package was absent from the image before bspm installed it.

## Scope

**In:** two absence checks in phase 2 of `.github/smoke-test.sh`, run before the
install: a `dpkg -s r-cran-<pkg>` read and a `find.package()` read in the root R
session that runs the install. A new phase 2 FAIL line names which check found
the package. The header comment and the phase 2 PASS line say what phase 2 now
asserts. The DESIGN.md CI / publish bullet says the same in one clause. A probe
package already in the image fails the run. There is no fallback list.

**Out:** a broken C++ toolchain control in smoke (its own candidate row). A host
port probe in phase 1 and smoke container cleanup on cancel (their own candidate
rows). A `SMOKE_PKG` input in the workflows (not needed: the controls run
locally).

## Acceptance criteria

- [x] AC1: Before phase 2 of `.github/smoke-test.sh` installs `SMOKE_PKG`, it
      runs two absence checks: `dpkg -s r-cran-<pkg>` reports no installed
      entry, and `find.package()` returns no path across `.libPaths()` in the
      same root Rscript session that runs the install. When either check finds
      the package, the script exits 1 with a FAIL line that names phase 2, says
      the package was already in the image, and names which check found it.
      That line differs from the two existing phase 2 FAIL lines.
- [x] AC2: Against an image built from this branch, a run with `SMOKE_PKG`
      unset exits 0 with the three phase PASS lines, and its phase 2 PASS line
      says `praise` was absent from the image before the install.
- [x] AC3: Against the same image, a `SMOKE_PKG` that `dpkg -s` shows installed
      exits 1 with the AC1 FAIL line naming the dpkg check. A `SMOKE_PKG` that
      `installed.packages()` lists but `dpkg -l 'r-cran-*'` does not exits 1
      with the AC1 FAIL line naming the R library check.
- [x] AC4: Against the same image, `SMOKE_PKG=oolong` (absent from the image,
      no r2u binary) passes the AC1 absence checks and then exits 1 with the
      existing "did not install as an apt binary" FAIL line.
- [x] AC5: The `verify` slot is clean: `hadolint Dockerfile` reports nothing,
      the branch image builds, and shellcheck 0.11.0 at `-S info` reports
      nothing on `.github/smoke-test.sh`.

## Coverage

- AC1 → T1, T3
- AC2 → T2, T3
- AC3 → T2, T3
- AC4 → T3
- AC5 → T1, T2

## Tasks

- [x] T1: In `.github/smoke-test.sh` phase 2, add the dpkg absence read before
      the install, guarded so a failing read cannot end the script under
      `set -e` before its FAIL line prints. Add the `find.package()` check at
      the top of the existing root Rscript block, with a stage marker so the
      shell prints a FAIL line distinct from the install failure line. Update
      the header comment and the PASS line. Run shellcheck 0.11.0 at `-S info`
      in a container against the file inside the repo checkout (no local
      shellcheck; Docker Desktop does not share the scratchpad). Run the script
      under macOS bash 3.2 as well as bash 5 where the two differ.
- [x] T2: Start Docker Desktop, run `hadolint Dockerfile` in a container, and
      build `rocker-bayes:dev` from the branch (arm64). In that image, compare
      `installed.packages()` with `dpkg -l 'r-cran-*'`. Planned controls:
      `brms` for the dpkg case and `cmdstanr` for the R library case. If a read
      shows either is not of its kind, pick a package of that kind from the
      comparison and log the swap. If `praise` is already in the image, change
      the default probe to an absent package with an r2u binary and log it.
- [x] T3: Run the AC2 default case and the AC3 and AC4 controls against
      `rocker-bayes:dev`. Log each exit status and FAIL or PASS line, and check
      each failure's identity (which check fired), not the line alone.
- [x] T4: Update the DESIGN.md CI / publish bullet in one clause to say phase 2
      asserts the probe package was absent before the install.

## Work log

- 2026-10-20: created by /milestone-plan.
- 2026-10-20: tier check: milestone — a change to running CI code with a design decision (fail or fall back when the probe is present).
- 2026-10-20: absorbed candidate row "Assert smoke packages arrive this run" (M001 review F3, F12, split 2026-10-20). Collision sweep: M001 shipped phase 2 (archive), no D-entry overlaps, sibling smoke rows stay separate. Inbox: 0 open issues, 0 open PRs.
- 2026-10-20: checker-regress shape judged not to fire: the smoke test checks the built image, the repo's external deliverable, not a repo-internal artifact.
- 2026-10-20: lessons surfaced: the praise/oolong probe pair, guarded reads under `set -e`, macOS bash 3.2 vs bash 5, Docker Desktop not sharing the scratchpad.
- 2026-10-20: criteria audit (reduced mode, fresh Opus reader) returned 3 findings, all fixed by narrowing: AC1 R check scoped to the root session's `.libPaths()`; AC3 restated as script behavior per kind of present package, with the brms and cmdstanr picks moved to T2; AC4 limited to the oolong run. AC5 added after the audit as the profile's verify slot; its promise covers two named files, so the three reduced-audit questions find nothing.
- 2026-10-20: question set: probe already in the image — fail the run, no fallback list.
- 2026-10-20: question set: verification — local arm64 build with Docker Desktop on this Mac, granted.
- 2026-10-20: plan gate chose failing the run over a fallback probe list because a fallback hides the case it exists to catch and adds parsing; falsified by roster churn making the default probe present more than once a year.
- 2026-10-20: plan gate chose local control runs over CI control branches because the workflows pass no `SMOKE_PKG` and each CI control costs a build; falsified by a control that passes locally and fails on amd64 CI.
- 2026-10-20: no release notes: a CI-only change with no recipe change gets no release under D-002.
- 2026-10-20: implement started; branch m006-smoke-pkg-arrives cut from main at eeeab0d. Docker Desktop started; `rocker-bayes:dev` build running in the background.
- 2026-10-20: T1 choice: the R library check signals through Rscript exit status 3 rather than a stdout stage marker, so install output still streams live; the dpkg check counts only a `Status: install ok installed` line.
- 2026-10-20: question set (implement stop): download koalaman/shellcheck:v0.11.0 and hadolint/hadolint:v2.12.0 for local lint — granted.
- 2026-10-20: T1 checkpoint: absence checks, new FAIL lines, header comment, and PASS line in `.github/smoke-test.sh`. shellcheck 0.11.0 `-S info` exit 0, hadolint exit 0, `bash -n` clean. The bash 3.2 and bash 5 runs wait for the image (T3); T1 stays open until then.
- 2026-10-20: T4 done out of order while the image builds: one sentence added to the DESIGN.md CI / publish bullet after the smoke-test clause.
- 2026-10-20: T2: `docker build --pull -t rocker-bayes:dev .` exit 0, image a46c72b6ce29 (arm64); hadolint v2.12.0 exit 0. Reads in that image: `praise` no dpkg entry, no `find.package()` path; `brms` `Status: install ok installed`, path /usr/lib/R/site-library/brms; `cmdstanr` no dpkg entry, path /usr/local/lib/R/site-library/cmdstanr; `oolong` absent from both. Planned controls kept, default probe kept. `.libPaths()` in root Rscript: /usr/local/lib/R/site-library, /usr/lib/R/site-library, /usr/lib/R/library.
- 2026-10-20: T3 runs against a46c72b6ce29 under macOS /bin/bash 3.2.57 (the only bash on this host; the PR's CI run is the bash 5 run, and the new code uses no arrays). Default: exit 0, three phase PASS lines, phase 2 PASS line says praise was absent before the install; the log shows apt fetching `r-cran-praise_1.0.0-1.ca2404.1` from r2u.
- 2026-10-20: T3 controls, each exit 1. `brms`: dpkg-check FAIL line (shell check fired; no Rscript ran). `cmdstanr`: R-library-check FAIL line after `found before the install: /usr/local/lib/R/site-library/cmdstanr`. `oolong`: passed both absence checks, built from source (`DONE (oolong)`), then the existing "r-cran-oolong absent" line. Extra: `nosuchpkgm006` gave "not available" and the existing "install or load ... failed" line, so exit 3 does not swallow other failures.
- 2026-10-20: T3 checked the T1 comment's claim: in a throwaway container, `dpkg -r binutils-common` left `Status: deinstall ok config-files` and `dpkg -s` exited 0.
- 2026-10-20: claim audit: not owed — internal tier.
- 2026-10-20: review checkpoint: AC1–AC5 evidence recorded and ticked, consistency gate clean; four review lenses running, findings not yet settled.
- 2026-10-20: review settled 15 findings: 10 fixed in a6bbeae, 1 to a candidate row, 4 rejected. No criterion failed, so no return. AC1–AC5 re-verified on a6bbeae.
- 2026-10-20: step-7 approval: m006-smoke-pkg-arrives approved for merge

## Decisions

## Review

Fresh evidence 2026-10-20 on branch head 97d9fe9, synced with origin/main (0 behind). Image `rocker-bayes:dev` rebuilt from cache, Id b30a5a3dad77, arm64, run under macOS /bin/bash 3.2.57; container user root.

- **AC1 verified.** `.github/smoke-test.sh:138` reads `dpkg -s r-cran-<pkg>` before the install and line 141 fails on a `Status: install ok installed` entry, naming the dpkg check. Lines 152–155 run `find.package()` in the same root Rscript that runs `install.packages(pkg)` at line 157, and exit 3. Line 165 fails on that status, naming the R library check. Both lines say the package was already in the image and differ from the existing lines 169 ("install or load ... failed") and 174 ("did not install as an apt binary"). The AC3 runs below exercise both branches.
- **AC2 verified.** `SMOKE_PKG` unset: exit 0 with the three phase PASS lines and the summary PASS line. Phase 2 reads `praise was absent from the image before the install, installed as r-cran-praise, and loads`; the log shows `Get:1 https://r2u.stat.illinois.edu/ubuntu noble/main all r-cran-praise all 1.0.0-1.ca2404.1`.
- **AC3 verified.** `SMOKE_PKG=brms` (T2: `r-cran-brms` `install ok installed`): exit 1, the line-141 FAIL line naming the dpkg check. `SMOKE_PKG=cmdstanr` (T2: in `installed.packages()`, no dpkg entry): exit 1, R printed `found before the install: /usr/local/lib/R/site-library/cmdstanr`, then the line-165 FAIL line naming the R library check.
- **AC4 verified.** `SMOKE_PKG=oolong`: no absence FAIL line; the log shows `installing *source* package 'oolong'`, then exit 1 with `oolong did not install as an apt binary (r-cran-oolong absent)`.
- **AC5 verified.** hadolint v2.12.0 on `Dockerfile` exit 0 with no output; `docker build -t rocker-bayes:dev .` exit 0; shellcheck v0.11.0 `-S info` on `.github/smoke-test.sh` exit 0 with no output.
- **Consistency gate.** `cairn_validate.py`: all checks passed. No IP/GP text changed, so `cairn_impact` was skipped. Profile checks: build and hadolint clean (AC5); base pinned by the explicit tag `jmgirard/rstudio2u:${BASE_TAG}` (default `noble`, unchanged); the diff adds no credential strings; `.dockerignore` present and excludes `.git`, `.github`, and `cairn`; changelog slot is `none` and the change is CI-only (no release under D-002).

spawned: diff-bug, blame-history, prior-review, ripple

- diff-bug #1: the absence checks ran only on noble arm64; resolute first runs after merge and a resolute image carrying `praise` would hold all tags — reject (planned change: the plan gate chose local noble arm64 runs; a resolute failure fails closed with a FAIL line naming the cause).
- diff-bug #2: the dpkg check after the install accepted any `dpkg -s` success, including `config-files`, while the pre-check counted only installed — fix now, fixed a6bbeae.
- diff-bug #3: the pre-check matched only `install ok installed`, so `unpacked`, `half-configured`, `triggers-pending` and held packages read as absent at the dpkg step — fix now, fixed a6bbeae (any state but none, `not-installed`, `config-files` counts as present).
- diff-bug #4: the comment "Any other failure exits 1" is false for docker exec's 125–137 statuses — fix now, fixed a6bbeae.
- diff-bug #5: a failed dpkg exec read as "absent", so a gone container got the install-failure line — fix now, fixed a6bbeae (docker exec exits 1 for a gone container, like an unknown package, so only dpkg's "is not installed" message counts as no record; otherwise a "could not read the dpkg status" FAIL line).
- diff-bug #6: exit status 3 from a package's own `quit(status = 3)` in `.onLoad` would read as "already in the image" — follow-up, candidate row "Tell phase 2 exit 3 from package quit".
- diff-bug #7: the FAIL text said `find.package()` found it "in .libPaths()", but it also searches loaded namespaces — fix now, fixed a6bbeae.
- diff-bug #8: the DESIGN.md sentence said "already in the image" and "bspm fetched", wider than the two checks — fix now, fixed a6bbeae.
- blame-history #1: same as diff-bug #2 — fix now, fixed a6bbeae.
- blame-history #2: the DESIGN.md sentence overstated the check while the post-check was loose — fix now, fixed a6bbeae.
- blame-history #3: a default probe of `praise` fails every run if the image ever gains praise — reject (planned change: the plan gate chose failing over a fallback list).
- prior-review #1: same point as blame-history #3, no regression of an M001 or M002 review point found — reject (planned change).
- ripple #1: the phase 2 comment still said the dpkg check alone proves the r2u path — fix now, fixed a6bbeae.
- ripple #2: the ROADMAP candidate row still describes phase 2 as never asserting arrival — reject (false as staleness: post-merge hygiene graduates that row).
- ripple #3: the `SMOKE_PKG` env doc did not say the package must be absent — fix now, fixed a6bbeae.

Re-verified after a6bbeae (fresh image Id da8a31fb930f, `docker build` exit 0, hadolint exit 0, shellcheck `-S info` exit 0). Phase 2 sites now: `dpkg_state()` at line 143, pre-check at 156–167 (dpkg FAIL line 164), `find.package()` at 176 with exit 3 at 179 before `install.packages` at 181 (R FAIL line 189), install failure line 193, post-check at 197–211 (existing apt-binary line 205). AC2: default exit 0, the same three PASS lines and praise PASS line, r2u `Get:1 ... r-cran-praise`. AC3: `brms` exit 1, `dpkg check: r-cran-brms is installed`; `cmdstanr` exit 1, `found before the install: /usr/local/lib/R/site-library/cmdstanr`, then `R library check: find.package() found it`. AC4: `oolong` exit 1 after `installing *source* package`, `r-cran-oolong absent`. `dpkg_state()` probed against a live container: `r-cran-brms` → installed, `r-cran-nosuch` → empty, `binutils-common` after `dpkg -r` → config-files, a removed container → `?`.
