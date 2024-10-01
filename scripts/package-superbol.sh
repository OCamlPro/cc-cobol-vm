#!/bin/bash

set -ev

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
INSTALLDIR="/home/bas/superbol"
BUILDDIR=$(readlink -f "${BUILDDIR:-$(pwd)/tmp-builddir}")
SWITCHNAME="${SWITCHNAME:-for-padbol}"
TARGETDIR=$(readlink -f "${TARGETDIR:-INSTALL_DIR}")

echo "Packaging SuperBOL into ${TARGETDIR}"

export LD_LIBRARY_PATH="${TARGETDIR}/${INSTALLDIR}/lib:${TARGETDIR}/${INSTALLDIR}/lib64"
export LIBRARY_PATH="${TARGETDIR}/${INSTALLDIR}/lib:${TARGETDIR}/${INSTALLDIR}/lib64"
export CFLAGS="-static-libgcc"
export CXXFLAGS="-static-libgcc -static-libstdc++"

DATE=$(date +%Y%m%d%H%M)

mkdir -p ${BUILDDIR}
cd ${BUILDDIR}

if [ ! -e fmt ]; then
    git clone git@github.com:fmtlib/fmt.git
    git -C fmt checkout 10.2.1
fi

if [ -e spdlog ]; then
    git -C spdlog pull
else
    git clone git@github.com:gabime/spdlog.git
fi

if [ -e gixsql ]; then
    git -C gixsql pull
else
    git clone -b multiline-declare-section git@github.com:emilienlemaire/gixsql.git
fi

if [ -e visam-2.2.tar.Z ]; then
    if [ ! -e visam-2.2 ]; then
	tar -xvzf visam-2.2.tar.Z
    fi
else
    wget http://inglenet.ca/Products/GnuCOBOL/visam-2.2.tar.Z
    tar -xvzf visam-2.2.tar.Z
fi

if [ -e gnucobol ]; then
    git -C gnucobol pull
else
    git clone -b gnucobol-3.x git@github.com:OCamlPro/gnucobol --depth 1
fi

if [ -e padbol ]; then
    git -C padbol pull
    if [ ! -e padbol/_opam ]; then
	cd padbol
	opam switch link $SWITCHNAME
	cd ..
    fi
else
    git clone -b edit-port git@github.com:emilienlemaire/padbol --depth 1
    cd padbol
    if [ ! -e _opam ]; then
	opam switch link $SWITCHNAME
    fi
    cd ..
    git -C padbol submodule update --recursive --init
fi

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

    export CMAKE_PREFIX_PATH=$TARGETDIR/$INSTALLDIR
    export CMAKE_MODULE_PATH=${TARGETDIR}/${INSTALLDIR}/lib
    export PKG_CONFIG_PATH=${TARGETDIR}/${INSTALLDIR}/lib64/pkgconfig:${TARGETDIR}/${INSTALLDIR}/lib/pkgconfig
    export CMAKE_FIND_USE_CMAKE_SYSTEM_PATH=FALSE

    cd fmt
    if [ ! -e "_build/commits/${FMT_COMMIT}" ]; then
	mkdir -p _build
	cd _build
	cmake -DCMAKE_INSTALL_PREFIX:PATH=${INSTALLDIR} -DBUILD_SHARED_LIBS=TRUE -DFMT_TEST=OFF ..
	make -j
	cd ..
    fi
    cd _build
    make DESTDIR=${TARGETDIR} install
    rm -rf commits
    mkdir commits
    touch commits/${FMT_COMMIT}
    cd ../..

    export CXXFLAGS="$(pkg-config --cflags fmt) $CXXFLAGS"
    export LIBS="$(pkg-config --libs fmt) $LIBS"

    cd spdlog
    if [ ! -e "_build/commits/${SPDLOG_COMMIT}" ]; then
	mkdir -p _build
	cd _build
	cmake -DCMAKE_INSTALL_PREFIX:PATH=${INSTALLDIR} \
	    -DBUILD_SHARED_LIBS=TRUE \
	    -DSPDLOG_BUILD_EXAMPLE=NO \
	    -DSPDLOG_BUILD_TESTS=NO \
	    -DSPDLOG_FMT_EXTERNAL=ON \
	    -DCMAKE_CXX_FLAGS="-fPIC" \
	    ..
	make -j
	cd ..
    fi
    cd _build
    make DESTDIR=${TARGETDIR} install
    rm -rf commits
    mkdir commits
    touch commits/${SPDLOG_COMMIT}
    cd ../..

    export CXXFLAGS="$(pkg-config --cflags spdlog) $CXXFLAGS"
    export LIBS="$(pkg-config --libs spdlog) $LIBS"

    cd gixsql
    if [ ! -e "commits/${GIXSQL_COMMIT}" ]; then
	touch extra_files.mk
	autoreconf -i
	./configure --prefix=${INSTALLDIR}
	make -j
    fi
    make DESTDIR=${TARGETDIR} install
    mkdir -p commits
    touch commits/${GIXSQL_COMMIT}
    mkdir -p ${TARGETDIR}/commits/
    echo > ${TARGETDIR}/commits/gixsql-${GIXSQL_COMMIT}
    cd ..
