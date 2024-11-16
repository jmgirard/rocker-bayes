# docker-cmdstanr
Dockerfile for docker-cmdstanr
Built on top of rocker/tidyverse:4.4.1

## Docker code to pull and run image
```
docker pull jmgirard/docker-cmdstanr
docker run -e PASSWORD=pass -p 8787:8787 jmgirard/docker-cmdstanr
```

## R code to test within-chain parallelization
```r
library(cmdstanr)
file <- file.path(cmdstan_path(), "examples", "bernoulli", "bernoulli.stan")
mod <- cmdstan_model(file)
data_list <- list(N = 10, y = c(0,1,0,0,0,0,0,0,0,1))
fit <- mod$sample(
  data = data_list,
  seed = 123,
  chains = 4,
  parallel_chains = 4,
  refresh = 500
)
```
