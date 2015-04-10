#!/bin/sh
cd emsdk; source ./emsdk_env.sh > /dev/null; cd ..

if [ ! -d ./Foundation ]; then
  git clone git@github.com:tomboinc/Foundation.git
fi

cd Foundation

# Build
cd System/CoreFoundation/src
make
make install
cd ../../../
cd System/Foundation/src
make
make install

# Test
cd ../../../
cd System/test
make
node str.js
