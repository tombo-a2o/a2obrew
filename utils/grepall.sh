#!/bin/bash

for i in `find . -name .git -exec dirname {} \;`; do
  pushd $i > /dev/null
  echo checking: $i
  git grep $1
  popd > /dev/null
  echo ===================================================================================
done
