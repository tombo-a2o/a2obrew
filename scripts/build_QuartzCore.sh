#!/bin/bash -exu
source emsdk/emsdk_env.sh > /dev/null

if [ ! -d ./UIKit ]; then
  git clone git@github.com:tomboinc/UIKit.git --branch master
fi

cd UIKit 
git pull

make -B -f Makefile.QuartzCore install