#!/bin/bash

set -e

# Install the latest release on the VM

INSTALLDIR=$(readlink -f "${INSTALLDIR:-${HOME}/superbol}")

mkdir -p tmp-install

mkdir -p ${INSTALLDIR}/bin
mkdir -p ${INSTALLDIR}/lib
mkdir -p ${INSTALLDIR}/include
mkdir -p ${INSTALLDIR}/share


tar -xvzf superbol-install.tar.gz -C tmp-install

cp -Rf tmp-install/target/home/* /home/

export PATH=${INSTALLDIR}/bin:${PATH}
export LD_LIBRARY_PATH=${INSTALLDIR}/lib:${LD_LIBRARY_PATH}
export C_INCLUDE_PATH=${INSTALLDIR}/include:${C_INCLUDE_PATH}
