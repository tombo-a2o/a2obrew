#!/bin/bash -ex
source emsdk/emsdk_env.sh > /dev/null

if [ ! -d ./Chameleon ]; then
  git clone git@github.com:tomboinc/Chameleon.git --branch feature/emscripten
fi

cd Chameleon
git pull
cd UIKit
make
make install
