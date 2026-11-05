# M011: Fix the package persistence claim

- **Status:** in-progress
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

- [ ] AC1: No text in `README.md`, the `docker-compose.yml` comments, or the `start_*` and `stop_*` messages, each read in full, says that R packages a user installs stay in the home volume. The README's "Adding R Packages" section says that by default `install.packages()` puts packages in system library folders outside the home volume, and a run of the `noble` image that prints `.libPaths()` and `find.package()` for the installed packages shows those folders.
- [ ] AC2: The README says that in the shipped Compose setup, everything outside `/home/rstudio`, installed packages and `sudo apt install` libraries included, stays when the container is stopped and started, and is lost whenever Compose replaces the container. It names these examples: `docker compose down` then `up`, a newer image (such as one from the weekly rebuild) that a start launcher or `docker compose pull` and `up` brings in, and a changed `RS_PORT`. Quick start step 5 and the update FAQ say this or link to it. A Compose run of the `noble` image shows each named outcome for an apt binary installed through bspm, a package with no r2u binary at run time, and one `sudo apt install` package, and shows that a home directory file remains in every case.
- [ ] AC3: The README gives at least these two ways to keep packages: a saved list of install commands, kept in the home directory, with any `sudo apt install` lines included, and the derivative image that its "Baking packages" section shows. The saved list, written as the README shows it and rerun in a replaced Compose container, loads its packages again. The section's Dockerfile lists packages the image lacks, and a fresh container from that built image loads them.
- [ ] AC4: The README's two `docker run --rm` commands, in Option 1 and in the "Baking packages" section, each say that the command has no home volume, so files and packages are gone when the container ends. `docker image inspect` on the `noble` image shows no declared volume, and a file written to the home directory in a `docker run --rm` container is absent from the next one.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T2, T3
- AC4 → T1, T2

## Tasks

- [x] T1: Start Docker Desktop and run the observation on `noble`, using the shipped `docker-compose.yml` under its own project name (`-p m011`) and a free `RS_PORT`, so the user's `rstudio_home` volume is not touched. Note the digest of any local `latest` first, to restore it at cleanup.
  - Fresh container, before any bspm call: try `sudo apt install` on a package the image lacks. If it fails until `sudo apt update` runs, T2 fixes README line 162.
  - Install `praise` (apt binary) and a package with no r2u binary (`oolong` if apt shows none). Print `.libPaths()` and `find.package()`. Write a file in the home directory.
  - Compare container IDs and check all four items after each of: `docker compose stop` then `start`; a changed `RS_PORT`; `down` then `up`; and a newer image. Reinstall between cases. For the newer image, pull `noble-2026-10-26` or another older date tag, tag it `latest`, start, install, then run `docker compose pull` and `up -d`.
  - Run `docker image inspect` for declared volumes, and write a file in a `docker run --rm` container, then look for it in the next one.
- [x] T2: Write the README text from T1's output, for the sites AC1 to AC4 name. Follow the simple-english document rules for new text. Name the saved list as the way for Compose and launcher users. Change the Baking Dockerfile's package list to packages for which `find.package()` finds nothing in the image. Read the files AC1 names in full.
- [ ] T3: Run the README's own text. Write the saved list as shown, rerun it in a replaced Compose container, and check that its packages load. Build the Baking Dockerfile as shown and check that a fresh container loads its packages. Then remove the test containers, volumes, and images, restore any earlier local `latest`, and check that `rstudio_home` is unchanged.
- [ ] T4: Update `cairn/DESIGN.md`: Architecture states where installed packages live and when they are lost. If T1 shows no declared volume, correct the contract boundary line that lists a "`/home/rstudio` volume", marked `corrected M011`.

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

## Decisions

## Review
