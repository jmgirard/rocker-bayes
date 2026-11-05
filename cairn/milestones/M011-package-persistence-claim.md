# M011: Fix the package persistence claim

- **Status:** review
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP1, IP3
- **Resolves:** —
- **Surface tier:** user-facing — README text that image users read and act on
- **Branch/PR:** m011-package-persistence-claim

## Goal

The README says truthfully where installed R packages live, when they are lost, and how to keep them.

## Scope

**In:**
- Replace the false sentence in the README's "Adding R Packages" section with what a running container shows.
- State the rule for the shipped Compose setup, with examples. Carry it to Quick start step 5 and the update FAQ.
- Give two ways to keep packages: a saved install list and a derivative image. Change the "Baking packages" Dockerfile to packages the image lacks, because the three it lists are already baked in.
- Say at both `docker run --rm` commands that they have no home volume.
- Correct `cairn/DESIGN.md` where it calls `/home/rstudio` a volume of the base, if the run shows no declared volume, and record where packages live.

**Out:**
- An image change that keeps packages in the home volume: the user chose the text fix at the plan gate. A later plan can reopen it.
- A README recipe for a package folder in the home volume: same plan gate answer.
- The same false claim in rstudio2u, and the launcher stop messages: candidate row "Correct the claim in rstudio2u too".
- The `renv::restore()` speed claim: candidate row "Check the renv and bspm speed claim".
- The word "immutable" for the CmdStan tag: candidate row "Stop calling the CmdStan tag immutable".
- Using a derivative image through Compose and the launchers: candidate row "Run a derivative image with Compose".

## Acceptance criteria

- [x] AC1: No text in `README.md`, the `docker-compose.yml` comments, or the `start_*` and `stop_*` messages, each read in full, says that R packages a user installs stay in the home volume. The README's "Adding R Packages" section says that by default `install.packages()` puts packages in system library folders outside the home volume, and a run of the `noble` image that prints `.libPaths()` and `find.package()` for the installed packages shows those folders.
- [x] AC2: The README says that in the shipped Compose setup, by default, R packages a user installs and libraries a user adds with `sudo apt install`, when the image lacks them, stay when the same container is stopped and started, and are lost when Compose replaces the container. It names these examples: `docker compose down` then `up`, a newer image (such as one from the weekly rebuild) that a start launcher or `docker compose pull` and `up` brings in, and a changed `RS_PORT` that a start launcher or `docker compose up` applies. Quick start step 5 and the update FAQ say this or link to it. A run of the shipped compose file, on the image whose digest `noble` names on the run's date, with that digest recorded, shows each named outcome through one route the example names, for an apt binary installed through bspm, a package with no r2u binary at run time, and one `sudo apt install` package, each shown present just before the action, with container IDs compared and a home directory file as a control that remains in every case. The newer-image example starts from an older date tag and ends on that image.
- [x] AC3: The README gives at least these two ways to keep packages: a saved list of install commands, kept in the home directory, with any `sudo apt install` lines included, and the derivative image that its "Baking packages" section shows. The saved list, written as the README shows it and rerun in a replaced Compose container, loads its packages again. The section's Dockerfile lists packages the image lacks, and a fresh container from that built image loads them.
- [x] AC4: The README's two `docker run --rm` commands, in Option 1 and in the "Baking packages" section, each say that the command has no home volume, so files and packages are gone when the container ends. `docker image inspect` on the `noble` image shows no declared volume, and a file written to the home directory in a `docker run --rm` container is absent from the next one.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2, T5
- AC3 → T2, T3, T5
- AC4 → T1, T2

## Tasks

