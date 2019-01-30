#!/usr/bin/env bash
pushd modules/terminal/
python setup.py clean
rm -vf *.c *.cpp *.so
popd
rm -vf terminal.so
