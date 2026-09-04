# rocker-bayes

[![Build](https://github.com/jmgirard/rocker-bayes/actions/workflows/docker.yml/badge.svg)](https://github.com/jmgirard/rocker-bayes/actions/workflows/docker.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/jmgirard/rocker-bayes)](https://hub.docker.com/r/jmgirard/rocker-bayes)
[![Image Size](https://img.shields.io/docker/image-size/jmgirard/rocker-bayes/latest)](https://hub.docker.com/r/jmgirard/rocker-bayes)
[![License: MIT](https://img.shields.io/github/license/jmgirard/rocker-bayes)](LICENSE)

Everything you need for **Bayesian data analysis in R**, ready to run. Builds on
[jmgirard/rstudio2u](https://github.com/jmgirard/rstudio2u) (RStudio Server,
Pandoc, and Quarto on [r2u](https://github.com/rocker-org/r2u)) and adds
[CmdStan](https://mc-stan.org/users/interfaces/cmdstan) plus a curated set of
Bayesian R packages. Works on AMD64 and ARM64 (e.g., Apple Silicon).

Binary package installation from within R via
[bspm](https://cloud.r-project.org/package=bspm) using `install.packages()`, for
fast installs and no compiling.

| Tag                 | Base image                | Architectures | CmdStan     |
| ------------------- | ------------------------- | ------------- | ----------- |
| `latest`, `noble`   | `jmgirard/rstudio2u:noble`    | amd64, arm64  | 2.39.0  |
| `resolute`          | `jmgirard/rstudio2u:resolute` | amd64, arm64  | 2.39.0  |

The R and RStudio versions are whatever the underlying
[rstudio2u](https://github.com/jmgirard/rstudio2u) base ships. All tags are built
from a single [`Dockerfile`](Dockerfile); select the base with the `BASE_TAG`
build argument (e.g. `--build-arg BASE_TAG=resolute` for `resolute`) and pin
CmdStan with `--build-arg CMDSTAN_VERSION=<version>` if you need a specific
version.

These tags **move** as new versions are released. For a frozen, identical
environment (e.g. a course), pin an immutable tag instead — see
[Reproducibility](#reproducibility).

> On a Windows host you may want to increase the number of CPUs available to WSL
> via `%UserProfile%\.wslconfig`, so Stan can use more cores.

## Included R packages

### Interfaces
- [brms](https://paulbuerkner.com/brms/)
- [ordbetareg](https://www.robertkubinec.com/ordbetareg)
- [rstanarm](https://mc-stan.org/rstanarm/)

### Backends
- [cmdstanr](https://mc-stan.org/cmdstanr/) (newest from <https://stan-dev.r-universe.dev/builds>)
- [posterior](https://mc-stan.org/posterior/)
- [rstan](https://mc-stan.org/rstan/)

### Data preparation
- [data.table](https://rdatatable.gitlab.io/data.table/)
- [tidyverse](https://www.tidyverse.org/)

### Model comparison & selection
- [bridgesampling](https://cran.r-project.org/package=bridgesampling)
- [loo](https://mc-stan.org/loo/)
- [priorsense](https://n-kall.github.io/priorsense/)
- [projpred](https://mc-stan.org/projpred/)

### Model interrogation
- [bayesplot](https://mc-stan.org/bayesplot/)
- [BayesFactor](https://richarddmorey.github.io/BayesFactor/)
- [easystats](https://easystats.github.io/easystats/)
- [emmeans](https://rvlenth.github.io/emmeans/)
- [ggeffects](https://strengejacke.github.io/ggeffects/)
- [marginaleffects](https://marginaleffects.com/)
- [shinystan](https://mc-stan.org/shinystan/)
- [tidybayes](https://mjskay.github.io/tidybayes/)

### Structural equation modeling
- [blavaan](https://ecmerkle.github.io/blavaan/)

All packages are the newest available on CRAN at build time (except cmdstanr,
which comes from the Stan r-universe).

## Use Examples

### Quick start (recommended): double-click launcher

The easiest way to run the server, good for classrooms and non-technical users.

1. Install and open [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Download this repository (green **Code** button → **Download ZIP**, then unzip)
   or `git clone https://github.com/jmgirard/rocker-bayes`
3. Double-click the launcher for your system:
   - **macOS:** `start_mac.command` — the first time, right-click it and choose
     **Open** to get past Gatekeeper (double-click works every time after that)
   - **Windows:** `start_windows.bat`
   - **Linux:** `start_linux.sh`
4. It downloads the latest image, starts the server, waits until it is ready,
   and opens <http://localhost:8787> in your browser (no username or password)
5. When you are done, double-click the matching `stop_...` file. Your session is
   preserved; run the start file again to resume.

The launchers just wrap the Docker Compose commands below, so Docker Desktop must
be installed and running.

> **Your work is saved.** The Compose setup stores the home directory (your
> files, settings, installed R packages, and compiled CmdStan toolchain) in a
> Docker named volume, so it survives stopping, restarting, and even updating to
> a newer image. To wipe it and start completely fresh, run
> `docker compose down -v`.

### Option 1: Pull and run from Docker Hub

1. Install and open [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Enter the following command in your terminal

    ```
    docker pull jmgirard/rocker-bayes
    docker run --rm -p 8787:8787 -e PASSWORD=pass -t jmgirard/rocker-bayes
    ```

3. Navigate to <http://localhost:8787> and enter username `rstudio` and password `pass`
4. Whenever you use `install.packages()` or `update.packages()`, it will use bspm
5. When done, open Docker Desktop and end the container
6. Next time, you don't need to run `docker pull...` again

### Option 2: Clone, build, and compose

1. Install and open [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Install [Git](https://git-scm.com/downloads)
3. Enter the following command in your terminal

    ```
    git clone https://github.com/jmgirard/rocker-bayes
    cd rocker-bayes
    docker compose up --build -d
    ```
4. Navigate to <http://localhost:8787> (no username or password needed)
5. Whenever you use `install.packages()` or `update.packages()`, it will use bspm
6. When done, open Docker Desktop and end the container
7. Next time, you don't need to run `git clone...` again

### Getting files in and out

Because the home directory lives in a Docker volume (not an ordinary host
folder), move files through RStudio or Docker:

- **In RStudio (easiest):** use the **Upload** button in the Files pane to bring
  files in, and select a file then **More → Export** to download it out.
- **From a terminal:** with the server running,
  `docker compose cp ./data.csv bayes:/home/rstudio/` copies a file in, and
  `docker compose cp bayes:/home/rstudio/results.csv ./` copies one out.

If you would rather work directly in a folder on your own computer, replace the
`rstudio_home` volume in `docker-compose.yml` with a bind mount, e.g.
`- ./workspace:/home/rstudio/workspace`, and keep your work in that folder.

## Adding R Packages

Thanks to [bspm](https://cloud.r-project.org/package=bspm), packages install as
precompiled binaries — fast, with no compiling.

**Interactively (in a running container):**

- In the RStudio console, `install.packages("dplyr")` transparently pulls the
  binary via bspm; you don't need to do anything special.
- Packages installed this way persist in the home volume (see above), so they
  are still there next time you start the server.
- If a package needs a system library, open the RStudio **Terminal** and
  `sudo apt install <libfoo-dev>` (rarely needed — bspm resolves most
  dependencies for you).

**Baking packages into your own image (recommended for a course or lab):**

Build a small image on top of rocker-bayes so everyone gets the same packages
preinstalled. Pin an immutable tag (see below) for reproducibility:

```dockerfile
FROM jmgirard/rocker-bayes:noble-cmdstan2.39.0

# install.packages() uses bspm here too, so these are fast binary installs
RUN Rscript -e 'install.packages(c("projpred", "loo", "priorsense"))'
```

```
docker build -t my-course .
docker run --rm -p 8787:8787 -e PASSWORD=pass my-course
```

## Reproducibility

`latest`, `noble`, and `resolute` are **moving** tags that update as new versions
of R, RStudio, CmdStan, and the R packages are released. For a setting where
everyone should get an identical environment, pin an **immutable** tag instead:

| Tag pattern           | Example                   | Frozen at                    |
| --------------------- | ------------------------- | ---------------------------- |
| `<variant>-<date>`    | `noble-2026-07-05`        | everything, as of that build |
| `<variant>-cmdstan<v>`| `noble-cmdstan2.39.0`     | that CmdStan version         |

Use one in `docker run`, in `docker-compose.yml`, or as the `FROM` line of a
derivative image and it will not change under you. Browse the
[available tags](https://hub.docker.com/r/jmgirard/rocker-bayes/tags) on Docker Hub.

The image is rebuilt weekly by CI, so the Docker date tags are the record of
*builds*. The [GitHub releases](https://github.com/jmgirard/rocker-bayes/releases)
are the record of changes to the *recipe*: a new base image or tag scheme is a
major version, a new R or CmdStan version, package, variant, or launch tool is a
minor version, and a fix is a patch. A weekly rebuild with no recipe change gets
no release.

For project-level reproducibility, [renv](https://rstudio.github.io/renv/) works
well inside the container: `renv::init()` records exact package versions in a
lockfile you can commit, and `renv::restore()` rebuilds them — quickly, since
bspm still serves binaries.

## Test between- and within-chain parallelization

This small model won't get much benefit from within-chain parallelization; it's
just a quick check that CmdStan, `brms`, and threading all work.

```r
library(brms)
fit_serial <- brm(
  count ~ zAge + zBase * Trt + (1 | patient),
  data = epilepsy, family = poisson(),
  chains = 4, cores = 4, backend = "cmdstanr"
)
fit_parallel <- update(
  fit_serial, chains = 2, cores = 2,
  backend = "cmdstanr", threads = threading(2)
)
```

## Security

Like its [rstudio2u](https://github.com/jmgirard/rstudio2u#security) base, this
image is intentionally **root-capable**: the RStudio user has passwordless
`sudo` so that bspm can install system binaries and you can `apt install`
additional Ubuntu dependencies. That capability *is* root inside the container,
and it is the whole point of the image. Run it safely:

- **Keep it bound to `127.0.0.1`** (as `docker-compose.yml` does). Do not publish
  the port on `0.0.0.0` or a public interface.
- **`DISABLE_AUTH=true` / no-login is only safe on a localhost-only bind.** Never
  combine passwordless access with a network-reachable port; set a strong
  `PASSWORD` (and leave auth enabled) if the server is reachable by others.
- **Don't run with `--privileged`**, don't mount the Docker socket, and be
  cautious mounting sensitive host directories.

## FAQ / Troubleshooting

**"Cannot connect to the Docker daemon" / the launcher says Docker isn't running.**
Open Docker Desktop, wait until it reports *Running*, then try again.

**Port 8787 is already in use.**
Use a different host port. Create a file named `.env` next to the launcher
containing one line:

```
RS_PORT=8888
```

then double-click the launcher again and browse to <http://localhost:8888>. (The
`.env` file works for double-clicking, which is why it is the recommended way;
from a terminal, `RS_PORT=8888 docker compose up -d` also does the job.) With
`docker run`, change the mapping to `-p 8888:8787`.

**How do I update to the latest version?**
`docker compose pull` (the launchers do this for you) or
`docker pull jmgirard/rocker-bayes`. Your work in the home volume is preserved.

**How do I reset everything / reclaim disk space?**
`docker compose down -v` removes the container and its home volume (this deletes
saved work). `docker image prune` reclaims old image layers.

**Does it work on Apple Silicon?**
Yes — images are built for both amd64 and arm64, so Apple Silicon Macs run
natively without emulation.

**What's the login?**
Username `rstudio`; the password is whatever you pass via `-e PASSWORD=...` (the
Compose default is `rstudio`). The Compose/launcher setup uses `DISABLE_AUTH=true`,
so no login is required at all.

## How to Cite

Citation metadata is in [`CITATION.cff`](CITATION.cff); GitHub shows a
ready-to-copy citation via the **Cite this repository** button on the repo page.
