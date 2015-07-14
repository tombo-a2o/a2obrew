#!/bin/bash -exu
# Install emsdk

if [ ! -d ./emsdk ]; then
  git clone git@github.com:tomboinc/emsdk --branch feature/objc
fi

cd emsdk

# change repository
if git remote -v | grep juj > /dev/null ; then
  git remote set-url origin git@github.com:tomboinc/emsdk.git
  git fetch
  git reset HEAD .
  git checkout .
  git checkout feature/objc
fi

git pull
source ./emsdk_env.sh

if emsdk list | grep INSTALLED | grep sdk-a2o-64bit > /dev/null; then
  echo "* sdk-a2o-64bit is installed"
else
  cp ../emsdk_manifest.json .
  emsdk install sdk-a2o-64bit
fi

if emsdk list | grep INSTALLED | grep \* | grep sdk-a2o-64bit > /dev/null; then
  echo "* sdk-a2o-64bit is activated"
else
  emsdk activate sdk-a2o-64bit
fi

cd ..
./scripts/update_emscripten.sh

source emsdk/emsdk_env.sh > /dev/null
emcc --clear-cache
