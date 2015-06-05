#!/bin/bash -exu
source emsdk/emsdk_env.sh > /dev/null

echo $PATH

# Clone
if [ ! -d ./objc4 ]; then
  git clone git@github.com:tomboinc/objc4.git --branch feature/emscripten
fi

# Build
cd objc4
make
make install
