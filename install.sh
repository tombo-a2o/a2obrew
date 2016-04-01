#!/bin/bash -ex
# Install a2o environment
OS=`uname`

if [ "$OS" = "Darwin" ]; then
  ./scripts/mac/install.sh
elif [ "$OS" = "Linux" ]; then
  if which apt-get; then
    ./scripts/ubuntu/install.sh
  else
    echo "* UNKNOWN LINUX"
    exit 1
  fi
else
  echo "* UNKNOWN OS"
  exit 1
fi

# Install Ruby for a2obrew CLI
./scripts/install_ruby.sh

# Install LLs for emscripten
./scripts/install_node.sh
./scripts/install_python.sh

# Load LLs
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# Install emscripten
bin/a2obrew emscripten upgrade
source emsdk/emsdk_env.sh > /dev/null
eval "$(bin/a2obrew init -)"

if [ $# == 1 ]; then
    if [ "$1" = "rebuild" ]; then
        bin/a2obrew libraries clean
    fi
fi

# install dependent libraries
bin/a2obrew libraries update
bin/a2obrew libraries autogen
# libbsd
bin/a2obrew libraries configure libbsd
bin/a2obrew libraries build libbsd
bin/a2obrew libraries install libbsd
# blocks-runtime
bin/a2obrew libraries configure blocks-runtime
bin/a2obrew libraries build blocks-runtime
bin/a2obrew libraries install blocks-runtime
# objc4
bin/a2obrew libraries configure objc4
bin/a2obrew libraries build objc4
bin/a2obrew libraries install objc4
# ICU
bin/a2obrew libraries configure icu
bin/a2obrew libraries build icu
bin/a2obrew libraries install icu
# libdispatch
bin/a2obrew libraries configure libdispatch
bin/a2obrew libraries build libdispatch
bin/a2obrew libraries install libdispatch
# openssl
bin/a2obrew libraries configure openssl
bin/a2obrew libraries build openssl
bin/a2obrew libraries install openssl
# freetype
bin/a2obrew libraries configure freetype
bin/a2obrew libraries build freetype
bin/a2obrew libraries install freetype
# Foundation
bin/a2obrew libraries configure Foundation
bin/a2obrew libraries build Foundation
bin/a2obrew libraries install Foundation
# cocotron
bin/a2obrew libraries configure cocotron
bin/a2obrew libraries build cocotron
bin/a2obrew libraries install cocotron
# Chameleon
bin/a2obrew libraries configure Chameleon
bin/a2obrew libraries build Chameleon
bin/a2obrew libraries install Chameleon

# Install commit hooks
./scripts/install_commit_hooks.sh
