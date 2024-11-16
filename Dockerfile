FROM rocker/tidyverse:4.4.1

LABEL maintainer="Jeffrey Girard <me@jmgirard.com>" \
    version="1.0" \
    description="Tools for Bayesian analysis in R" \
    license="MIT"

ARG CMDSTAN_VERSION=2.35.0

ENV DEBIAN_FRONTEND=noninteractive \
    CMDSTAN=/opt/cmdstan

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential curl git libv8-dev \
    && apt-get clean \
    && mkdir -p ${CMDSTAN} \ 
    && curl -L https://github.com/stan-dev/cmdstan/releases/download/v${CMDSTAN_VERSION}/cmdstan-${CMDSTAN_VERSION}.tar.gz | \
    tar -xz -C ${CMDSTAN} --strip-components=1 \
    && cd ${CMDSTAN} \
    && make build -j$(nproc) \
    && rm -rf /var/lib/apt/lists/* ${CMDSTAN}/test \
    && chown -R rstudio:rstudio ${CMDSTAN} \
    && Rscript -e 'install.packages(c("rstan", "cmdstanr"), repos = c("https://stan-dev.r-universe.dev", getOption("repos")))' \
    && install2.r --error --skipinstalled \
    rstanarm brms tidybayes bayesplot Matrix projpred loo dagitty future easystats ggeffects

ENV PATH="${CMDSTAN}/bin:${PATH}"

CMD ["/init"]