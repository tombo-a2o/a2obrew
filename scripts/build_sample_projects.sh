#!/bin/bash -exu
parent_path=$( cd "$(dirname "${BASH_SOURCE}")" ; pwd -P )
cd "$parent_path"
eval "$(bin/a2obrew init -)"

for d in ../sample_projects/*/; do
  cd "$d"
  make
done
