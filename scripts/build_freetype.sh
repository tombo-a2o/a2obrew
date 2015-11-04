#!/bin/bash -ex
source emsdk/emsdk_env.sh > /dev/null

if [ ! -d ./freetype ]; then
  git clone git@github.com:fchiba/freetype.git --branch master
fi

pushd freetype
emconfigure ./configure --prefix=${EMSCRIPTEN}/system/local --disable-shared
emmake make
emmake make install
popd
