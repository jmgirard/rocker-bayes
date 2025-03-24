#!/bin/bash

set -e

# Build ARGs
CMDSTAN_VERSION=${1:-${CMDSTAN_VERSION}}

# Install R packages
R -q -e '
  install.packages(
    pkgs = c(
      "brms",
      "easystats",
      "effects",
      "ggeffects",
      "patchwork",
      "rstan",
      "rstanarm",
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

# Install CmdStan (adding flag to suppress ignorable warnings on ARM64)
# https://discourse.mc-stan.org/t/warnings-when-compiling-cmdstan-code-on-linux-arm64/37320/2
mkdir -p /home/rstudio/.cmdstan
R -q -e '
  cmdstanr::install_cmdstan(
    dir = "/home/rstudio/.cmdstan",
    version = "'${CMDSTAN_VERSION}'",
    cpp_options = list("CXXFLAGS+= -Wno-psabi")
  )
  cmdstanr::set_cmdstan_path("/home/rstudio/.cmdstan")
'
chown -R rstudio /home/rstudio/.cmdstan

# Clean up
apt-get clean
rm -rf /tmp/*
