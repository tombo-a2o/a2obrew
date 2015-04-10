#!/bin/sh
cd emsdk; source ./emsdk_env.sh > /dev/null; cd ..

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
  --build=i686-pc-linux-gnu \
  --prefix=${EMSCRIPTEN}/system/local \
  --with-cross-build=`pwd`/../buildMac
emmake make
make install
