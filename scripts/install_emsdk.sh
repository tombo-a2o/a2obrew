#!/bin/bash -exu
# Install emsdk
if [ ! -d ./emsdk ]; then
  git clone https://github.com/juj/emsdk > /dev/null
  cd emsdk
  source ./emsdk_env.sh > /dev/null
else
  cd emsdk
  source ./emsdk_env.sh > /dev/null
  git stash > /dev/null
  git pull > /dev/null
  git stash pop > /dev/null
fi

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

source ./emsdk_env.sh > /dev/null
emcc --clear-cache
