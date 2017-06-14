#!/bin/bash -exu
a2o_path=$( cd "$(dirname "${BASH_SOURCE}")" ; cd ..; pwd -P )
lang_path="${a2o_path}/lang"
mkdir -p "${lang_path}"
cd "${lang_path}"

if [ ! -d pyenv ]; then
  git clone git@github.com:pyenv/pyenv.git
fi

if [ ! -d python2/bin ]; then
  ./pyenv/plugins/python-build/bin/python-build 2.7.9 python2
fi

if [ ! -d ruby-build ]; then
  git clone https://github.com/rbenv/ruby-build.git
fi

if [ ! -d ruby/bin ]; then
  ./ruby-build/bin/ruby-build 2.4.1 ruby
fi

if [ ! -f ruby/bin/bundle ]; then
  ./ruby/bin/gem install bundler
fi

if [ ! -d node-build ]; then
  git clone https://github.com/nodenv/node-build.git
fi

if [ ! -d node/bin ]; then
  ./node-build/bin/node-build 6.11.0 node
fi
