#!/bin/bash -ex
source emsdk/emsdk_env.sh > /dev/null

if [ ! -d ./blocks-runtime ]; then
  git clone git@github.com:mheily/blocks-runtime.git
fi

cd blocks-runtime
autoreconf -i || autoreconf -i
emconfigure ./configure --prefix=${EMSCRIPTEN}/system/local
rm a.out*
make
make install
