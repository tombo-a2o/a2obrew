#!/bin/bash -ex
source emsdk/emsdk_env.sh > /dev/null

if [ ! -d ./libkqueue ]; then
  git clone git@github.com:tomboinc/libkqueue.git --branch feature/emscripten
fi

if [ ! -d ./libpwq ]; then
  git clone git@github.com:tomboinc/libpwq.git --branch feature/emscripten
fi

if [ ! -d ./libdispatch-linux ]; then
  git clone git@github.com:tomboinc/libdispatch-linux.git --branch feature/emscripten
fi

for repo in libkqueue libpwq; do
  pushd $repo
  git pull
  autoreconf -i || autoreconf -i
  AR=emar emconfigure ./configure --prefix=${EMSCRIPTEN}/system/local --disable-shared --enable-static
  rm a.out*
  emmake make
  emmake make install
  popd
done

cd libdispatch-linux
git pull
# No need to call emconfigure because the configure script is just a wrapper of cmake and calls emcmake internally
./configure --prefix=${EMSCRIPTEN}/system/local
make
make install
