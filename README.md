# rocker-bayes
Dockerfile for rocker-bayes (v3.0)
- Built on top of rocker/rstudio:4.4.1 (ubuntu 22.04)
- Installs CmdStan 2.35.0
- Installs packages: brms cmdstanr easystats effects ggeffects patchwork rstan tidyverse

*Note that this image supports both AMD64 and ARM64 architectures.*

## Build image locally
```
# git clone https://github.com/jmgirard/rocker-bayes.git
# cd rocker-bayes
docker build . -f bayes_4.4.1.Dockerfile -t rocker-bayes
```

## Pull and run image
```
docker pull jmgirard/rocker-bayes
docker run -e PASSWORD=pass -p 8787:8787 jmgirard/rocker-bayes
```

## Test between-and-within-chain parallelization
Note that this small model won't get much benefit from within-chain parallelization. It's just used to test that everything is working.
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
