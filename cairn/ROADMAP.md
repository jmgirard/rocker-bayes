# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-09-13 (M003 done and archived, retry row promoted, 3 candidate rows added and 2 extended, caps and byte budgets clean)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->
| M004 | Rerun a weekly build that failed on the r2u mirror | in-progress | M003 | high | milestones/M004-weekly-leg-retry.md |
| M003 | Unattended-rebuild alerts and schedule keepalive | done | M001, M002 | normal | milestones/archive/M003-unattended-rebuild-alerts.md |
| M002 | Pre-merge CI lane and lint | done | M001 | normal | milestones/archive/M002-pre-merge-ci-lane.md |
| M001 | Smoke-test gate before any tag moves | done | — | high | milestones/archive/M001-smoke-test-publish-gate.md |

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- [high] After M004 merges, check the live retry on the first scheduled run that fails on the r2u mirror: `rebuild-retry.yml` starts, reruns only the failed jobs, and a green attempt 2 closes the ci-failure issue. No run before merge can show this, because `workflow_run` starts only from the default branch's copy. Promote to a hotfix if a qualifying scheduled failure starts no retry run — added 2026-09-13 — M004 plan gate
- [high] Smoke phase 2 cannot tell a fresh bspm fetch from a package the image already carries: it asserts `library()` plus `dpkg -s`, never that the package arrived this run. Assert absence before installing. Relatedly, the compile control fails at stanc parse time, so no control covers a broken C++ toolchain — added 2026-09-12 — M001 review F3, F12
- [high] No workflow runs `.github/tests/test_publish_guard.sh`, and `.github/tests/**` is absent from the push paths filter, so the guard can drift from what `docker.yml` calls it with. M002 lints shell files and M003 runs the three ported suites, so neither covers it — added 2026-09-12 — M001 review F8, M003 review N5
- [high] `scripts/install_bayes.sh` still builds the `install_cmdstan()` call by interpolating `CMDSTAN_VERSION` into R source. The M002 quoting fix stops whitespace from splitting it, but a value carrying a double quote still rewrites the call. Read it with `Sys.getenv()` instead, the convention `smoke-test.sh` already follows — added 2026-09-12 — M002 review
- [high] Nothing asserts a leg's digest was built from the base tag its variant claims. A matrix edit setting `base_tag: noble` on a resolute row passes every gate and ships noble bytes under the resolute tag. Read an OS-release or base label out of the pulled image, as the arch assertion reads `{{.Architecture}}` — added 2026-09-12 — M001 review F14
- CmdStan is compiled into `/home/rstudio/.cmdstan`, which the compose home volume captures on first run; an image update does not refresh CmdStan for existing users until the volume is wiped. Move it outside the home directory or refresh at start — added 2026-09-03 — cairn/DESIGN.md Architecture
- A `keepalive` failure alone fails the scheduled run, and `rebuild-gap.yml` counts only `--status success` runs, so a deleted deploy key raises a false "no successful rebuild" alert on the second week while tags move. The 50-day threshold leaves one weekly chance before GitHub's 60-day cutoff. The keepalive comment says a branch dispatch reaches nothing new, but any workflow pushed to any branch can read the key secret — added 2026-09-13 — M003 review N3, O7, O8, O6
- Alerts that fail quietly: `ci-failure-issue.sh` reads `gh issue list` through process substitution, so a failed listing reads as "none open" and opens a duplicate or leaves an issue open. A `rebuild-gap.sh` refusal (exit 2) and a broken `ci-failure-issue.sh` in `notify` fail the job with no issue. `notify` strips `job=` with `sed | xargs`, so an empty result from a job misspelled in `RESULTS` is dropped and the rest can close the issue — added 2026-09-13 — M003 review O4, O11, N6, N7
- Digest artifacts are named by digest alone and merged flat, so two legs building byte-identical images collapse to one file and the guard blocks with a wrong-cause message. Name them `<variant>-<arch>` — added 2026-09-12 — M001 review F7
- Phase 1 never touches the published host port when the image declares a HEALTHCHECK, because the healthcheck requests `localhost:8787` from inside the container. Add a host-side probe — added 2026-09-12 — M001 review F18
- The manifest guard compares the architecture list against the exact string `amd64 arm64`, so an index naming a third architecture as well is refused though it satisfies AC5. Use a subset check — added 2026-09-12 — M001 review F13
- The push paths filter includes `.github/smoke-test.sh` and the fixtures, but `.dockerignore` excludes `.github` from the build context, so a comment typo rebuilds four legs and re-points `latest` at an identical image — added 2026-09-12 — M001 review F9
- `pr-ci.yml` triggers a full noble build on any `.github/workflows/**` edit, including a comment-only change to the publish lane. Same class as the `docker.yml` paths row above, in the other workflow — added 2026-09-12 — M002 review
- A `paths` filter plus a required status check leaves a pull request that touches none of those paths waiting forever for a check that never runs. Neither workflow declares a `merge_group` trigger either, so a merge queue merges unchecked — added 2026-09-12 — M002 review
- The shell lint pathspec covers `*.sh` and `*.command` only. An extensionless script or a `.bash` file is never linted, and the enumeration count still reads as if coverage were complete — added 2026-09-12 — M002 review
- [low] Neither `pr-ci.yml` nor `lint.yml` sets a `concurrency` group, so several quick pushes to one pull request each start a full build and none is cancelled. M003's `script-tests` job in `pr-ci.yml` has none either — added 2026-09-12 — M002 review, M003 review P2
- [low] Dispatch and cancel side effects of `notify`: its `always()` gate reports a cancelled scheduled run (`cancelled skipped success`) as a failure. A branch dispatch with `notify` and without `test_mode` skips `publish` and opens an issue. A green `notify` dispatch, or a manual rerun of a scheduled run, closes a real issue whose text says only a scheduled run closes it — added 2026-09-13 — M003 review O2, P1, O3, O5, N4
- [low] `.github/dependabot.yml` matches no workflow trigger path and is schema-validated by nothing, so a config error surfaces only on GitHub's Dependabot page — added 2026-09-12 — M002 review
- [low] The smoke test's cleanup trap fires on EXIT only, so a cancelled CI job leaves the container holding the port and the next run reports a collision as an image defect — added 2026-09-12 — M001 review F23, F17
- [low] Every branch dispatch pushes four untagged manifests to the production Docker Hub repository and nothing prunes them. This is the storage cost the M001 plan gate named as its own falsification condition — added 2026-09-12 — M001 review, blame lens item 1
- [low] Docker Hub description sync: a workflow that copies README.md to the Docker Hub page on push to main. Needs a Docker Hub token with read, write and delete scope — added 2026-09-11 — rstudio2u .github/workflows/dockerhub-description.yml
- Roster drift: `effects` and `patchwork` are baked in but absent from the README package list; list them under a category or drop them (GP1) — added 2026-09-03 — scripts/install_bayes.sh, README.md
- `.gitattributes` cites `scripts/tests/test_launcher_line_endings.sh`, which was not ported; fix the comment or port the guard (GP7) — added 2026-09-03 — cairn/DESIGN.md Known issues
