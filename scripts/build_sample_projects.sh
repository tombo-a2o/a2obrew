#!/bin/bash -exu
parent_path=$( cd "$(dirname "${BASH_SOURCE}")" ; pwd -P )
cd "$parent_path"
cd ..
PATH="$PATH:$(pwd)/bin"
eval "$(a2obrew init -)"

for d in sample_projects/*/; do
  pushd .
  cd "$d"
  rm -rf ./a2o
  make
  popd
done
