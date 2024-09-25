#!/bin/bash

set -e

# Compile the latest versions of padbol:master and gnucobol:gnucobol-3.x
# and generate a binary archive 


if ldconfig -p | grep libpq; then
    :
else
    echo "Postgresql does not seem to be installed, please install it."
    exit 1
fi

# By default The script expects an opam switch 'for-padbol' with all the needed
# dependencies to build padbol and targets a non-relocatable distribution, with install directory
# /home/bas/superbol. Make sure /home/bas exists on your system.
# Alternatively, you can pass as first argument a bash script defining
# TARGETDIR, BUILDIR and/or SWITCHNAME to override their default values.

export SUPERBOL_PACKAGING=1

INSTALLDIR=$(readlink -f "${TARGETDIR:-/home/bas/superbol}")
BUILDDIR=$(readlink -f "${BUILDDIR:-$(pwd)/tmp-builddir}")
SWITCHNAME="${SWITCHNAME:-for-padbol}"
TARGETDIR="${TARGETDIR:-INSTALL_DIR}"


export LD_LIBRARY_PATH="${TARGETDIR}/lib:${TARGETDIR}/lib64"
export LIBRARY_PATH="${TARGETDIR}/lib:${TARGETDIR}/lib64"

DATE=$(date +%Y%m%d%H%M)

#rm -rf ${TARGETDIR}
#rm -rf ${BUILDDIR}

mkdir -p ${BUILDDIR}
cd ${BUILDDIR}

if [ -e gixsql ]; then
    git -C gixsql pull
else
    git clone git@github.com:fmtlib/fmt.git
    git -C fmt checkout 10.2.1
    git clone git@github.com:gabime/spdlog.git
    git clone -b multiline-declare-section git@github.com:emilienlemaire/gixsql.git
fi

if [ -e gnucobol ]; then
    git -C gnucobol pull
else
    git clone -b gnucobol-3.x git@github.com:OCamlPro/gnucobol --depth 1
fi

if [ -e padbol ]; then
    git -C padbol pull
else
    git clone git@github.com:OCamlPro/padbol --depth 1
    (cd padbol; opam switch link $SWITCHNAME)
fi
git -C padbol submodule update --recursive --init

FMT_COMMIT=$(git -C fmt rev-parse --short HEAD)
SPDLOG_COMMIT=$(git -C spdlog rev-parse --short HEAD)
GIXSQL_COMMIT=$(git -C gixsql rev-parse --short HEAD)
GNUCOBOL_COMMIT=$(git -C gnucobol rev-parse --short HEAD)
SUPERBOL_COMMIT=$(git -C padbol rev-parse --short HEAD)

if [ ! -e ${TARGETDIR}/commits/gixsql-${GIXSQL_COMMIT} ]; then
    echo GixSQL not up to date
    rm -rf ${TARGETDIR}
fi

if [ ! -e ${TARGETDIR}/commits/gnucobol-${GNUCOBOL_COMMIT} ]; then
    echo GnuCOBOL not up to date
    rm -rf ${TARGETDIR}
fi

if [ ! -e ${TARGETDIR}/commits/superbol-${SUPERBOL_COMMIT} ]; then
    echo SuperBOL not up to date
    rm -rf ${TARGETDIR}
fi


if [ ! -e ${TARGETDIR}/commits/gixsql-${GIXSQL_COMMIT} ]; then

    export CMAKE_PREFIX_PATH=$TARGETDIR
    export CMAKE_MODULE_PATH=$TARGETDIR/lib
    export PKG_CONFIG_PATH=${TARGETDIR}/lib64/pkgconfig:${TARGETDIR}/lib/pkgconfig
    export CMAKE_FIND_USE_CMAKE_SYSTEM_PATH=FALSE

    cd fmt
    if [ ! -e "_build/commits/${FMT_COMMIT}" ]; then
	mkdir -p _build
	cd _build
	cmake -DCMAKE_INSTALL_PREFIX:PATH=${TARGETDIR} -DBUILD_SHARED_LIBS=TRUE -DFMT_TEST=OFF ..
	make -j
	make install
	rm -rf commits
	mkdir commits
	touch commits/${FMT_COMMIT}
	cd ..
    fi
    cd ..

    export CXXFLAGS="$(pkg-config --cflags fmt)"
    export LIBS="$(pkg-config --libs fmt) $LIBS"

    cd spdlog
    if [ ! -e "_build/commits/${SPDLOG_COMMIT}" ]; then
	mkdir -p _build
	cd _build
	cmake -DCMAKE_INSTALL_PREFIX:PATH=${TARGETDIR} -DBUILD_SHARED_LIBS=TRUE -DSPDLOG_BUILD_EXAMPLE=NO -DSPDLOG_BUILD_TESTS=NO -DSPDLOG_FMT_EXTERNAL=ON -DCMAKE_CXX_FLAGS="-fPIC" ..
	make -j
	make install
	rm -rf commits
	mkdir commits
	touch commits/${SPDLOG_COMMIT}
	cd ..
    fi
    cd ..

    export CXXFLAGS="$(pkg-config --cflags spdlog) $CXXFLAGS"
    export LIBS="$(pkg-config --libs spdlog) $LIBS"

    cd gixsql
    if [ ! -e "_build/commits/gixsql-${GIXSQL_COMMIT}" ]; then
	touch extra_files.mk
	autoreconf -i
	./configure --prefix=${TARGETDIR}
	make -j
	make install
    fi
    mkdir -p ${TARGETDIR}/commits/
    echo > ${TARGETDIR}/commits/gixsql-${GIXSQL_COMMIT}
    cd ..
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

C_INCLUDE_PATH=${TARGETDIR}/include
export C_INCLUDE_PATH


if [ ! -e ${TARGETDIR}/commits/superbol-${SUPERBOL_COMMIT} ]; then
    cd padbol
    SUPERBOL_COMMIT=$(git rev-parse --short HEAD)
    make -j

    cd superkix
    export TARGETDIR
    cargo build --release
    cd ..

    cp -f padbol ${TARGETDIR}/bin/superbol
    find superkix/third-parties -name '*.so' -exec cp -f {} ${TARGETDIR}/lib \;
    cp -f superkix/target/release/server ${TARGETDIR}/bin/superkix
    cp -f superkix/target/release/libsuperkix.so ${TARGETDIR}/lib/
    cp -f $(ldd ${TARGETDIR}/bin/superkix | awk '{ print $3 }' | grep -v ${TARGETDIR}) ${TARGETDIR}/lib/
    cd ..

    echo > ${TARGETDIR}/commits/superbol-${SUPERBOL_COMMIT}
fi

cd $(dirname ${TARGETDIR})
ARCHIVE=superbol-x86_64-${DATE}-${SUPERBOL_COMMIT}-${GNUCOBOL_COMMIT}.tar.gz
tar zcf ${BUILDDIR}/${ARCHIVE} $(basename ${TARGETDIR})

echo
echo
echo $(basename ${BUILDDIR})/${ARCHIVE} generated
