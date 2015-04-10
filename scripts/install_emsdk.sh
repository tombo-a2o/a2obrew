#!/bin/sh
# Install emsdk
if [ ! -d ./emsdk ]; then
# FIXME: Change after https://github.com/juj/emsdk/pull/30 is merged
# git clone https://github.com/juj/emsdk
  git clone https://github.com/gunyarakun/emsdk > /dev/null
  cd emsdk
  source ./emsdk_env.sh > /dev/null
else
  cd emsdk
  source ./emsdk_env.sh > /dev/null
  git pull > /dev/null
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
