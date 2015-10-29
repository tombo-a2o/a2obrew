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

if [ $# == 1 ]; then
    if [ "$1" = "rebuild" ]; then
        ./scripts/clean_libraries.sh
    fi
fi

./scripts/build_libbsd.sh
./scripts/build_blocks_runtime.sh
./scripts/build_objc4.sh
./scripts/build_ICU.sh
./scripts/build_libdispatch_em.sh
./scripts/build_cairo.sh
./scripts/build_openssl.sh

./scripts/build_frameworks.sh install_header_only
./scripts/build_frameworks.sh install
