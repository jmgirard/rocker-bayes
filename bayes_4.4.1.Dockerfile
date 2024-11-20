ARG R_VERSION=4.4.1

FROM rocker/rstudio:${R_VERSION}

COPY install_bayes.sh /rocker_scripts/install_bayes.sh

RUN chmod +x /rocker_scripts/install_bayes.sh && /rocker_scripts/install_bayes.sh

ENV CMDSTAN="/opt/cmdstan"

CMD ["/init"]