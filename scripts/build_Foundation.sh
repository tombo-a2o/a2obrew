#!/bin/bash -exu
source emsdk/emsdk_env.sh > /dev/null

if [ ! -d ./Foundation ]; then
  git clone git@github.com:tomboinc/Foundation.git --branch feature/emscripten
fi

cd Foundation
git pull

# Build
cd System/CoreFoundation/src
make
DSTROOT=${EMSCRIPTEN}/system/frameworks make install
cd ../../../
cd System/Foundation/src
make
DSTROOT=${EMSCRIPTEN}/system/frameworks make install
cd ../../../
cd System/CFNetwork/src
make
DSTROOT=${EMSCRIPTEN}/system/frameworks make install
cd ../../../
cd System/CoreGraphics
make
make install
cd ../../

# Test
cd System/test/helloworld
make -B
node str.js
