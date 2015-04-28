#!/bin/bash -exu
# Install a2o environment
OS=`uname`

if [ "$OS" = "Darwin" ]; then
  ./scripts/mac/install.sh
elif [ "$OS" = "linux" ]; then
  . /etc/lsb-release
  if which apt-get; then
    ./scripts/ubuntu/install.sh
  else
    echo "* UNKNOWN OS"
    exit 1
  fi
fi

./scripts/install_node.sh
./scripts/install_python.sh
./scripts/install_emsdk.sh
./scripts/build_objc4.sh
./scripts/build_ICU.sh
./scripts/build_libdispatch.sh
./scripts/build_Foundation.sh
