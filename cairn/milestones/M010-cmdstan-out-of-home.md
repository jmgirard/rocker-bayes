<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M010: Give old home volumes the new CmdStan

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** high   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** IP1, IP3, GP3, GP4   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — it changes where the image keeps CmdStan and what every user's session runs   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m010-cmdstan-out-of-home   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

A user whose home volume was made by an older image gets the image's own CmdStan after an update, with no volume wipe.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** CmdStan is installed to `/opt/cmdstan`, owned `root:staff` and group
writable, and the Dockerfile sets `ENV CMDSTAN=/opt/cmdstan/cmdstan-${CMDSTAN_VERSION}`.
The base image's `/etc/cont-init.d/01_set_env` copies container variables into
`Renviron.site`, so RStudio sessions see it. The smoke test gets a fourth phase
that boots the image on a volume holding a stale `~/.cmdstan`. The README,
`docker-compose.yml`, and DESIGN.md say where CmdStan now lives, how to remove
the old folder, and how to use a CmdStan of one's own.

**Out:**
- Deleting the old `~/.cmdstan` from existing volumes: never done implicitly
  (IP3). The README gives the user the command.
- A link at `/home/rstudio/.cmdstan` pointing to `/opt/cmdstan`: rejected at
  the plan gate (work log).
- Checking that the CmdStan in an image matches its `<variant>-cmdstan<v>` tag
  against the Dockerfile pin from CI: the candidate row "Check CmdStan matches
  the version tag".
- A git tag and GitHub release for this recipe change (D-002): the user
  declares that window, through `/cairn-release`.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets.
     Every item opens with its positional label — `ACn:` — the item's
     position counted top-to-bottom, the number Coverage cites; an
     insertion, removal, or reorder renumbers the labels and the Coverage
     lines together. -->

- [ ] AC1: With `/home/rstudio` mounted from a named volume whose `.cmdstan`
      holds only a `cmdstan-2.36.0` directory, as an earlier image would have
      left it, an image built from this branch, run as the `rstudio` user with
      `CMDSTAN` removed from the process environment so that only
      `Renviron.site` supplies it (as in an RStudio session), reports
      `/opt/cmdstan/cmdstan-<pin>` from `cmdstanr::cmdstan_path()` and `<pin>`
      from `cmdstanr::cmdstan_version()`, where `<pin>` is the Dockerfile's
      `ARG CMDSTAN_VERSION` value.
- [ ] AC2: An image built from this branch has no `/home/rstudio/.cmdstan`
      path (`docker run --rm --entrypoint test <image> ! -e /home/rstudio/.cmdstan`
      exits 0), so a new home volume gets no `.cmdstan` folder.
- [ ] AC3: `.github/smoke-test.sh`, with its new phase, passes every phase on
      all four legs of a `docker.yml` `test_mode` dispatch run from this
      branch, and on a noble image built locally from this branch.
- [ ] AC4: In each of two containers started from this branch's image, one
      with default settings and one with `USERID=1501` set at `docker run`,
      the `rstudio` user compiles and samples
      `.github/smoke-fixtures/bernoulli.stan` with
      `cpp_options = list(stan_threads = TRUE)`.
- [ ] AC5: With `CMDSTAN=<dir>` written to `/home/rstudio/.Renviron`, where
      `<dir>` is a directory other than the image's whose `makefile` names a
      CmdStan version, `cmdstanr::cmdstan_path()` run as the `rstudio` user
      with `CMDSTAN` removed from the process environment reports `<dir>`.
- [ ] AC6: No hit of `grep -n -i cmdstan README.md docker-compose.yml` says
      the home volume holds CmdStan. A README FAQ entry says that a home volume
      made by an earlier image keeps a `~/.cmdstan` folder this image no longer
      reads, and gives the commands to see its size and to delete it, with a
      warning that the folder can hold a CmdStan the user installed and points
      `CMDSTAN` at. The README says how to use a CmdStan of one's own by setting
      `CMDSTAN` in `~/.Renviron`, and that a derived image that installs its
      own CmdStan must set `CMDSTAN` too.
- [ ] AC7: `bash .github/tests/test_install_cmdstan.sh` passes, hadolint run
      from the image that `pr-ci.yml`'s `hadolint/hadolint-action@v3.5.0` step
      uses reports nothing on the Dockerfile, and the pinned shellcheck that
      `.github/workflows/lint.yml` runs passes at `-S info` over every tracked
      `*.sh` and `*.command` file.

## Coverage
<!-- owner: plan · create/amend-via-gate; each acceptance criterion → the
     task(s) satisfying it, by positional number (AC/Task counted
     top-to-bottom). Review reads to fence evidence — tracking-rules "AC fencing". -->

