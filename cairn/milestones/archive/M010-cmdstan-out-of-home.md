# M010: Give old home volumes the new CmdStan

**Status:** done (2026-10-21, PR #23 https://github.com/jmgirard/rocker-bayes/pull/23)

**Goal:** A user whose home volume was made by an older image gets the image's own CmdStan after an update, with no volume wipe.

**Outcome:** `install_bayes.sh` installs CmdStan to `/opt/cmdstan`, owned
`root:staff`, group-writable, with setgid on directories only. The
Dockerfile sets `ENV CMDSTAN=/opt/cmdstan/cmdstan-${CMDSTAN_VERSION}` after
the install, and the base's `01_set_env` copies it into `Renviron.site`.
Smoke phase 4 boots a second container on a self-named volume seeded with a
stale `cmdstan-2.36.0` and checks cmdstanr with `CMDSTAN` removed from the R
process. It failed against the previous image and against one without
`01_set_env`. Two test_mode runs passed all four legs. The README covers the
old folder (size, delete warning, recompiling old models) and `~/.Renviron`.

**Decisions:** /opt plus `CMDSTAN` over copying CmdStan in at start, no link
at the old path, and the image pin over a user's own CmdStan with a
`~/.Renviron` override (plan gate).

**Review:** four lenses, 23 findings: 12 fixed in c07d906, 6 follow-ups, 5
rejected. New candidate rows: "Keep CmdStan runtime files writable", "Smoke a
threaded CmdStan build in CI", "Set setgid on site-library dirs only". The
claim audit added "Fix the package persistence claim". Graduated the
candidate row "Give old home volumes the new CmdStan".
