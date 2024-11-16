#!/bin/bash
# install_bayes.sh

set -e

## Build ARGs
NCPUS=$(nproc || echo 1)

# Install R packages and cleanup
Rscript -e 'install.packages(c("rstan", "cmdstanr"), repos = c("https://stan-dev.r-universe.dev", getOption("repos")))'

install2.r --error --skipinstalled -n "$NCPUS" \
    bayesplot \
    brms \
    easystats \
    future \
    ggeffects \
    Matrix \
    projpred \
    rstanarm \
    shinystan \
    tidybayes

# Clean up
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/downloaded_packages

## Strip binary installed libraries from RSPM
## https://github.com/rocker-org/rocker-versioned2/issues/340
strip /usr/local/lib/R/site-library/*/libs/*.so
