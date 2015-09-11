#!/bin/bash -exu
source emsdk/emsdk_env.sh > /dev/null

echo $PATH

# Clone
if [ ! -d ./pixman ]; then
  git clone git://anongit.freedesktop.org/git/pixman.git
fi

if [ ! -d ./cairo ]; then
  git clone git://anongit.freedesktop.org/git/cairo
fi

# Build
cd pixman
sed -e "s/AM_INIT_AUTOMAKE(\[foreign dist-bzip2\])/AM_INIT_AUTOMAKE([foreign dist-bzip2 subdir-objects])/g" configure.ac > tmp
mv tmp configure.ac
NOCONFIGURE=1 ./autogen.sh || autoreconf -i
emconfigure ./configure --prefix=${EMSCRIPTEN}/system/local --enable-shared=no --enable-static=yes
make
make install
cd ..

cd cairo
NOCONFIGURE=1 ./autogen.sh
emconfigure ./configure \
    --prefix=${EMSCRIPTEN}/system/local \
    --enable-shared=no \
    --enable-static=yes \
    --enable-gl=yes \
    --enable-pthread=no \
    --enable-png=no \
    --enable-script=no \
    --enable-interpreter=no \
    --enable-ps=no \
    --enable-pdf=no \
    --enable-svg=no \
    CFLAGS="-DCAIRO_NO_MUTEX=1"
make
make install
cd ..
