#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Usage: ./do_all.sh [some commands]"
  exit 1
fi

for repo in emscripten/emscripten emscripten/fastcomp/src emscripten/fastcomp/src/tools/clang; do
  (cd $repo; pwd; $*)
done
