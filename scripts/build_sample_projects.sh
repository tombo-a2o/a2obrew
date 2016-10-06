#!/bin/bash -exu
parent_path=$( cd "$(dirname "${BASH_SOURCE}")" ; pwd -P )
cd "$parent_path"

for d in ../sample_projects/*/; do
  cd "$d"
  make
done
