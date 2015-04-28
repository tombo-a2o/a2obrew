#!/bin/bash -exu
source emsdk/emsdk_env.sh > /dev/null

if [ ! -f ./downloads/icu4c-54_1-src.tgz ]; then
  curl -o ./downloads/icu4c-54_1-src.tgz http://download.icu-project.org/files/icu4c/54.1/icu4c-54_1-src.tgz
fi

if [ ! -d ./icu ]; then
  tar xvfz ./downloads/icu4c-54_1-src.tgz
fi

cd icu
mkdir -p buildMac buildEmscripten
cd buildMac
../source/runConfigureICU MacOSX
make
cd ../buildEmscripten
source ../../emsdk/emsdk_env.sh
emconfigure \
  ../source/configure \
  --enable-static \
  --disable-shared \
  --disable-icuio \
  --disable-layout \
  --disable-tests \
  --disable-samples \
  --disable-extras \
  --disable-tools \
  --with-data-packaging=files \
  --prefix=${EMSCRIPTEN}/system/local \
  --with-cross-build=`pwd`/../buildMac
emmake make ARFLAGS=rv
make install
