#!/bin/bash -ex
source emsdk/emsdk_env.sh > /dev/null

if [ ! -d ./openssl ]; then
  git clone git@github.com:gunyarakun/openssl.git --branch feature/emscripten
fi

for repo in openssl; do
  pushd $repo
  git pull
  emmake sh ./Configure -no-asm no-ssl3 no-comp no-hw no-engine no-shared no-dso no-gmp --openssldir=$EMSCRIPTEN/system/local linux-generic32
  emmake make build_libs
  emmake make install_emscripten
  popd
done
