#!/bin/bash -exu
source emsdk/emsdk_env.sh > /dev/null

# Clone
if [ ! -d ./libbsd ]; then
  git clone git@github.com:tomboinc/libbsd.git --branch feature/emscripten
fi

# Build
cd libbsd
git pull
./autogen
emconfigure ./configure --prefix=${EMSCRIPTEN}/system/local --disable-shared
make
make install
