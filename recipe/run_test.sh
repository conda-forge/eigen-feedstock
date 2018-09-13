#!/bin/sh

${CXX} -I${PREFIX}/include -o test test.cc

./test
