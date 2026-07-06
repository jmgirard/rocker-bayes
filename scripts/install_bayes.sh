#!/bin/bash

set -e

# Build ARGs
CMDSTAN_VERSION=${1:-${CMDSTAN_VERSION}}

# The r2u binary mirror is a single host that occasionally becomes unreachable
# from a given CI runner's IP for minutes at a time. Tell apt to retry failed
# downloads so a brief blip doesn't abort a whole bspm install (this config also
# benefits the end user's later installs).
cat > /etc/apt/apt.conf.d/80-retries <<'EOF'
Acquire::Retries "3";
EOF

# Retry a command to ride out a *brief* r2u/apt blip. When bspm's underlying apt
# fetch fails, R aborts with an empty error and the whole build fails; installs
# are idempotent, so a retry just picks up whatever didn't land. This stays
# deliberately short: a runner that can't reach the mirror stays blocked on the
# same IP no matter how long we wait, so we fail fast and let the workflow's
# retry-on-failure job re-run the leg on a fresh runner (a new IP) instead.
retry() {
  local n=1 max=2 delay=20
  until "$@"; do
    if [ "${n}" -ge "${max}" ]; then
      echo "Command still failing after ${max} attempts: $*" >&2
      return 1
    fi
    echo "Attempt ${n} failed; retrying in ${delay}s..." >&2
    sleep "${delay}"
    n=$((n + 1))
  done
}

# Install R packages
retry R -q -e '
  install.packages(
    pkgs = c(
      "bayesplot",
      "BayesFactor",
      "blavaan",
      "bridgesampling",
      "brms",
      "data.table",
      "easystats",
      "effects",
      "emmeans",
      "ggeffects",
      "loo",
      "marginaleffects",
      "ordbetareg",
      "patchwork",
      "posterior",
      "priorsense",
      "projpred",
      "rstan",
      "rstanarm",
      "shinystan",
      "tidybayes",
      "tidyverse"
    )
  )
  install.packages(
    pkgs = "cmdstanr",
    repos = c(
      "https://stan-dev.r-universe.dev",
      getOption("repos")
    )
  )
'

# Install CmdStan (adding flags for ARM64 warnings and O3 optimization)
# https://discourse.mc-stan.org/t/warnings-when-compiling-cmdstan-code-on-linux-arm64/37320/2
mkdir -p /home/rstudio/.cmdstan
R -q -e '
  cmdstanr::install_cmdstan(
    dir = "/home/rstudio/.cmdstan",
    version = "'${CMDSTAN_VERSION}'",
    cpp_options = list("CXXFLAGS+= -Wno-psabi -O3")
  )
  cmdstanr::set_cmdstan_path("/home/rstudio/.cmdstan")
'
chown -R rstudio /home/rstudio/.cmdstan

# Clean up
apt-get clean
rm -rf /tmp/*

# Fix permissions for all newly installed packages
chown -R root:staff /usr/local/lib/R/site-library /usr/lib/R/site-library
chmod -R g+ws /usr/local/lib/R/site-library /usr/lib/R/site-library
