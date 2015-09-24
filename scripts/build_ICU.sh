#!/bin/bash -exu

if [ ! -d ./icu ]; then
  git clone git@github.com:fchiba/icu.git --branch prebuilt
fi

if [ `uname` = "Darwin" ]; then
  nativeDir=buildMac
else
  nativeDir=buildLinux
fi

cd icu
mkdir -p buildEmscripten
cd buildEmscripten
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
  --with-cross-build=`pwd`/../$nativeDir
emmake make ARFLAGS=rv
cd lib
for archive in `ls *.a`; do
    bc=`basename ${archive} .a`.bc
    llvm-ar t ${archive} > files
    llvm-ar x ${archive}
    llvm-link -o ${bc} `cat files`
    rm ${archive}
    rm `cat files`
    rm files
    llvm-ar r ${archive} ${bc}
    rm ${bc}
done
cd ..
make install
