#!/bin/bash -exu
source emsdk/emsdk_env.sh > /dev/null

if [ ! -d ./Foundation ]; then
  git clone git@github.com:tomboinc/Foundation.git --branch feature/emscripten
fi

cd Foundation
git pull

repos="CoreGraphics"

for repo in $repos; do
    (cd System/$repo; make install)
done

# Test
cd System/test/helloworld
make -B
node str.js
