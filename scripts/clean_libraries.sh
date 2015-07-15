#!/bin/bash -exu

rm -rf Foundation blocks-runtime icu libbsd libdispatch-linux libkqueue libpwq objc4 Chameleon
cd emsdk/emscripten/a2o/system
git clean -fdx .
git checkout .
