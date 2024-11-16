# rocker-bayes
Dockerfile for rocker-bayes
- Built on top of rocker/tidyverse:4.4.1 (ubuntu 22.04)
- Installs CmdStan 2.35.0
- Installs engines: brms cmdstanr rstan rstanarm
- Installs supports: bayesplot easystats future ggeffects Matrix projpred rstanarm shinystan tidybayes

## Docker code to pull and run image
```
docker pull jmgirard/rocker-bayes
docker run -e PASSWORD=pass -p 8787:8787 jmgirard/rocker-bayes
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
