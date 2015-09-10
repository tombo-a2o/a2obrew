#!/bin/bash -exu
source emsdk/emsdk_env.sh > /dev/null

if [ ! -d ./UIKit-WinObjC ]; then
  git clone git@github.com:tomboinc/UIKit-WinObjC.git --branch master
fi

cd UIKit-WinObjC
git pull

make -B -f Makefile.CoreGraphics install
