# Design

_Architecture as it **is**. Status lives in ROADMAP.md; tasks in milestone files; decisions in DECISIONS.md._

## Purpose & Scope

<!-- Seeded by cairn-init on 2026-09-03 from README.md, Dockerfile, and the CI
     workflow. Refine with /design-interview; nothing here is elicited. -->

- rocker-bayes is a Docker image for Bayesian data analysis in R, published to
  Docker Hub as `jmgirard/rocker-bayes`.
- It layers CmdStan and a curated set of Bayesian R packages (brms, rstan,
  cmdstanr, loo, bayesplot, tidybayes, blavaan, and others) on top of
  `jmgirard/rstudio2u`, which supplies R, RStudio Server, Pandoc, Quarto, and
  bspm binary package installs from r2u.
- Two Ubuntu variants (`noble`, `resolute`) are built from one Dockerfile via
  the `BASE_TAG` build argument; both ship for amd64 and arm64.
- The primary audience is classrooms and non-technical users: double-click
  launchers for macOS, Windows, and Linux wrap `docker compose` and open
  RStudio at localhost with no login.
- Out of scope: R and RStudio versions (those are whatever rstudio2u ships),
  and any language package shipped to a registry (the image is the sole
  deliverable).

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
- The CmdStan version is pinned once, in the Dockerfile `ARG`; CI reads it from
  there for the immutable tag.
- R packages are the newest on CRAN at build time; cmdstanr comes from the
  Stan r-universe.
- A weekly scheduled CI rebuild (no cache) picks up base-image updates; push
  builds use the GitHub Actions cache.
- Container is intentionally root-capable (passwordless sudo); safety comes
  from the localhost-only bind, documented in README "Security".

## Design Principles

<!-- IP<n> = Inviolable (hard constraint) block first, then GP<n> = Guiding
     (tradeable with justification). Numbers are never reused. None elicited
     yet; run /design-interview to populate. -->

### Inviolable

_(none yet)_

### Guiding

_(none yet)_

## Architecture

- Single-stage build: `FROM jmgirard/rstudio2u:${BASE_TAG}`, copy `scripts/`
  to `/rocker_scripts`, run `install_bayes.sh`, set a healthcheck on port 8787,
  `CMD ["/init"]` from the base.
- The build context is restricted by `.dockerignore` to `scripts/` and the
  Dockerfile.
- Home directory persists in the `rstudio_home` named volume, pre-populated
  from the image on first run.

## Known issues

_(none recorded)_
