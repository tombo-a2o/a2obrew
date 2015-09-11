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

if [ ! -d ./UIKit-WinObjC ]; then
  git clone git@github.com:tomboinc/UIKit-WinObjC.git --branch master
fi

cd UIKit-WinObjC
git pull

for makefile in `ls Makefile*`; do
    make -f $makefile install_header_only
done
