# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# Base image
# ---------------------------------------------------------------------------
# rstudio2u tag to build on. Override to build the different tags, e.g. build
# the "resolute" tag with:
#   docker build --build-arg BASE_TAG=resolute .
ARG BASE_TAG=noble
FROM jmgirard/rstudio2u:${BASE_TAG}

LABEL org.label-schema.license="MIT" \
      org.label-schema.vcs-url="https://github.com/jmgirard/rocker-bayes" \
      org.label-schema.vendor="Girard Consulting" \
      maintainer="Jeffrey Girard <me@jmgirard.com>"

# ---------------------------------------------------------------------------
# Build configuration
# ---------------------------------------------------------------------------
# CmdStan version to install. Pin a specific release to override, e.g.:
#   docker build --build-arg CMDSTAN_VERSION=2.39.0 .
ARG CMDSTAN_VERSION="2.39.0"
ENV CMDSTAN_VERSION=${CMDSTAN_VERSION}

# ---------------------------------------------------------------------------
# Install Bayesian analysis stack (R packages + CmdStan)
# ---------------------------------------------------------------------------
COPY scripts /rocker_scripts
RUN chmod -R +x /rocker_scripts \
    && /rocker_scripts/install_bayes.sh

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
# Report container health by checking that RStudio Server is serving HTTP.
# wget already exits non-zero when the request fails, so the exec form needs no
# shell and no explicit `|| exit 1`.
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD ["wget", "-q", "-O", "/dev/null", "http://localhost:8787/"]

EXPOSE 8787
CMD ["/init"]
