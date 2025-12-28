#!/bin/sh
set -ex

mkdir -p build
cd build

cmake -GNinja ${CMAKE_ARGS} \
  -DCMAKE_PREFIX_PATH=${PREFIX} \
  -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_BUILD_TYPE=Release \
  ..
ninja install
ninja basicstuff -j${CPU_COUNT}
if [[ "${CONDA_BUILD_CROSS_COMPILATION}" != "1" ]]; then
# basicstuff_8 seems to be failing with
# https://gitlab.com/libeigen/eigen/-/issues/2977
ctest --output-on-failure -R basicstuff_[1234567]
fi
