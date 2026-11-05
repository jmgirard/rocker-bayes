<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M016: Resync the launchers from rstudio2u

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP7, IP4
- **Resolves:** —
- **Surface tier:** user-facing — students read the launcher output this changes
- **Branch/PR:** m016-resync-launchers

## Goal

Make this repo's seven launcher files match rstudio2u's at commit `4b181de`, apart from the project's names, so launcher users here get the offline reminder that rstudio2u ships.

## Scope

**In:** Copy `start_linux.sh`, `start_mac.command`, `start_windows.bat`,
`stop_linux.sh`, `stop_mac.command`, `stop_windows.bat`, and
`launcher_common.sh` from rstudio2u at `4b181de`, with one name map: the
project name `rocker-bayes` in the Starting and Stopping lines, and the
Compose service `bayes` in `docker compose port` (IP4). This brings in the
reminder that repeats the skipped-update warning after the running banner,
the window hold after a skipped update, and the test seam markers. A README
Quick start sentence states the offline behavior. DESIGN.md's Launchers
family names the sync commit. The Windows reminder is not run here: it rests
on rstudio2u's Windows scenario suite at `4b181de` and on AC1's byte match
apart from names.

**Out:**
- Porting rstudio2u's launcher scenario tests: GP7 ports tests only for a
  file that diverges, and after the sync only names differ. DESIGN.md's Known
  issues entry on unported launcher tests stays.
- rstudio2u's false `git archive` comment in `.gitattributes` and its CRLF
  guard's bare-CR miss: new candidate row "Fix rstudio2u's CRLF guard and
  claim". This milestone copies neither file.
- The `stop_*` "resume where you left off" text, which is the same in both
  repos: candidate row "Correct the claim in rstudio2u too".
- A check that catches later drift from rstudio2u: new candidate row "Catch
  launcher drift from rstudio2u".

## Acceptance criteria

- [x] AC1: Each of the seven launcher files (`start_linux.sh`, `start_mac.command`, `start_windows.bat`, `stop_linux.sh`, `stop_mac.command`, `stop_windows.bat`, `launcher_common.sh`) in the branch head's tree has the same bytes as rstudio2u's blob of that file at commit `4b181de`, passed through `LC_ALL=C sed -e 's/compose port rstudio2u /compose port bayes /' -e 's/rstudio2u/rocker-bayes/g'`. `cmp` exits 0 for each of the seven, and `git diff --summary main...HEAD` lists no mode change.
- [x] AC2: With `docker compose pull` exiting non-zero and a local copy of the service's image present, through a Compose file whose service `bayes` has both `image:` (a local-only tag) and `build:`, as `docker-compose.yml` does, `start_mac.command` and `start_linux.sh`, each run once on this Mac with `RS_LAUNCHER_NONINTERACTIVE=1` and their own `COMPOSE_PROJECT_NAME` and `RS_PORT`, print the line that begins `⚠️  Reminder: the update was skipped` after the `RStudio Server is running` banner, then `RStudio keeps running after you close this window.`, and exit 0. A run of each whose pull succeeds prints neither line.
- [x] AC3: README's Quick start says that when a launcher cannot download the image and a copy is already on the computer, it starts that copy and says the update was skipped, and that with no copy it stops with an error.
- [ ] AC4: At the branch head, shellcheck 0.11.0 `-x -S info` reports nothing on every tracked `*.sh` and `*.command` file, as shown by `lint.yml`'s job on the pull request.

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T3
- AC4 → T1

## Tasks

