#!/bin/bash -exu
(cd emsdk/emscripten/a2o; git pull)
(cd emsdk/clang/fastcomp/src; git pull)
(cd emsdk/clang/fastcomp/src/tools/clang; git pull)
