#!/usr/bin/env bash
set -e
pushd modules/terminal
python setup.py build_ext --inplace
popd
ln -svf modules/terminal/terminal.*.so terminal.so
./main.py