- [x] T1: Write the seven files from `git -C ../rstudio2u show 4b181de:<file>` through AC1's `sed`, keeping each file's mode. Run the AC1 `cmp` loop, the CRLF guard `.github/tests/test_launcher_line_endings.sh`, and a containerized shellcheck 0.11.0 on the changed files from inside the checkout (LESSONS M002).
- [x] T2: Write a scratch Compose file in the session scratchpad, passed by absolute path in `COMPOSE_FILE`, with service `bayes`, `image: rocker-bayes:dev` (local only, so the pull fails), and `build:`. Run `start_mac.command` and `start_linux.sh` under `RS_LAUNCHER_NONINTERACTIVE=1` with their own `COMPOSE_PROJECT_NAME` and `RS_PORT` (LESSONS M011). Run the control with an image that pulls, such as `jmgirard/rstudio2u:latest`. Take each project down after its run.
- [x] T3: Add the README Quick start sentence (AC3), matched to rstudio2u's README line 218, and name `4b181de` and the name map in DESIGN.md's Launchers family.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: not run — work named at the question set.
- 2026-11-05: question set: which candidate to take — "Resync the launchers from rstudio2u"; where rstudio2u's `.gitattributes` claim and guard miss go — a candidate row here, no companion PR.
- 2026-11-05: idea vet: gap — whether to port rstudio2u's launcher scenario tests; reading taken: no port, since GP7 ports tests only for a diverging file and users see the same launchers either way. No flaw found.
- 2026-11-05: lessons used: 2026-09-12 (M002) on Docker Desktop mounts, 2026-11-05 (M011) on isolating launcher runs, 2026-11-05 (M013) on `git archive` line endings, 2026-11-05 (M014) on Compose with `image:` and `build:`.
- 2026-11-05: collision check: source row "Resync the launchers from rstudio2u" absorbed in full; its rstudio2u faults go to a new row by the question set. No D-entry, archive, or open issue or PR overlaps. Inbox: 0 open issues, 0 open PRs.
- 2026-11-05: plan gate chose a byte match against a pinned rstudio2u commit over a hand-edit of the missing reminder, because a byte match makes "synced" checkable; falsified by a launcher change this repo needs that rstudio2u does not take.
- 2026-11-05: plan gate chose no ported scenario tests over porting rstudio2u's stubbed-docker suites, because GP7 ports tests only for a diverging file; falsified by a launcher bug here that rstudio2u's suite passes.
- 2026-11-05: criteria audit (full mode, fresh Opus reader): AC1 no finding. AC2 narrowed to "pull exiting non-zero" and to a Compose file with both `image:` and `build:`, scratch file moved to the scratchpad. AC3 narrowed to the pull-failed and no-copy conditions. AC4 was bound to two CI jobs; narrowed to shellcheck on the files, line-endings half dropped as covered by AC1. Windows reminder unverified by any run here; Scope now states its reliance on rstudio2u's suite and AC1.
- 2026-11-05: implement started; branch `m016-resync-launchers` cut from `ee2cad4`. The verify slot's hadolint and build apply only to Dockerfile or build-context changes, and no task touches those, so shellcheck stands in.
- 2026-11-05: T1 done. The seven files were written by `sed` from rstudio2u's blobs, not by the Write tool, so the CRLF bytes stay exact. `cmp` matched all seven. The CRLF guard passed on the staged blobs (244 and 12 lines), shellcheck 0.11.0 `-x -S info` was clean on every tracked `*.sh` and `*.command`, and the modes did not change.
- 2026-11-05: T2 done. The scratch Compose files are in the scratchpad: service `bayes` with `build:`, using `rocker-bayes:dev` (pull denied, the image is local) for the offline runs and `jmgirard/rstudio2u:latest` (pulls) for the control. The project names were `m016-<mode>-<launcher>` on port 18797. Both offline runs printed the warning, the banner, the reminder, and then the keeps-running line, and exited 0. Both control runs exited 0 with neither line. All four projects were taken down with `down -v`.
- 2026-11-05: T3 done. README Quick start step 4 states the pull-failed and no-copy behavior, worded from T2's output and the `Could not download the latest image.` branch in `start_mac.command`. DESIGN.md's Launchers family names `4b181de` and the name map. The Simple English hook reported 31 hits in older README text, which the low row "Clear the README's plain-English hits" holds, and none in the added lines, so they were left alone.
- 2026-11-05: claim audit: 19 claims read, 0 corrected — launcher_common.sh, start_linux.sh, start_mac.command, start_windows.bat, README.md. One claim was unverifiable here: Compose 5.6.1 exits 1 with "no port 8787/tcp" when an override drops `ports`. The test-seam comments refer to rstudio2u's scenario suites, which this repo does not port (Scope Out).
- 2026-11-05: implement complete; status set to review.

## Decisions

## Review

- AC1 evidence (2026-11-05, head `5fe8211`): `cmp` exited 0 for 7 of 7 files. Each compared `git show HEAD:<file>` with rstudio2u's `4b181de` blob through AC1's `sed`. `git diff --summary main...HEAD` printed nothing, so no mode changed.
- AC2 evidence (2026-11-05, head `5fe8211`): fresh runs, port 18798, projects `m016r-*`, scratchpad Compose files with service `bayes`, `image:` and `build:`. Offline (`rocker-bayes:dev`, pull access denied, image local): `start_mac.command` and `start_linux.sh` each exited 0, with the banner at log line 27, the reminder at 32, and the keeps-running line at 36. Control (`jmgirard/rstudio2u:latest`, pull worked): each exited 0 with neither line. All projects were removed and no `m016r` container is left.
- AC3 evidence (2026-11-05, head `5fe8211`): README.md lines 93–95 in Quick start step 4 say that when the launcher cannot download the image and a copy is on the computer, it starts that copy and says the update was skipped, and that with no copy it stops with an error. The first part matches AC2's runs. The second matches the `Could not download the latest image.` branch with `exit 1` in start_mac.command:64, start_linux.sh:58, and start_windows.bat:80.
- AC4 local evidence (2026-11-05, head `5fe8211`): containerized shellcheck 0.11.0 with `-x -S info` exited 0 over the 23 files that `git ls-files '*.sh' '*.command'` lists. The box waits for `lint.yml`'s job on the PR, which the criterion names.
