#!/bin/bash -exu

rm -rf depends/*
cd emsdk/emscripten/a2o/system
git clean -fdx .
git checkout .
