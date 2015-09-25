#!/bin/bash -exu
source emsdk/emsdk_env.sh > /dev/null

if [ ! -d ./Foundation ]; then
  git clone git@github.com:tomboinc/Foundation.git --branch feature/emscripten
fi

cd Foundation
git pull

for repo in `cat System/frameworks.txt`; do
    (cd System/$repo; make install_header_only)
done
cd ..

if [ ! -d ./cocotron ]; then
  git clone git@github.com:tomboinc/cocotron.git --branch feature/emscripten
fi

cd cocotron
git pull

for repo in `cat frameworks.txt`; do
    (cd $repo; make install_header_only)
done
cd ..

if [ ! -d ./Chameleon ]; then
  git clone git@github.com:tomboinc/Chameleon.git --branch feature/with_cocotron
fi

cd Chameleon/UIKit
git pull

make install_header_only
