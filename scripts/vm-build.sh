#!/usr/bin/bash

pwd

export LD_LIBRARY_PATH=/home/bas/superbol/lib:/usr/host/lib
export PATH=/home/bas/superbol/bin:${PATH}

if [ ! -e Makefile ]; then
    cd ${APP_HOME}/cobol_repo
fi

./configure
make
make install
