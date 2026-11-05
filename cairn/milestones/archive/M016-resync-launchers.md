# M016: Resync the launchers from rstudio2u

**Status:** done (2026-11-05, PR #31 https://github.com/jmgirard/rocker-bayes/pull/31)

**Goal:** Make this repo's seven launcher files match rstudio2u's at commit `4b181de`, apart from the project's names, so launcher users here get the offline reminder that rstudio2u ships.

**Outcome:** The `start_*`, `stop_*`, and `launcher_common.sh` files equal
rstudio2u's `4b181de` blobs after the map `compose port rstudio2u` →
`compose port bayes`, then `rstudio2u` → `rocker-bayes` (`cmp` 7 of 7, no mode
change). After a failed pull with a local copy, the start launchers repeat the
warning after the banner (`launcher_remind_offline`), hold the window
(`launcher_hold_offline`), and exit 0. The seam key wait prints "[test seam]
key wait skipped". The macOS and Linux runs used a scratch `COMPOSE_FILE` with
a local-only image, plus a working-pull control. Windows rests on rstudio2u's
suite and the byte match. README Quick start step 4 and DESIGN.md were updated.

**Decisions:** a byte match against a pinned commit over a hand edit, and no
ported scenario tests (GP7), both at the plan gate.

**Review:** four lenses, 15 findings: 2 fixed in 4a7c0fd (the README names the
window hold), 2 follow-ups, 10 rejected (2 edge), 1 noted. New parked row "Keep
the Linux launcher in a terminal". Extended "Name a bad pin in launcher
errors". Plan rows "Fix rstudio2u's CRLF guard and claim" and "Catch launcher
drift from rstudio2u". Graduated "Resync the launchers from rstudio2u". Lesson
2026-11-05 (M011) extended with the scratch Compose route.
