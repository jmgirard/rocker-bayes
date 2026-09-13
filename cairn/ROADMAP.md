# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-09-12 (M002 done and archived, 6 review findings filed as candidates, caps and byte budgets clean)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->
| M003 | Unattended-rebuild alerts and schedule keepalive | in-progress | M001, M002 | normal | milestones/M003-unattended-rebuild-alerts.md |
| M002 | Pre-merge CI lane and lint | done | M001 | normal | milestones/archive/M002-pre-merge-ci-lane.md |
| M001 | Smoke-test gate before any tag moves | done | — | high | milestones/archive/M001-smoke-test-publish-gate.md |

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- [high] Smoke phase 2 cannot tell a fresh bspm fetch from a package the image already carries: it asserts `library()` plus `dpkg -s`, never that the package arrived this run. Assert absence before installing. Relatedly, the compile control fails at stanc parse time, so no control covers a broken C++ toolchain — added 2026-09-12 — M001 review F3, F12
- [high] No workflow runs `.github/tests/test_publish_guard.sh`, and `.github/tests/**` is absent from the push paths filter, so the guard can drift from what `docker.yml` calls it with. M002 lints shell files and M003 runs the three ported suites, so neither covers it — added 2026-09-12 — M001 review F8
- [high] `scripts/install_bayes.sh` still builds the `install_cmdstan()` call by interpolating `CMDSTAN_VERSION` into R source. The M002 quoting fix stops whitespace from splitting it, but a value carrying a double quote still rewrites the call. Read it with `Sys.getenv()` instead, the convention `smoke-test.sh` already follows — added 2026-09-12 — M002 review
- [high] Nothing asserts a leg's digest was built from the base tag its variant claims. A matrix edit setting `base_tag: noble` on a resolute row passes every gate and ships noble bytes under the resolute tag. Read an OS-release or base label out of the pulled image, as the arch assertion reads `{{.Architecture}}` — added 2026-09-12 — M001 review F14
- CmdStan is compiled into `/home/rstudio/.cmdstan`, which the compose home volume captures on first run; an image update does not refresh CmdStan for existing users until the volume is wiped. Move it outside the home directory or refresh at start — added 2026-09-03 — cairn/DESIGN.md Architecture
- `retry-on-failure` reruns genuine smoke failures, not just mirror flakes, and `no-cache` is true for `schedule`, so a deterministic weekly failure rebuilds all four legs up to three times. Scope the retry to mirror symptoms, or drop it — added 2026-09-12 — M001 review F2
- Digest artifacts are named by digest alone and merged flat, so two legs building byte-identical images collapse to one file and the guard blocks with a wrong-cause message. Name them `<variant>-<arch>` — added 2026-09-12 — M001 review F7
- Phase 1 never touches the published host port when the image declares a HEALTHCHECK, because the healthcheck requests `localhost:8787` from inside the container. Add a host-side probe — added 2026-09-12 — M001 review F18
- The manifest guard compares the architecture list against the exact string `amd64 arm64`, so an index naming a third architecture as well is refused though it satisfies AC5. Use a subset check — added 2026-09-12 — M001 review F13
- The push paths filter includes `.github/smoke-test.sh` and the fixtures, but `.dockerignore` excludes `.github` from the build context, so a comment typo rebuilds four legs and re-points `latest` at an identical image — added 2026-09-12 — M001 review F9
- `pr-ci.yml` triggers a full noble build on any `.github/workflows/**` edit, including a comment-only change to the publish lane. Same class as the `docker.yml` paths row above, in the other workflow — added 2026-09-12 — M002 review
- A `paths` filter plus a required status check leaves a pull request that touches none of those paths waiting forever for a check that never runs. Neither workflow declares a `merge_group` trigger either, so a merge queue merges unchecked — added 2026-09-12 — M002 review
- The shell lint pathspec covers `*.sh` and `*.command` only. An extensionless script or a `.bash` file is never linted, and the enumeration count still reads as if coverage were complete — added 2026-09-12 — M002 review
- [low] Neither `pr-ci.yml` nor `lint.yml` sets a `concurrency` group, so several quick pushes to one pull request each start a full build and none is cancelled — added 2026-09-12 — M002 review
- [low] `.github/dependabot.yml` matches no workflow trigger path and is schema-validated by nothing, so a config error surfaces only on GitHub's Dependabot page — added 2026-09-12 — M002 review
- [low] The smoke test's cleanup trap fires on EXIT only, so a cancelled CI job leaves the container holding the port and the next run reports a collision as an image defect — added 2026-09-12 — M001 review F23, F17
- [low] Every branch dispatch pushes four untagged manifests to the production Docker Hub repository and nothing prunes them. This is the storage cost the M001 plan gate named as its own falsification condition — added 2026-09-12 — M001 review, blame lens item 1
- [low] Docker Hub description sync: a workflow that copies README.md to the Docker Hub page on push to main. Needs a Docker Hub token with read, write and delete scope — added 2026-09-11 — rstudio2u .github/workflows/dockerhub-description.yml
- Roster drift: `effects` and `patchwork` are baked in but absent from the README package list; list them under a category or drop them (GP1) — added 2026-09-03 — scripts/install_bayes.sh, README.md
- `.gitattributes` cites `scripts/tests/test_launcher_line_endings.sh`, which was not ported; fix the comment or port the guard (GP7) — added 2026-09-03 — cairn/DESIGN.md Known issues
