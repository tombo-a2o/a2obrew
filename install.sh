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
bin/a2obrew emscripten update

source emsdk/emsdk_env.sh > /dev/null
eval "$(bin/a2obrew init -)"

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

# Install commit hooks
./scripts/install_commit_hooks.sh
