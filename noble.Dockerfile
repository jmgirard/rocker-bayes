FROM jmgirard/rstudio2u:noble

LABEL org.label-schema.license="MIT" \
      org.label-schema.vcs-url="https://github.com/jmgirard/rocker-bayes" \
      org.label-schema.vendor="Girard Consulting" \
      maintainer="Jeffrey Girard <me@jmgirard.com>"

# Install Bayes
ENV CMDSTAN_VERSION=2.36.0

COPY scripts /rocker_scripts
RUN chmod -R +x /rocker_scripts/
RUN /rocker_scripts/install_bayes.sh

EXPOSE 8787
CMD ["/init"]
