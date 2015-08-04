#!/bin/bash -ex
source emsdk/emsdk_env.sh > /dev/null

if [ ! -d ./blocks-runtime ]; then
  git clone git@github.com:mheily/blocks-runtime.git
fi

cd blocks-runtime
git pull
autoreconf -i || autoreconf -i
AR=emar emconfigure ./configure --prefix=${EMSCRIPTEN}/system/local --enable-static --disable-shared
rm a.out*
make
make install
