#!/bin/bash -ex
source emsdk/emsdk_env.sh > /dev/null

if [ ! -d ./libdispatch ]; then
  git clone git@github.com:tomboinc/libdispatch-linux.git --branch feature/emscripten
fi

cd libdispatch
git pull
make
make install
