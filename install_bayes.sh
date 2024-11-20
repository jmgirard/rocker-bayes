#!/bin/bash
# install_bayes.sh

set -e

# Build ARGs
NCPUS=$(nproc || echo 1)
CMDSTAN=${1:-${CMDSTAN:-"/opt/cmdstan"}}

# Install R packages and cleanup
R -q -e '
    options(mc.cores = '${NCPUS}')
    install.packages("pak", repos = sprintf("https://r-lib.github.io/p/pak/stable/%s/%s/%s", .Platform$pkgType, R.Version()$os, R.Version()$arch))
    pak::repo_add("https://stan-dev.r-universe.dev")
    pak::pkg_install(c("brms", "cmdstanr", "easystats", "effects", "ggeffects", "patchwork", "rstan", "tidyverse"))
    pak::cache_clean()
    pak::meta_clean(TRUE)
'

# Install CmdStan
mkdir -p ${CMDSTAN}
R -q -e 'cmdstanr::install_cmdstan(dir = "'${CMDSTAN}'")'
chmod -R 777 ${CMDSTAN}

# Clean up
apt-get clean
rm -rf /tmp/*