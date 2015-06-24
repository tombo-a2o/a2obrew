#!/bin/bash -exu
(cd emsdk/emscripten/a2o; git pull)
(cd emsdk/clang/fastcomp/src; git pull)
(cd emsdk/clang/fastcomp/src/tools/clang; git pull)
if type nproc ; then
  JOBS=`nproc`
elif type gnproc ; then
  JOBS=`gnproc`
else
  JOBS=1
fi
(cd emsdk/clang/fastcomp/build_feature-objc_64; make -j${JOBS})
