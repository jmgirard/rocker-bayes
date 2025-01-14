# rocker-bayes

## Image Tags/Versions

| Tag    | Base Image     | Operating System       | R ver | CmdStan |
|--------|----------------|------------------------|-------|---------|
| latest | rocker/rstudio | "noble" (Ubuntu 24.04) | 4.4.2 | 2.36.0  |
| 4.4.2  | rocker/rstudio | "noble" (Ubuntu 24.04) | 4.4.2 | 2.36.0  |
| 4.4.1  | rocker/rstudio | "jammy" (Ubuntu 22.04) | 4.4.1 | 2.35.0  |


## Included R packages

### Interfaces
- [brms](https://paulbuerkner.com/brms/)
- [rstanarm](https://mc-stan.org/rstanarm/)

### Backends
- [cmdstanr](https://mc-stan.org/cmdstanr/)
- [rstan](https://mc-stan.org/rstan/)

### Data Preparation
- [data.table](https://rdatatable.gitlab.io/data.table/)
- [tidyverse](https://www.tidyverse.org/)

### Model Interrogation
- [bayesplot](https://mc-stan.org/bayesplot/)
- [easystats](https://easystats.github.io/easystats/)
- [ggeffects](https://strengejacke.github.io/ggeffects/)
- [shinystan](https://mc-stan.org/shinystan/)
- [tidybayes](https://mjskay.github.io/tidybayes/)

# How to use

## Option 1: Pull and run image
Most users will want to just install Docker Desktop, pull the image, and run it.

```
docker pull jmgirard/rocker-bayes
docker run -e PASSWORD=pass -p 8787:8787 jmgirard/rocker-bayes
```

Then navigate to <http://localhost:8787> in your web browser and enter "rstudio" and "pass".<br />
Use volumes or bind mounts to grant the container access to persistent storage or host directories.

## Option 2: Build image locally
You could also download the Dockerfile from GitHub and build it yourself.

```
git clone https://github.com/jmgirard/rocker-bayes.git
cd rocker-bayes
docker-compose up --build -d
```

Then navigate to <http://localhost:8787> in your web browser and enter "rstudio" and "pass".<br />
You can also customize the port and password by editing `.env` in a text editor.

# Test between-and-within-chain parallelization
Note that this small model won't get much benefit from within-chain parallelization. <br />
It's just used to quickly test that everything is working.

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