- [x] T1: Start Docker Desktop and run the observation on `noble`, using the shipped `docker-compose.yml` under its own project name (`-p m011`) and a free `RS_PORT`, so the user's `rstudio_home` volume is not touched. Note the digest of any local `latest` first, to restore it at cleanup.
  - Fresh container, before any bspm call: try `sudo apt install` on a package the image lacks. If it fails until `sudo apt update` runs, T2 fixes README line 162.
  - Install `praise` (apt binary) and a package with no r2u binary (`oolong` if apt shows none). Print `.libPaths()` and `find.package()`. Write a file in the home directory.
  - Compare container IDs and check all four items after each of: `docker compose stop` then `start`; a changed `RS_PORT`; `down` then `up`; and a newer image. Reinstall between cases. For the newer image, pull `noble-2026-10-26` or another older date tag, tag it `latest`, start, install, then run `docker compose pull` and `up -d`.
  - Run `docker image inspect` for declared volumes, and write a file in a `docker run --rm` container, then look for it in the next one.
- [x] T2: Write the README text from T1's output, for the sites AC1 to AC4 name. Follow the simple-english document rules for new text. Name the saved list as the way for Compose and launcher users. Change the Baking Dockerfile's package list to packages for which `find.package()` finds nothing in the image. Read the files AC1 names in full.
- [x] T3: Run the README's own text. Write the saved list as shown, rerun it in a replaced Compose container, and check that its packages load. Build the Baking Dockerfile as shown and check that a fresh container loads its packages. Then remove the test containers and volumes, restore any earlier local `latest`, and check that `rstudio_home` is unchanged. The test images stay until review's evidence run, which removes them.
- [x] T4: Update `cairn/DESIGN.md`: Architecture states where installed packages live and when they are lost. If T1 shows no declared volume, correct the contract boundary line that lists a "`/home/rstudio` volume", marked `corrected M011`.
- [x] T5: Fix what review pass 1 returned: the README's stop-and-start rule for the Compose setup and the other fix-now findings. Run bare `docker compose stop` and `start`, bare `pull` and `up -d`, and `RS_PORT` through a launcher. Run the list in a real RStudio session.

## Work log

