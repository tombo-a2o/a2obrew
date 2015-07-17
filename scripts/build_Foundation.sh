#!/bin/bash -exu
source emsdk/emsdk_env.sh > /dev/null

if [ ! -d ./Foundation ]; then
  git clone git@github.com:tomboinc/Foundation.git --branch feature/emscripten
fi

cd Foundation
git pull

# Build
pushd System/CoreFoundation/src
make
make install
popd

pushd System/Security
make
make install
popd

pushd System/CFNetwork/src
make
make install
popd

pushd System/CoreGraphics
make
make install
popd

pushd System/Foundation/src
make
make install
popd

pushd System/CoreAnimation
make
make install
popd

# Test
cd System/test/helloworld
make -B
node str.js
