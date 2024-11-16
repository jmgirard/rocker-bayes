FROM rocker/tidyverse:4.4.1

ENV DEBIAN_FRONTEND=noninteractive
ENV CMDSTAN=/opt/cmdstan

RUN apt-get update \
	&& apt-get install -y --no-install-recommends build-essential gfortran git curl ca-certificates nodejs \
	&& apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p ${CMDSTAN} \ 
	&& curl -L https://github.com/stan-dev/cmdstan/releases/download/v2.35.0/cmdstan-2.35.0.tar.gz | \
    tar -xz -C ${CMDSTAN} --strip-components=1 \
	&& cd ${CMDSTAN} \
	&& make build -j$(nproc)

ENV PATH="${CMDSTAN}/bin:${PATH}"

RUN install2.r --error --skipinstalled dagitty future \
	&& Rscript -e 'install.packages(c("rstan", "cmdstanr"), repos = c("https://stan-dev.r-universe.dev", getOption("repos")))' \
	&& install2.r --error --skipinstalled rstanarm brms tidybayes bayesplot Matrix projpred loo easystats

CMD ["/init"]