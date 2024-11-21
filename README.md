# rocker-bayes
Dockerfile for rocker-bayes (v3.0)
- Built on top of rocker/rstudio:4.4.1 (ubuntu 22.04)
- Installs CmdStan 2.35.0
- Installs packages: brms cmdstanr easystats effects ggeffects patchwork rstan tidyverse

*Note that this image supports both AMD64 and ARM64 architectures.*

# How to use

## Option 1: Pull and run image
Most users will want to just install Docker Desktop, pull the image, and run it. Then navigate to <http://localhost:8787> and enter "rstudio" and "pass".

```
docker pull jmgirard/rocker-bayes
docker run -e PASSWORD=pass -p 8787:8787 jmgirard/rocker-bayes
```

## Option 2: Build image locally
You could also download the Dockerfile from GitHub and build it yourself. Then navigate to <http://localhost:8787> and enter "rstudio" and "pass".

```
# git clone https://github.com/jmgirard/rocker-bayes.git
# cd rocker-bayes
docker build . -f bayes_4.4.1.Dockerfile -t rocker-bayes
```

# Test between-and-within-chain parallelization

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

# How to build multi-architecture image

These notes are more for me, but perhaps others can learn from them.

## Build on Mac for linux/arm64

```
# git clone https://github.com/jmgirard/rocker-bayes.git
# cd rocker-bayes
docker buildx build --platform linux/amd64 --load \
  -f bayes_4.4.1.Dockerfile -t jmgirard/rocker-bayes:arm64 --push .
```

## Build on Windows for linux/amd64

```
# git clone https://github.com/jmgirard/rocker-bayes.git
# cd rocker-bayes
docker build -f bayes_4.4.1.Dockerfile -t jmgirard/rocker-bayes:amd64 --push .
```

## Create multi-architecture manifest list

```
docker manifest create jmgirard/rocker-bayes:latest \
  --amend jmgirard/rocker-bayes:amd64 \
  --amend jmgirard/rocker-bayes:arm64
docker manifest annotate jmgirard/rocker-bayes:latest \
  jmgirard/rocker-bayes:amd64 --arch amd64
docker manifest annotate jmgirard/rocker-bayes:latest \
  jmgirard/rocker-bayes:arm64 --arch arm64
docker manifest push jmgirard/rocker-bayes:latest
```

