#!/bin/bash

for i in `find . -name .git -exec dirname {} \;`; do
  pushd $i > /dev/null
  echo checking: $i
  git status -s -b
  popd > /dev/null
done
