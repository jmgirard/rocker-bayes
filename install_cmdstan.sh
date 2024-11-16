#!/bin/bash
# install_cmdstan.sh

set -e

## Build ARGs
CMDSTAN_VERSION=${1:-${CMDSTAN_VERSION:-"2.35.0"}}
CMDSTAN=${1:-${CMDSTAN:-"/opt/cmdstan"}}
NCPUS=$(nproc || echo 1)

# A function to install apt packages only if they are not installed
function apt_install() {
    if ! dpkg -s "$@" >/dev/null 2>&1; then
        if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
            apt-get update
        fi
        apt-get install -y --no-install-recommends "$@"
    fi
}

# Install apt dependencies
apt_install build-essential curl libv8-dev

# Make directory for cmdstan
mkdir -p $CMDSTAN

# Download the requested version of the cmdstan installer
curl -fSL https://github.com/stan-dev/cmdstan/releases/download/v$CMDSTAN_VERSION/cmdstan-$CMDSTAN_VERSION.tar.gz -o /tmp/cmdstan.tar.gz

# Extract and decompress the cmdstan installer files 
tar -xz -C $CMDSTAN --strip-components=1 -f /tmp/cmdstan.tar.gz

# Move to the cmdstan installer folder
cd $CMDSTAN

# Install cmdstan from the installer files
make build -j"$NCPUS"

# Give access permissions to rstudio user
chown -R rstudio:rstudio $CMDSTAN

# Clean up
apt-get autoremove -y
apt-get autoclean -y
rm -rf /var/lib/apt/lists/* /tmp/* $CMDSTAN/test