- AC1 → T1, T2, T3, T4
- AC2 → T1, T4
- AC3 → T3, T4, T6
- AC4 → T1, T4
- AC5 → T2, T4
- AC6 → T5
- AC7 → T1, T2, T3

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate. Every item opens with its positional label —
     `Tn:` — the item's position counted top-to-bottom, the number Coverage
     cites; an insertion, removal, or reorder renumbers the labels and the
     Coverage lines together. -->

- [x] T1: Test first: change the expected calls in
      `.github/tests/test_install_cmdstan.sh` (line 98) to `/opt/cmdstan` and
      a `root:staff` owner with `chmod -R g+ws` (add a `chmod` stub), and see
      the suite fail. Then change `install_cmdstan_step` in
      `scripts/install_bayes.sh` (lines 46–59): install into `/opt/cmdstan`,
      drop the build-session `set_cmdstan_path()` call, and set the owner and
      mode as `main` does for the site-library. Run the suite green.
- [x] T2: In the Dockerfile, add `ENV CMDSTAN=/opt/cmdstan/cmdstan-${CMDSTAN_VERSION}`
      after the `RUN` (before it, cmdstanr warns during the build that the
      directory does not exist yet). Confirm the `docker.yml` grep for
      `^ARG CMDSTAN_VERSION=` (lines 92, 268) still reads one value. Run
      hadolint from the image the action uses.
- [x] T3: Add phase 4 "old home volume" to `.github/smoke-test.sh`. It
      creates a named volume whose name the script generates from `$NAME`,
      seeds it through a mount at a path the image does not populate with
      `.cmdstan/cmdstan-2.36.0/makefile`, owned by the image's `rstudio`
      user, and boots a second container on it. It runs
      `env -u CMDSTAN Rscript` as `rstudio` and fails with its own FAIL line
      unless the path equals the image's `CMDSTAN` under `/opt/cmdstan/` and
      the version equals the image's `CMDSTAN_VERSION`. The EXIT trap removes
      both containers and that volume and never touches `rstudio_home`.
      Update the header to four phases and the phase 3 comment (lines
      217–220). Write R comments without apostrophes (M007 lesson). Control:
      run the script against `rocker-bayes:dev` built from `main` before
      this change and record phase 4's FAIL line. Run shellcheck.
- [x] T4: Build noble locally (`docker build -t rocker-bayes:dev .`) and run
      the full smoke test. Read the pin from the Dockerfile and compare it
      with phase 4's output for AC1. Run the AC2 command. For AC4, start two
      containers (default, `USERID=1501`) and compile and sample the fixture
      with `stan_threads = TRUE` as `rstudio`. For AC5, write `CMDSTAN=<dir>`
      to `~/.Renviron` with a stub CmdStan directory and read the path with
      `env -u CMDSTAN Rscript`. Record each result in the work log.
- [x] T5: README: rewrite the "Your work is saved" note, add the FAQ entry
      on the old `~/.cmdstan` folder (`du -sh ~/.cmdstan`, then
      `rm -rf ~/.cmdstan` after the warning), and add the `~/.Renviron`
      and derived-image notes. Fix the `docker-compose.yml` volume comment.
      Update DESIGN.md's Image build family and Architecture to say CmdStan
      lives in `/opt/cmdstan` and is found through `CMDSTAN`.
- [x] T6: Push the branch and start one `docker.yml` dispatch with
      `test_mode=true` from it (granted at the plan gate). Record the run URL
      and each leg's smoke result.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-10-20: created by /milestone-plan.
