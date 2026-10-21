#!/bin/bash

set -e

# apt retry/timeout settings for the r2u mirror come from the base image
# (/etc/apt/apt.conf.d/80-retries); do not overwrite them here.

# Retry a command to ride out a *brief* r2u/apt blip. When bspm's underlying apt
# fetch fails, R aborts with an empty error and the whole build fails; installs
# are idempotent, so a retry just picks up whatever didn't land. This stays
# deliberately short: a runner that can't reach the mirror stays blocked on the
# same IP no matter how long we wait, so we fail fast. For a scheduled rebuild,
# .github/workflows/rebuild-retry.yml then reruns the run's failed jobs once, on
# fresh runners, when every failed leg failed in its build step with the
# "Command still failing after" line below in its log. Push and dispatch
# builds, and a second attempt, are not rerun. The rule is in
# .github/retry-decision.sh.
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

# Install CmdStan (adding flags for ARM64 warnings and O3 optimization)
# https://discourse.mc-stan.org/t/warnings-when-compiling-cmdstan-code-on-linux-arm64/37320/2
# The version is the first argument, else CMDSTAN_VERSION from the environment
# (the Dockerfile ENV sets it). R reads it with Sys.getenv() and never sees it
# spliced into its code, so no value can rewrite the install_cmdstan() call.
install_cmdstan_step() {
  CMDSTAN_VERSION="${1:-${CMDSTAN_VERSION:-}}"
  if [ -z "${CMDSTAN_VERSION}" ]; then
    echo "install_bayes.sh: CMDSTAN_VERSION is empty; set the Dockerfile ARG or pass a CmdStan release such as 2.40.0" >&2
    return 1
  fi
  export CMDSTAN_VERSION
  mkdir -p /home/rstudio/.cmdstan
  R -q -e '
    cmdstanr::install_cmdstan(
      dir = "/home/rstudio/.cmdstan",
      version = Sys.getenv("CMDSTAN_VERSION"),
      cpp_options = list("CXXFLAGS+= -Wno-psabi -O3")
    )
    cmdstanr::set_cmdstan_path("/home/rstudio/.cmdstan")
  '
  chown -R rstudio /home/rstudio/.cmdstan
}

main() {
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

  install_cmdstan_step "$@"

  # Clean up
  apt-get clean
  rm -rf /tmp/*

  # Fix permissions for all newly installed packages
  chown -R root:staff /usr/local/lib/R/site-library /usr/lib/R/site-library
  chmod -R g+ws /usr/local/lib/R/site-library /usr/lib/R/site-library
}

# Run only when executed. .github/tests/test_install_cmdstan.sh sources this
# file to call install_cmdstan_step on its own.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
