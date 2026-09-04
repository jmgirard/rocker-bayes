# Design

_Architecture as it **is**. Status lives in ROADMAP.md; tasks in milestone files; decisions in DECISIONS.md._

## Purpose & Scope

<!-- Elicited in the 2026-09-03 design interview (Phase 1). -->

- rocker-bayes is a Docker image for Bayesian data analysis in R, published to
  Docker Hub as `jmgirard/rocker-bayes`. The image is the sole deliverable.
- **Audience: the general Bayesian-R community.** Classrooms are one important
  user group, and the double-click launchers serve them, but `docker run` and
  derivative `FROM` images are first-class paths, not afterthoughts.
- **Contract boundary.** rocker-bayes inherits `jmgirard/rstudio2u` as given:
  R, RStudio Server, Pandoc, Quarto, bspm/r2u, and the runtime interface
  (port 8787, user `rstudio`, `/home/rstudio` volume, `PASSWORD` / `ROOT` /
  `DISABLE_AUTH` / `USERID`, s6 `/init`) are the base's to define, and
  base-level fixes go upstream first. This repo's own job is the Bayesian
  layer: CmdStan, the R package roster, and the launchers and compose file it
  ships. Launcher code is synced from rstudio2u; it may diverge here when the
  Bayesian layer needs it, with the divergence stated.
- **Roster bar.** A package earns a place by being mainstream in the
  Stan / Bayesian-R ecosystem and stating in one line what it adds that
  nothing already baked in does. Periodic pruning of packages that fell out of
  use is licensed work. No hard size number.
- **Build targets are commitments.** Two Ubuntu variants (`noble`, `resolute`)
  from one Dockerfile via `BASE_TAG`, each on amd64 and arm64; a broken leg is
  ship-blocking or hotfix-tier, with documented temporary asymmetry only when
  an upstream forces it.
- **Versioning is the Docker tag set.** Moving `latest` / `noble` / `resolute`
  plus immutable `<variant>-<date>` and `<variant>-cmdstan<v>` tags, published
  by CI on every build. Git tags (`v4.2` … `v8.0`) are retired; there is no
  hand release.
- Out of scope: R and RStudio versions (whatever rstudio2u ships), a
  locked-down or non-root mode, and any language package shipped to a
  registry.

## Function Families

- **Image build**: `Dockerfile` (build args `BASE_TAG`, `CMDSTAN_VERSION`) and
  `scripts/install_bayes.sh` (R package installs via bspm, CmdStan download and
  compile).
- **Local run**: `docker-compose.yml` (localhost-only port bind, named home
  volume, `RS_PORT` / `RS_PASS` from `.env`).
- **Launchers**: `start_*` / `stop_*` files plus `launcher_common.sh`; the
  Windows `.bat` files are stored with CRLF line endings (see `.gitattributes`).
- **CI / publish**: `.github/workflows/docker.yml` builds each architecture on
  a native runner, pushes by digest, and merges the digests into multi-arch
  manifest lists with mutable and immutable tags.

## Conventions

- Tags: mutable `latest`, `noble`, `resolute`; immutable `<variant>-<date>` and
  `<variant>-cmdstan<version>`. User-facing docs never mention milestone IDs.
- **CmdStan is pinned by hand** in the Dockerfile `ARG` and bumped after a
  CmdStan release is reviewed; the weekly rebuild never changes it. CI reads
  the pin for the immutable tag.
- R packages are the newest on CRAN at build time (cmdstanr from the Stan
  r-universe). **A version pin added to dodge an upstream bug is temporary**:
  recorded when added, tracked to removal, removed when upstream heals.
- **This repo's own user-facing surface is frozen** like the base interface:
  the `.env` variables `RS_PORT` / `RS_PASS`, the compose service name `bayes`,
  the launcher file names, and the immutable tag patterns change only through a
  deprecation period and a README notice.
- Launcher code (`start_*`, `stop_*`, `launcher_common.sh`) is synced from
  rstudio2u, whose test suite verifies it; tests are ported here only when a
  file diverges. `.bat` files are stored CRLF (`.gitattributes`).
- A weekly scheduled CI rebuild (no cache) picks up base-image updates; push
  builds use the GitHub Actions cache.
- Container is intentionally root-capable (passwordless sudo); safety comes
  from the localhost-only bind, documented in README "Security".

## Design Principles

<!-- IP<n> = Inviolable (hard constraint) block first, then GP<n> = Guiding
     (tradeable with justification). Numbers are never reused. -->

### Inviolable

_(none yet)_

### Guiding

_(none yet)_

### Banked candidates (interview 2026-09-03, Phase 1 complete; Phase 2 pending)

<!-- Proto-principles heard in Phase 1. Not commitments. Phase 2 classifies
     each as IP / GP / skip and removes this ledger. -->

- B1 Base contract inherited, never overridden here; base fixes go upstream first.
- B2 Launchers synced from rstudio2u; divergence is stated and triggers porting its tests.
- B3 Roster: mainstream Bayesian-R; each add justifies itself in one line; pruning is licensed work.
- B4 Upstream-bug pins are temporary and tracked to removal.
- B5 CmdStan version moves only by a reviewed manual bump, never by the weekly rebuild.
- B6 All four build legs (noble/resolute x amd64/arm64) are commitments.
- B7 This repo's own user-facing surface changes only via deprecation + README notice.
- B8 Docker tags are the only versioning; git tags retired (a decision, not a principle).
- Inherited from rstudio2u for Phase 2 to confirm or fence: no-auth only on a localhost bind; student work in the home volume is never wiped implicitly; never knowingly ship a broken moving tag.

## Architecture

- Single-stage build: `FROM jmgirard/rstudio2u:${BASE_TAG}`, copy `scripts/`
  to `/rocker_scripts`, run `install_bayes.sh`, set a healthcheck on port 8787,
  `CMD ["/init"]` from the base.
- The build context is restricted by `.dockerignore` to `scripts/` and the
  Dockerfile.
- Home directory persists in the `rstudio_home` named volume, pre-populated
  from the image on first run.

## Known issues

- Launcher tests were not ported from rstudio2u: `.gitattributes` cites
  `scripts/tests/test_launcher_line_endings.sh`, which does not exist here.
  The launchers and the CRLF guard are unverified in this repo (interview
  2026-09-03).
- Newest-on-CRAN means a bad upstream release can break the weekly rebuild
  (rstanarm dev bug, 2025-01); a failed build leaves the old moving tag in
  place.
