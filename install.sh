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

# Install Ruby for a2obrew CLI
./scripts/install_ruby.sh

# Install LLs for emscripten
./scripts/install_node.sh
./scripts/install_python.sh
# Install emscripten
./scripts/install_emsdk.sh

source emsdk/emsdk_env.sh > /dev/null

if [ $# == 1 ]; then
    if [ "$1" = "rebuild" ]; then
        bin/a2obrew clean
    fi
fi

bin/a2obrew update
bin/a2obrew autogen
# install basic libraries
# libbsd
bin/a2obrew configure libbsd
bin/a2obrew build libbsd
bin/a2obrew install libbsd
# blocks-runtime
bin/a2obrew configure blocks-runtime
bin/a2obrew build blocks-runtime
bin/a2obrew install blocks-runtime
# objc4
bin/a2obrew configure objc4
bin/a2obrew build objc4
bin/a2obrew install objc4
# ICU
bin/a2obrew configure icu
bin/a2obrew build icu
bin/a2obrew install icu
# libdispatch
bin/a2obrew configure libdispatch
bin/a2obrew build libdispatch
bin/a2obrew install libdispatch
# pixman
bin/a2obrew configure pixman
bin/a2obrew build pixman
bin/a2obrew install pixman
# cairo
bin/a2obrew configure cairo
bin/a2obrew build cairo
bin/a2obrew install cairo
# openssl
bin/a2obrew configure openssl
bin/a2obrew build openssl
bin/a2obrew install openssl
# freetype
bin/a2obrew configure freetype
bin/a2obrew build freetype
bin/a2obrew install freetype
# Foundation
bin/a2obrew configure Foundation
bin/a2obrew build Foundation
bin/a2obrew install Foundation
# cocotron
bin/a2obrew configure cocotron
bin/a2obrew build cocotron
bin/a2obrew install cocotron
# Chameleon
bin/a2obrew configure Chameleon
bin/a2obrew build Chameleon
bin/a2obrew install Chameleon
