ARG R_VERSION=4.4.1

FROM rocker/tidyverse:${R_VERSION}

LABEL maintainer="Jeffrey Girard <me@jmgirard.com>" \
  version="1.0" \
  description="Tools for Bayesian analysis in R" \
  license="MIT"

ENV DEBIAN_FRONTEND=noninteractive \
  CMDSTAN=/opt/cmdstan

ARG CMDSTAN_VERSION=2.35.0

# Install dependencies and CmdStan
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential curl libv8-dev \
  && apt-get clean \
  && mkdir -p ${CMDSTAN} \ 
  && curl -fSL https://github.com/stan-dev/cmdstan/releases/download/v${CMDSTAN_VERSION}/cmdstan-${CMDSTAN_VERSION}.tar.gz -o /tmp/cmdstan.tar.gz \
  && tar -xz -C ${CMDSTAN} --strip-components=1 -f /tmp/cmdstan.tar.gz \
  && cd ${CMDSTAN} \
  && make build -j$(nproc) \
  && chown -R rstudio:rstudio ${CMDSTAN}

ENV PATH="${CMDSTAN}/bin:${PATH}"

# Install R packages and cleanup
RUN Rscript -e 'install.packages(c("rstan", "cmdstanr"), repos = c("https://stan-dev.r-universe.dev", getOption("repos")))' \
  && install2.r --error --skipinstalled bayesplot brms easystats future ggeffects Matrix projpred rstanarm shinystan tidybayes \
  && rm -rf /var/lib/apt/lists/* ${CMDSTAN}/test /tmp/* /var/tmp/*

CMD ["/init"]