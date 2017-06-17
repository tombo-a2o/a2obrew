#!/bin/bash -exu

rm -rf depends/*
cd emscripten/emscripten/system
git clean -fdx .
git checkout .
