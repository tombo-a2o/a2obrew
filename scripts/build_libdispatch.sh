#!/bin/sh -ex
cd emsdk; source ./emsdk_env.sh > /dev/null; cd ..

if [ ! -d ./blocks-runtime ]; then
  git clone git@github.com:mheily/blocks-runtime.git
fi

if [ ! -d ./libkqueue ]; then
  git clone git@github.com:tomboinc/libkqueue.git --branch feature/emscripten
fi

if [ ! -d ./libpwq ]; then
  git clone git@github.com:tomboinc/libpwq.git --branch feature/emscripten
fi

if [ ! -d ./libdispatch-linux ]; then
  git clone git@github.com:tomboinc/libdispatch-linux.git --branch feature/emscripten
fi

for repo in blocks-runtime libkqueue libpwq; do
  pushd $repo
  autoreconf -i || autoreconf -i
  emconfigure ./configure --prefix=${EMSCRIPTEN}/system/local
  emmake make
  emmake make install
  popd
done

cd libdispatch-linux
# No need to call emconfigure because the configure script is just a wrapper of cmake and calls emcmake internally
./configure --prefix=${EMSCRIPTEN}/system/local
make
make install
