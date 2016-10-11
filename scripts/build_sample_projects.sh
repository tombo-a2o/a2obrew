#!/bin/bash -exu
parent_path=$( cd "$(dirname "${BASH_SOURCE}")" ; pwd -P )
cd "$parent_path"
cd ..
eval "$(bin/a2obrew init -)"

for d in sample_projects/*/; do
  pushd .
  cd "$d"
  make
  popd
done
