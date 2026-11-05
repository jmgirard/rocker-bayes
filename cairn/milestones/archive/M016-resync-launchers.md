# M016: Resync the launchers from rstudio2u

**Status:** done (2026-11-05, PR #31 https://github.com/jmgirard/rocker-bayes/pull/31)

**Goal:** Make this repo's seven launcher files match rstudio2u's at commit `4b181de`, apart from the project's names, so launcher users here get the offline reminder that rstudio2u ships.

**Outcome:** The seven `start_*`, `stop_*`, and `launcher_common.sh` files
equal rstudio2u's `4b181de` blobs after the name map `compose port
rstudio2u` → `compose port bayes`, then `rstudio2u` → `rocker-bayes`. `cmp`
matched all 7, and no mode changed. After a failed pull with a local copy,
the start launchers repeat the warning after the running banner
(`launcher_remind_offline`), then hold the window with "RStudio keeps running
after you close this window." (`launcher_hold_offline`) and exit 0. Under
`RS_LAUNCHER_NONINTERACTIVE` the key wait prints "[test seam] key wait
skipped". Local runs of the macOS and Linux launchers used a scratch
`COMPOSE_FILE` with a local-only image, plus a working-pull control. Windows
rests on rstudio2u's Windows suite and the byte match. README Quick start
step 4 states the offline, hold, and no-copy behavior. DESIGN.md names the
sync commit.

**Decisions:** a byte match against a pinned rstudio2u commit over a hand
edit, and no ported scenario tests (GP7), both at the plan gate.

**Review:** four lenses, 15 findings: 2 fixed in 4a7c0fd (the README names
the window hold), 2 follow-ups, 10 rejected (2 edge), 1 noted. New parked row
"Keep the Linux launcher in a terminal". Extended "Name a bad pin in launcher
errors". New rows at plan: "Fix rstudio2u's CRLF guard and claim" and "Catch
launcher drift from rstudio2u". Graduated "Resync the launchers from
rstudio2u". Lesson 2026-11-05 (M011) extended with the scratch Compose route.
