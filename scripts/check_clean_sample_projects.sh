#!/bin/bash -exu
parent_path=$( cd "$(dirname "${BASH_SOURCE}")" ; pwd -P )
cd "$parent_path"
cd ..
PATH="$PATH:$(pwd)/bin"
eval "$(a2obrew init -)"

for d in sample_projects/*/; do
  pushd .
  cd "$d"
  make clean
  # file count should be zero
  echo "Checking whether make clean properly works or not."
  find a2o/build -type f | grep -v '\.nib$' | wc -l | grep -E '^(\s+)0$'
  popd
done
