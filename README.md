# docker-cmdstanr
Dockerfile for docker-cmdstanr
- Built on top of rocker/tidyverse:4.4.1 (ubuntu 22.04)
- Installs CmdStan 2.35.0, rstan, cmdstanr, brms, rstanarm, daggity, future, tidybayes, bayesplot, Matrix, projpred, loo, and easystats

## Docker code to pull and run image
```
docker pull jmgirard/docker-cmdstanr
docker run -e PASSWORD=pass -p 8787:8787 jmgirard/docker-cmdstanr
```

## R code to test between-and-within-chain parallelization
```r
library(brms)
fit_serial <- brm(
  count ~ zAge + zBase * Trt + (1|patient),
  data = epilepsy, family = poisson(),
  chains = 4, cores = 4, backend = "cmdstanr"
)
fit_parallel <- update(
  fit_serial, chains = 2, cores = 2,
  backend = "cmdstanr", threads = threading(2)
)
```
