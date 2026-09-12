# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-09-03 (status audit clean; no change since design interview)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->
| M001 | Smoke-test gate before any tag moves | in-progress | — | high | milestones/M001-smoke-test-publish-gate.md |
| M002 | Pre-merge CI lane and lint | planned | M001 | normal | milestones/M002-pre-merge-ci-lane.md |
| M003 | Unattended-rebuild alerts and schedule keepalive | planned | M001, M002 | normal | milestones/M003-unattended-rebuild-alerts.md |

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- CmdStan is compiled into `/home/rstudio/.cmdstan`, which the compose home volume captures on first run; an image update does not refresh CmdStan for existing users until the volume is wiped. Move it outside the home directory or refresh at start — added 2026-09-03 — cairn/DESIGN.md Architecture
- [low] Docker Hub description sync: a workflow that copies README.md to the Docker Hub page on push to main. Needs a Docker Hub token with read, write and delete scope — added 2026-09-11 — rstudio2u .github/workflows/dockerhub-description.yml
- Roster drift: `effects` and `patchwork` are baked in but absent from the README package list; list them under a category or drop them (GP1) — added 2026-09-03 — scripts/install_bayes.sh, README.md
- `.gitattributes` cites `scripts/tests/test_launcher_line_endings.sh`, which was not ported; fix the comment or port the guard (GP7) — added 2026-09-03 — cairn/DESIGN.md Known issues
