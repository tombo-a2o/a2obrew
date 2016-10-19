#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Usage: ./do_all.sh [some commands]"
  exit 1
fi

for repo in emsdk/emscripten/a2o emsdk/clang/fastcomp/src emsdk/clang/fastcomp/src/tools/clang; do
  (cd $repo; pwd; $*)
done