- 2026-10-20: tier check: milestone — the fix needs a design choice (move CmdStan or refresh it at start) and changes the image layout.
- 2026-10-20: absorbed the candidate row "Give old home volumes the new CmdStan"; collision sweep found no D-entry or archived milestone on the CmdStan location; the row "Check CmdStan matches the version tag" stays separate.
- 2026-10-20: inbox sweep found 0 open issues and 0 open PRs.
- 2026-10-20: lessons harvested: M008 stub suite for the install script, M007 no apostrophes in smoke R comments, M002 Docker Desktop shares home but not /tmp (seed with named volumes), M001 test_mode dispatch for branch evidence.
- 2026-10-20: base facts read from rocker-bayes:dev: cmdstanr 0.9.0 reads `CMDSTAN` first; `01_set_env` copies container variables into `Renviron.site`; `rstudio` is uid 1002 and in `staff`; `USERID` re-creates the user and adds `staff`; the current `~/.cmdstan` is 1.3 GB.
- 2026-10-20: criteria audit (full mode, fresh Opus reader) returned findings on all six drafts; fixed: smoke-phase and suite wording moved from AC1 and AC7 to tasks, AC2 narrowed to the `.cmdstan` folder, AC4 split into two containers, `~/.Renviron` check added as AC5, AC6 widened to `docker-compose.yml` with a delete warning, "no longer reads" and a derived-image note, hadolint pinned to the action's image, ENV placed after RUN (T2), smoke volume named by the script (T3); declined toward the narrower promise: a stale-volume run under `USERID=1501` and an ownership criterion (AC4 tests the write).
- 2026-10-20: AC3 takes the audit reader's own suggested wording for the test_mode answer, so it did not go back through the audit.
- 2026-10-20: question set: test_mode dispatch of docker.yml from the branch — granted (it pushes four untagged images to Docker Hub).
- 2026-10-20: question set: README on the old folder — size and delete commands, with a warning.
- 2026-10-20: plan gate chose /opt/cmdstan plus `CMDSTAN` over copying CmdStan into `~/.cmdstan` at start because the copy adds about 1.3 GB per version to each volume and slows the first start; falsified by a cmdstanr release that ignores `CMDSTAN` or a base that stops copying container variables into `Renviron.site`.
- 2026-10-20: plan gate chose no link at `/home/rstudio/.cmdstan` because a user's `install_cmdstan()` would write into the image layer and lose it at update; falsified by a derived image or user script that breaks on the old path.
- 2026-10-20: plan gate chose the image pin over a user-installed CmdStan, with a `~/.Renviron` override, because old volumes always hold a copy and would keep the stale one; falsified by users whose own CmdStan is overridden with no notice they can find.
- 2026-10-20: implement started on branch m010-cmdstan-out-of-home; the pre-change image is kept locally as rocker-bayes:pre-m010 for controls.
- 2026-10-20: T1 done: the suite went red on the old `/home/rstudio/.cmdstan` calls (2 failures), then green after the step moved to `/opt/cmdstan` with `chown -R root:staff` and `chmod -R g+ws`; added a check that the R program names no `/home/rstudio`.
- 2026-10-20: T2 done: `ENV CMDSTAN` placed after the RUN; the `^ARG CMDSTAN_VERSION=` grep still reads one value (2.40.0); hadolint-action v3.5.0 runs hadolint v2.15.1 (its Dockerfile), and that image reports nothing.
- 2026-10-20: T3 done: phase 4 added; it compares with the image's own `CMDSTAN` and `CMDSTAN_VERSION` and checks the version first, so a stale pick gets its own FAIL line; shellcheck v0.11.0 `-S info` clean.
- 2026-10-20: T3 control 1: smoke against rocker-bayes:pre-m010 passed phases 1-3 and failed phase 4 with "cmdstanr picked CmdStan 2.36.0 at /home/rstudio/.cmdstan/cmdstan-2.36.0, not the image's 2.40.0"; no smoke volume left after.
- 2026-10-20: T3 control 2: branch image with `/etc/cont-init.d/01_set_env` removed passed phases 1-3 and failed phase 4 the same way, so removing `CMDSTAN` from the R process is what makes the phase test the Renviron.site route.
- 2026-10-20: T4 done (noble arm64, this Mac): build ok; smoke passed all four phases, phase 4 reporting /opt/cmdstan/cmdstan-2.40.0 and 2.40.0, the Dockerfile pin; AC2 command exit 0; /opt/cmdstan is root:staff drwxrwsr-x.
- 2026-10-20: T4 AC4: threaded compile and sample passed as rstudio uid 1002 and as uid 1501 (`USERID=1501`), each writing main_threads.o into /opt/cmdstan; AC5: with `CMDSTAN` in ~/.Renviron pointing at a stub cmdstan-2.39.0, `cmdstan_path()` reported that directory.
- 2026-10-20: T5 done: README note and two FAQ entries, compose comment, DESIGN Image build, CI and Architecture lines; the simple-english lint total on README.md is 39 on main and on the branch, so the added lines add none.
- 2026-10-20: T6 started: branch pushed; docker.yml dispatched with test_mode=true, run https://github.com/jmgirard/rocker-bayes/actions/runs/39545142917.
- 2026-10-20: claim audit: 24 claims read, 1 corrected — README.md, docker-compose.yml (the rewrapped volume note said installed R packages persist in the home volume; they install to the site library, so "and installed R packages" was dropped; the same claim in older README text became the candidate row "Fix the package persistence claim").
- 2026-10-20: T6 done: run 39545142917 on 0d10372 succeeded; noble and resolute on amd64 and arm64 each printed "PASS: phase 4 (old home)" with /opt/cmdstan/cmdstan-2.40.0 and "PASS: smoke test (... + old home)"; publish ran in test_mode, notify skipped. 01ddecd after it changes only README.md, docker-compose.yml and cairn/, which are outside the build context.
- 2026-10-20: implement done; status set to review.

## Decisions
<!-- owner: implement / review · append-only; milestone-local. -->

## Review
<!-- owner: review · exclusive. -->
