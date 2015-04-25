#!/bin/sh -ex

# needs user id
[ $# -eq 1 ]

for repo in emsdk/emscripten/a2o_64bit emsdk/clang/fastcomp/src emsdk/clang/fastcomp/src/tools/clang; do
  pushd $repo
  remote=`git config --get remote.origin.url`
  add=`echo $remote | sed -e s/tomboinc/$1/g`
  git remote show $1 || git remote add $1 $add
  git fetch $1
  popd
done