- 2026-11-05: created by /milestone-plan.
- 2026-11-05: tier check: milestone — the row leaves a design choice open, correct the text or give packages a home in the volume.
- 2026-11-05: idea vet: gap, the row fits both a text fix and an image change with different user-visible behavior; the set answered "correct the README". gap, a home-volume library would still leave bspm's apt binaries in system folders and could hide newer image packages; the text fix avoids it. No flaw.
- 2026-11-05: lessons used: 2026-09-12 (M001) praise and oolong as bspm probes; 2026-10-20 (M006) read dpkg's Status line, not its exit status.
- 2026-11-05: collision check: absorbs the candidate row "Fix the package persistence claim"; M010 fixed only the compose comment; no D-entry bears on it. Inbox sweep: 0 open issues, 0 open PRs.
- 2026-11-05: question set: start Docker Desktop and download images for the check — yes, start it and download; test containers and volumes are removed afterward and `rstudio_home` is not touched.
- 2026-11-05: criteria audit (full mode, fresh Opus reader): 12 findings. Fixed in the wording: grep as the promise (1), flat claim given renv and `lib=` (2), unscoped stop and start (3), incomplete replace list, now a rule with examples plus `RS_PORT` (4), "weekly" as the only source of images (6), silent launcher pages (7), run location as a promise (8), `oolong` assumed binary-free (9), "two ways" (10), list location and apt lines (12), the second `--rm` site. Moved to T1: vacuous newer-image case (5), apt lists possibly empty (9). Narrowed: the derivative route is promised for a fresh container, not through Compose (11), with a candidate row. Added to T4: the DESIGN volume line.
- 2026-11-05: plan gate chose correcting the README over a home-library recipe or keeping packages by default, because bspm installs binaries system-wide (a base setting, IP1) and old copies in the volume can hide newer image packages; falsified by users needing packages across updates that a saved list and a derivative image cannot serve.
- 2026-11-05: test scope: no committed test for the altered claims; the evidence is T1 and T3's hand run. A smoke test phase was rejected because that script gates publishing, so a base change that keeps packages in the home volume would hold back every tag; falsified by this text going stale unnoticed after a base change.
- 2026-11-05: finding 11 of the audit disposed toward the narrower promise: a local-only image through the launchers hits the `pull` failure path and its offline warning, so the README names the saved list for Compose users.
- 2026-11-05: implement started on branch m011-package-persistence-claim; Docker Desktop started; T1 image download in progress, no README change yet.
- 2026-11-05: T1 done on `latest` (digest 2511d73a0dad, arm64, project m011, shipped compose file and mac launchers): `.libPaths()` is `/usr/local/lib/R/site-library`, `/usr/lib/R/site-library`, `/usr/lib/R/library`; `praise` went to the second, `oolong` (no r2u candidate) to the first; `sudo apt install` of libfftw3-dev worked before any bspm call, so README line 162 stands. All three items stayed through stop and start (same container ID) and were absent after `RS_PORT` change, `down` then `up`, and a launcher pull from `noble-2026-10-26` to `latest` (new container ID each time); the home file remained in all cases. No declared volume in the image config; a `--rm` file was absent from the next container. First script run read an empty package list inside the container and tested only the apt library and home file; fixed by passing the variables and failing on an empty list, then rerun in full.
- 2026-11-05: T2 done: new section "Keeping installed packages", plus Quick start step 5, the "Your work is saved" note, Option 1 step 5, the Adding R Packages bullet, the Baking Dockerfile and `--rm` note, the port FAQ, and the update FAQ. Baking now lists glmmTMB, mice, and metafor, which `find.package()` did not find in the image and which r2u has. README line 162 unchanged per T1. Older README text keeps its simple-english lint hits: restyling it is outside this scope.
- 2026-11-05: T3 done: the list and Dockerfile, extracted from README.md by script, both ran. In a replaced Compose container (0ed9c6ecfce6) `source("~/my_packages.R")` installed libfftw3-dev and loaded glmmTMB, mice, and metafor, all absent before. The built image loaded the same three from `/usr/lib/R/site-library`, each `r-cran-*` shown installed by dpkg. Project m011 and its volume removed. There was no local `latest` to restore and no `rstudio_home` volume existed before or after. Minor amendment: test images stay until review's evidence run.
- 2026-11-05: T4 done: DESIGN.md Purpose no longer lists a `/home/rstudio` volume in the base interface (no declared volume in the image), and Architecture says where installed packages live.
- 2026-11-05: T1's stop and start case and its newer-image case ran through `stop_mac.command` and `start_mac.command`, not bare `docker compose stop` and `start`; the Linux and Windows launchers were read, not run.
- 2026-11-05: claim audit: 26 claims read, 7 corrected — README.md
- 2026-11-05: claim audit dispositions: narrowed to "by default" in the note and section, narrowed "everything else" to changes you make, added the same-image and same-settings condition to stop and start, limited the published-image sentence to the start files, tied the update FAQ's loss to the next `up`, and qualified "Thanks to bspm". No change for the bind-mount case, because that text already says to keep work in the mounted folder, and none for the line near the top about binary installation. One re-read done; its one finding is fixed with no further pass.
- 2026-11-05: review return 1: AC2 fails as written, because the README states the stop-and-start outcome only for the launcher pair, not for the Compose setup (diff-bug #2). Fix with the fix-now findings in the Review section's pass 1.
- 2026-11-05: amendment routed: AC2 — "everything outside `/home/rstudio`" is false, because the image's own contents return in each new container (diff-bug #3).
- 2026-11-05: review return text fixes applied (checkpoint): stop and start rule, pinned and offline wording, labeled list, bind-mount note, Option 2 and apt links, DESIGN "by default". AC2's amended wording awaits its reader, and the bare Compose run and RStudio check are not done yet.
- 2026-11-05: re-audit: AC2 (full) — "any change stays" is false for files the base rewrites at start and for `/dev/shm`; `RS_PORT` named no route; flat "installed packages"; unresolved "or" in the evidence; `noble` against the shipped `latest`; domain too wide for the milestone's goal. Disposed toward the narrower promise: packages and apt libraries only, a route for `RS_PORT`, and the digest condition. "Each route" and a mount check were not added to the criterion, because either would widen it after a return; the review run covers those routes anyway.
- 2026-11-05: re-audit: AC2 (full) — "default folders" covers baked packages, which return in each new container, and shifts under renv; the digest clause cannot hold across the newer-image case and has no date; the "or" in the evidence is unresolved; "lost" can pass with nothing lost; the home file is a control, not a promise; "whenever" covers triggers the run does not sample. Second line for this criterion, so the wording goes to the user.
- 2026-11-05: amendment return: AC2 — "by default, R packages a user installs and libraries a user adds with `sudo apt install`, when the image lacks them, stay when the same container is stopped and started, and are lost when Compose replaces the container"
- 2026-11-05: AC2's whole amended text was approved by the user at a stop, after the second re-audit line, so no further reader ran. No further claim audit pass ran, by that step's one-pass rule; review's reviewers read the changed lines.
- 2026-11-05: T5 observed: bare `docker compose stop` and `start` kept all items (same container ID); bare `pull` and `up -d` from `noble-2026-10-26` lost them; `RS_PORT` through `start_mac.command` lost them, with the home file present each time. The container's only mount is `m011_rstudio_home` at `/home/rstudio`. In a real RStudio session reached in a browser, the console showed the same `.libPaths()`, `source("~/my_packages.R")` installed libfftw3-dev, and glmmTMB, mice, and metafor were found in `/usr/lib/R/site-library`. Earlier runs used `docker exec -u rstudio` with Rscript.

## Decisions

## Review

### Pass 2 (evidence at head d13be41, 2026-11-05)

The fix-now commit after this run changes README prose only, and the extracted list and Dockerfile are unchanged. Run through `docker exec -u rstudio` with Rscript on arm64. Full digest of `noble`, `latest`, and `noble-cmdstan2.40.0`: index digest sha256:2511d73a0dad7ae13bbebe13e2b490a44869a983bb9b29b02073c72e33cb6bbb, by `docker buildx imagetools inspect`. Each item was shown present in the state print before each action, and container IDs were compared.

AC1: read README.md, the `docker-compose.yml` comments, and the `start_*` and `stop_*` messages in full; none says user-installed packages stay in the home volume. "Adding R Packages" states the default folders. `.libPaths()` printed `/usr/local/lib/R/site-library`, `/usr/lib/R/site-library`, `/usr/lib/R/library`; `find.package()` put `praise` in the second and `oolong` in the first.

AC2: bare `docker compose stop` and `start` and the launcher pair kept `praise`, `oolong`, and libfftw3-dev with container 601d5805d1a9 unchanged. Each was then absent with a new container ID after `down` then `up`, `RS_PORT` through `up -d` and through `start_mac.command`, and a newer image from `noble-2026-10-26` through `start_mac.command` and through bare `pull` and `up -d`. The home file remained in every case. The README states the rule and names these examples; Quick start step 5 and the update FAQ link to it.

AC3: the README names both ways. The list, extracted from README.md and rerun in replaced container 69a40ff659e5, loaded glmmTMB, mice, and metafor, absent before, and installed libfftw3-dev. T5 also ran it in a real RStudio session. The extracted Dockerfile built, and a fresh container loaded the same three.

AC4: both `docker run --rm` commands carry the statement. The image config has no declared volume, and a file written in one `--rm` container was absent from the next.

Gate: `cairn_validate` passes; `hadolint Dockerfile` clean; `docker build` succeeds; base image names an explicit tag; no secret words; `.dockerignore` present; the diff touches no build context; changelog slot is none, so release notes hold user-visible changes. `dplyr` was found in `/usr/lib/R/site-library` in a fresh container, which backs the new sentence on packages the image includes.

Test project m011 removed. Two volumes that this work did not make, `rstudio2u_rstudio_home` and `rstudio2u-real-compose-test_rstudio_home`, appeared during this run, created 06:44Z and 06:47Z, with a `rstudio2u-real-compose-test` container running. They belong to other activity on this machine and were left alone. No `rocker-bayes` home volume exists.

spawned: diff-bug, blame-history, prior-review, ripple

- diff-bug #1: following the bind-mount note, `source("~/my_packages.R")` fails because the file is in the mounted folder — fix now.
- diff-bug #2: no record shows each item present before each action — fix now by this pass's evidence, which prints it.
- diff-bug #3: "those packages and libraries are lost" is false for `dplyr`, the README's own example, which the image includes — fix now.
- diff-bug #4: on an old pinned date tag, stale apt lists can make the list's apt line fail — reject (edge): only an old pin plus a removed apt version reaches it, outside common use, and apt prints its error.
- diff-bug #5: Option 2's "end the container" does not say stop rather than delete — follow-up, new row "Say what Option 2's rerun keeps" (parked, promote when a user reports it; the line is older text and no report exists).
- diff-bug #6: no statement or run covers whether rerunning `up --build -d` replaces the container — follow-up, same row.
- diff-bug #7: the digest was recorded as a prefix with its kind unnamed — fix now by this pass's full index digest.
- diff-bug #8: T5's runs record no digest — reject (false): AC2 needs one route, and this pass ties all routes to the digest.
- diff-bug #9: no record ties a run to the list as now written — fix now by this pass's extraction.
- diff-bug #10: no cleanup record covers the last runs — fix now by this pass's record, with final image removal at hygiene.
- diff-bug #11: no line records the full read AC1 asks for — fix now by the AC1 line above.
- diff-bug #12: paths and the list carry no variant limit, and only `noble` ran — reject (false): no criterion binds `resolute`, and both variants come from one Dockerfile and base recipe (GP5).
- diff-bug #13: "A newer image arrives" is not an action, and "they" came before its noun — fix now.
- diff-bug #14: "install them again" assumes the user knows what was installed — reject (planned change): the plan's saved list is the answer, in the linked section.
- diff-bug #15: a moved or renamed folder gives a new empty volume, so files look gone — follow-up, new row "Warn about moving the launcher folder" (parked, promote when a user reports it; the behavior predates this diff).
- diff-bug #16: the launcher half rests on the mac launchers — reject (false): AC2 needs one route, the log discloses this, and all three start files run pull then up.
- blame-history #1: the plan-gate choice has no D-entry, disputing pass 1 blame-history #1 — fix now, D-005 records it and states IP3's scope; the pass 1 reject is superseded.
- blame-history #2: the staff-writable library is now a stated fact with no D-entry note — reject (false): the text describes existing behavior, and D-004 records why no boundary applies.
- prior-review: no finding; the only related record is the M010 audit row this milestone fixes.
- ripple #1: the `docker-compose.yml` comment has no package exception — reject (false): it speaks only of the home directory's files and settings.

### Pass 1 (head 2e28f6f, 2026-11-05)

No box ticked in this pass, because AC2 returns to implement and the fixes change the text that AC1, AC3, and AC4 read.

Evidence: `latest` and `noble` have one digest (sha256:2511d73a0dad, by `docker buildx imagetools inspect`), run on arm64 through `docker exec -u rstudio` with Rscript. AC1's `.libPaths()` and AC2's stop and start, `RS_PORT`, down and up, and launcher-pull outcomes all matched T1, for `praise`, `oolong`, and libfftw3-dev, with the home file present in every case. AC3's extracted list and Dockerfile ran, and AC4's inspect and `--rm` file case passed.

Gate: `cairn_validate` passes; `hadolint Dockerfile` clean; `docker build` succeeds; base image names an explicit tag; no secret words in the Dockerfile; `.dockerignore` present; the diff touches no build context; changelog slot is none. Main has not moved.

spawned: diff-bug, blame-history, prior-review, ripple

- diff-bug #1: a user who took the bind-mount edit has no volume on `/home/rstudio`, so `~/my_packages.R` is lost — fix now.
- diff-bug #2: AC2 says the README states stop and start stay in the Compose setup, but it states this only for the launcher pair — fix now, floor return (AC failing).
- diff-bug #3: AC2's "everything outside `/home/rstudio`" is false, because image contents return in each container — amendment routed, the README's narrower wording is right.
- diff-bug #4: T1's task text named bare `docker compose` commands and the run used the launchers — fix now, run the bare forms.
- diff-bug #5: the record does not name the user or session, and the README sends users to the RStudio console — fix now, record the user and run the steps in a real RStudio session.
- diff-bug #6: "newest image" and "any start" are false for a pinned tag in `docker-compose.yml` — fix now.
- diff-bug #7: "each time they run" is false offline, when a failed pull starts the local copy — fix now, "try to".
- diff-bug #8: "The start files use the published image" is flat, but they use what the compose file names — fix now.
- diff-bug #9: the FAQ's "work in the home volume is preserved" follows the `docker pull` route, whose `--rm` users have no volume — reject (false): the sentence is scoped to the home volume, and Option 1 step 5 states `--rm` has none.
- diff-bug #10: criteria name `noble` and T1 ran on `latest`; only arm64 ran — fix now for the tag by the digest comparison above; reject (false) for architecture, because no criterion binds one.
- diff-bug #11: DESIGN.md's package line is flat where the README says "by default" — fix now.
- diff-bug #12: the top README line promises "no compiling" with no qualifier — reject (false): its subject is binary installation.
- diff-bug #13: the replacement list omits other triggers — reject (planned change): the plan chose a rule with named examples, and the list says "For example".
- diff-bug #14: a one-off `RS_PORT=8888 docker compose up -d` then a launcher start replaces the container, unwarned — reject (false): that is a changed `RS_PORT`, which the rule names.
- diff-bug #15: "no `rstudio_home` volume" would miss a prefixed name — reject (false): the check greps the substring, so `rocker-bayes_rstudio_home` matches.
- diff-bug #16: `system()` returns a status, so a failed apt line does not stop `source()` — reject (edge): only a failed `sudo apt install`, outside common use, reaches it, and apt prints its error in the console.
- diff-bug #17: the example pairs libfftw3-dev with packages that do not need it — fix now, label the lines.
- diff-bug #18: Quick start step 5 and the FAQ are narrower than the rule — reject (planned change): AC2 allows a link.
- diff-bug #19: Option 2 got no package note or link — fix now.
- diff-bug #20: "7 corrected" beside six listed items, and a dangling "— README.md" — reject (false): 7 is the reader's count, and the line takes its fixed shape.
- blame-history #1: no D-entry for rejecting a home-volume library — reject (false): the plan-gate work-log line records it, and the archive summary's Decisions line carries it.
- blame-history #2: stop launchers still say "resume where you left off" — follow-up, candidate row "Correct the claim in rstudio2u too" (normal), which already holds it.
- blame-history #3: step 5 is narrower than the rule — reject (planned change), as diff-bug #18.
- blame-history #4: a base-owned DESIGN line now rests on this image's config — reject (false): an image inherits a declared volume, so an empty config shows the base declares none.
- prior-review: no prior-review evidence touching this diff; the PR comment probe returned none.
- ripple #1: the top README line — reject (false), as diff-bug #12.
- ripple #2: the renv speed claim — follow-up, candidate row "Check the renv and bspm speed claim" (low), which already holds it.
- ripple #3: the ROADMAP row still describes the bug — reject (false): hygiene graduates it at merge.
- ripple #4: stop messages say work is preserved — follow-up, candidate row "Correct the claim in rstudio2u too" (normal).
- ripple #5: IP3 needs a scope note — reject (false): IP3 names the home volume and stays true.
- ripple #6: the `sudo apt install` bullet has no link — fix now.
- ripple #7: the FAQ's "work" could read as packages — reject (false): the next sentence covers packages.