fi

if [ ! -e ${TARGETDIR}/commits/gnucobol-${GNUCOBOL_COMMIT} ]; then
    echo "Checking for vbisam install"
    cd visam-2.2
    if [ ! -e _build/version/2.2 ]; then
	echo "Not installed: building"
	if [ -e Makefile ]; then
	    make distclean
	fi
	rm -rf _build
	mkdir -p _build
	cd _build
	../configure --prefix=${INSTALLDIR} --enable-vbisamdefault
	make -j
	cd ..
    else
	echo "Installed"
    fi
    cd _build
    make DESTDIR=${TARGETDIR} install
    ln -s ${TARGETDIR}/${INSTALLDIR}/lib/libvisam.so ${TARGETDIR}/${INSTALLDIR}/lib/libvbisam.so
    ln -s ${TARGETDIR}/${INSTALLDIR}/include/visam.h ${TARGETDIR}/${INSTALLDIR}/include/vbisam.h
    mkdir -p version
    touch version/2.2
    cd ../..
    C_INCLUDE_PATH=${TARGETDIR}/${INSTALLDIR}/include
    export C_INCLUDE_PATH
    cd gnucobol
    if [ ! -e _build/commits/${GNUCOBOL_COMMIT} ]; then
	mkdir -p _build
	cd _build
	../autogen.sh install
	../configure --prefix=${INSTALLDIR} --with-vbisam
	make -j
	rm -rf commits
	mkdir commits
	touch commits/${GNUCOBOL_COMMIT}
	cd ..
    fi
    cd _build
    make DESTDIR=${TARGETDIR} install
    mkdir -p ${TARGETDIR}/commits/
    touch ${TARGETDIR}/commits/gnucobol-${GNUCOBOL_COMMIT}
    cd ../..
fi

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

    mkdir -p ${TARGETDIR}/bin/
    mkdir -p ${TARGETDIR}/lib/

    cp -fv padbol ${TARGETDIR}/${INSTALLDIR}/bin/superbol
    find superkix/third-parties -name '*.so' -exec cp -fv {} ${TARGETDIR}/${INSTALLDIR}/lib \;
    cp -fv superkix/target/release/libsuperkix.so ${TARGETDIR}/${INSTALLDIR}/lib
    cp -fv superkix/target/release/server ${TARGETDIR}/${INSTALLDIR}/bin/superkix
    cp -fv $(ldd ${TARGETDIR}/${INSTALLDIR}/bin/superkix | awk '{ print $3 }' | grep -v ${TARGETDIR}) ${TARGETDIR}/${INSTALLDIR}/lib/
    rm -f ${TARGETDIR}/${INSTALLDIR}/lib/libc.so.*
    cd ..

    touch ${TARGETDIR}/commits/superbol-${SUPERBOL_COMMIT}
fi

cd $(dirname ${TARGETDIR})
ARCHIVE=superbol-x86_64-${DATE}-${SUPERBOL_COMMIT}-${GNUCOBOL_COMMIT}.tar.gz
tar zcf ${BUILDDIR}/${ARCHIVE} $(basename ${TARGETDIR})

echo
echo
echo $(basename ${BUILDDIR})/${ARCHIVE} generated
