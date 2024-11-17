ARG R_VERSION=4.4.1

FROM rocker/tidyverse:${R_VERSION}

COPY install_cmdstan.sh /rocker_scripts/install_cmdstan.sh
COPY install_bayes.sh /rocker_scripts/install_bayes.sh

ENV CMDSTAN_VERSION=2.35.0 CMDSTAN=/opt/cmdstan
    
RUN /rocker_scripts/install_cmdstan.sh && /rocker_scripts/install_bayes.sh

CMD ["/init"]