#!/bin/sh
cd emsdk; source ./emsdk_env.sh > /dev/null; cd ..

echo $PATH

# Clone
if [ ! -d ./objc4 ]; then
  git clone git@github.com:tomboinc/objc4.git --branch feature/emscripten
fi

# Build
cd objc4
make
make install-all
