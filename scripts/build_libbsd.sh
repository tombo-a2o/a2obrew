#!/bin/bash -exu
source emsdk/emsdk_env.sh > /dev/null

# Clone
if [ ! -d ./libbsd ]; then
  git clone git@github.com:tomboinc/libbsd.git --branch feature/emscripten
fi

# Build
cd libbsd
git pull
autoreconf -i
emconfigure ./configure --prefix=${EMSCRIPTEN}/system/local
make
make install