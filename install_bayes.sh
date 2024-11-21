#!/bin/bash
# install_bayes.sh

set -e

# Build ARGs
NCPUS=$(nproc || echo 1)
CMDSTAN_VERSION=${1:-${CMDSTAN_VERSION}}

# Install R packages and cleanup
R -q -e '
    options(mc.cores = '${NCPUS}')
    install.packages("pak", repos = sprintf("https://r-lib.github.io/p/pak/stable/%s/%s/%s", .Platform$pkgType, R.Version()$os, R.Version()$arch))
    pak::repo_add("https://stan-dev.r-universe.dev")
    pak::pkg_install(c("brms", "cmdstanr", "easystats", "effects", "ggeffects", "patchwork", "rstan", "rstanarm", "tidyverse"))
    pak::cache_clean()
    pak::meta_clean(TRUE)
'

# Install CmdStan (adding flag to suppress ignorable warnings on ARM64)
# https://discourse.mc-stan.org/t/warnings-when-compiling-cmdstan-code-on-linux-arm64/37320/2
mkdir -p /opt/cmdstan
R -q -e 'cmdstanr::install_cmdstan(dir = "/opt/cmdstan", version = "'${CMDSTAN_VERSION}'", cpp_options = list("CXXFLAGS+= -Wno-psabi"))'
chmod -R 777 /opt/cmdstan

# Clean up
apt-get clean
rm -rf /tmp/*