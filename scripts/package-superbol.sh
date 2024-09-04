#!/bin/sh

set -ev

# Compile the latest versions of padbol:master and gnucobol:gnucobol-3.x
# and generate a binary archive 

# The script expects an opam switch 'for-padbol' with all the needed
# dependencies to build padbol
# We target a non-relocatable distribution, with install directory
# /home/bas/superbol. Make sure /home/bas exists on your system.

TARGETDIR=/home/bas/superbol
BUILDDIR=$(pwd)/tmp-builddir

DATE=$(date +%Y%m%d%H%M)

#rm -rf ${TARGETDIR}
#rm -rf ${BUILDDIR}

mkdir -p ${BUILDDIR}
cd ${BUILDDIR}

if [ -e gnucobol ]; then
    git -C gnucobol pull
else
    git clone git@github.com:OCamlPro/gnucobol
    git -C gnucobol checkout gnucobol-3.x
fi

if [ -e gnucobol-contrib ]; then
    git -C gnucobol-contrib pull
else
    git clone git@github.com:OCamlPro/gnucobol-contrib
    git -C gnucobol-contrib checkout master
fi

if [ -e padbol ]; then
    git -C padbol pull
else
    git clone git@github.com:OCamlPro/padbol
    git -C padbol checkout master
    (cd padbol; opam switch link for-padbol)
fi
git -C padbol submodule update --recursive --init

GNUCOBOL_COMMIT=$(git -C gnucobol rev-parse --short HEAD)
GCONTRIB_COMMIT=$(git -C gnucobol-contrib rev-parse --short HEAD)
SUPERBOL_COMMIT=$(git -C padbol rev-parse --short HEAD)

if [ ! -e ${TARGETDIR}/commits/gnucobol-${GNUCOBOL_COMMIT} ]; then
    echo GnuCOBOL not up to date
    rm -rf ${TARGETDIR}
fi

if [ ! -e ${TARGETDIR}/commits/superbol-${GCONTRIB_COMMIT} ]; then
    echo GnuCOBOL Contrib not up to date
    rm -rf ${TARGETDIR}
fi

if [ ! -e ${TARGETDIR}/commits/superbol-${SUPERBOL_COMMIT} ]; then
    echo SuperBOL not up to date
    rm -rf ${TARGETDIR}
fi

if [ ! -e ${TARGETDIR}/commits/gnucobol-${GNUCOBOL_COMMIT} ]; then
    cd gnucobol
    if [ ! -e _build/commits/${GNUCOBOL_COMMIT} ]; then
	mkdir -p _build
	cd _build
	../autogen.sh install
	../configure --prefix=${TARGETDIR}
	make -j
	rm -rf commits
	mkdir commits
	touch commits/${GNUCOBOL_COMMIT}
	cd ..
    fi
    cd _build
    make install
    mkdir -p ${TARGETDIR}/commits/
    echo > ${TARGETDIR}/commits/gnucobol-${GNUCOBOL_COMMIT}
    cd ../..
fi

LD_LIBRARY_PATH=${TARGETDIR}/lib:${LD_LIBRARY_PATH}
export LD_LIBRARY_PATH

LIBRARY_PATH=${LD_LIBRARY_PATH}
export LIBRARY_PATH

C_INCLUDE_PATH=$${TARGETDIR}/include
export C_INCLUDE_PATH

if [ ! -e ${TARGETDIR}/commits/superbol-${SUPERBOL_COMMIT} ]; then
    cd padbol
    SUPERBOL_COMMIT=$(git rev-parse --short HEAD)
    make

    cd superkix
    cargo build --release
    cd ..

    cp -f padbol ${TARGETDIR}/bin/superbol
    find superkix/third-parties -name '*.so' -exec cp -f {} ${TARGETDIR}/lib \;
    cp -f superkix/target/release/server ${TARGETDIR}/bin/superkix
    cp -f superkix/target/release/libsuperkix.so ${TARGETDIR}/lib/
    cp -f $(ldd ${TARGETDIR}/bin/superkix | awk '{ print $3 }' | grep -v /home/bas/superbol) ${TARGETDIR}/lib/
    cd ..

    echo > ${TARGETDIR}/commits/superbol-${SUPERBOL_COMMIT}
fi

cd $(dirname ${TARGETDIR})
ARCHIVE=superbol-x86_64-${DATE}-${SUPERBOL_COMMIT}-${GNUCOBOL_COMMIT}.tar.gz
tar zcf ${BUILDDIR}/${ARCHIVE} $(basename ${TARGETDIR})

echo
echo
echo $(basename ${BUILDDIR})/${ARCHIVE} generated
