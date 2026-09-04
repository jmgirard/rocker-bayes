# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-09-03 (status audit clean; no change since design interview)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- CmdStan is compiled into `/home/rstudio/.cmdstan`, which the compose home volume captures on first run; an image update does not refresh CmdStan for existing users until the volume is wiped. Move it outside the home directory or refresh at start — added 2026-09-03 — cairn/DESIGN.md Architecture
- CI smoke test: after each build, start the container, confirm RStudio Server answers on 8787, and compile a trivial CmdStan model, so a broken image is never tagged (GP8) — added 2026-09-03 — .github/workflows/docker.yml
- Roster drift: `effects` and `patchwork` are baked in but absent from the README package list; list them under a category or drop them (GP1) — added 2026-09-03 — scripts/install_bayes.sh, README.md
- `.gitattributes` cites `scripts/tests/test_launcher_line_endings.sh`, which was not ported; fix the comment or port the guard (GP7) — added 2026-09-03 — cairn/DESIGN.md Known issues
