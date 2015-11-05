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

eval $(bin/a2obrew env)

if [ $# == 1 ]; then
    if [ "$1" = "rebuild" ]; then
        bin/a2obrew clean
    fi
fi

bin/a2obrew update
bin/a2obrew autogen
bin/a2obrew configure
bin/a2obrew build blocks-runtime
bin/a2obrew install blocks-runtime
bin/a2obrew build objc4
bin/a2obrew install objc4
bin/a2obrew build libdispatch
bin/a2obrew install libdispatch
bin/a2obrew build
bin/a2obrew install
