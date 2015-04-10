#!/bin/sh
cd emsdk; source ./emsdk_env.sh > /dev/null; cd ..

if [ ! -d ./Foundation ]; then
  git clone git@github.com:tomboinc/Foundation.git --branch feature/emscripten
fi

cd Foundation

# Build
cd System/CoreFoundation/src
make
DSTROOT=${EMSCRIPTEN}/system/frameworks make install
cd ../../../
cd System/Foundation/src
make
DSTROOT=${EMSCRIPTEN}/system/frameworks make install

# Test
cd ../../../
cd System/test
make
node str.js
