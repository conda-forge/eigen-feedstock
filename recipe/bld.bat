mkdir build
cd build

:: Workaround to make unwanted tools invisible for CMake
:: (E.g., GNU Fortron Compiler)
set PATH=%PATH:C:\ProgramData\chocolatey\bin;=%
set PATH=%PATH:C:\mingw64\bin;=%

set CMAKE_CONFIG="Release"

cmake -LAH -G"NMake Makefiles"              ^
  -DCMAKE_BUILD_TYPE=%CMAKE_CONFIG%         ^
  -DCMAKE_PREFIX_PATH=%LIBRARY_PREFIX%      ^
  -DCMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX%   ^
  -DEIGEN_BUILD_PKGCONFIG=ON ^
  ..
if errorlevel 1 exit 1

cmake --build . --config %CMAKE_CONFIG% --target install
if errorlevel 1 exit 1

rem Just make the basic tests as all the tests take too long to run.
FOR /L %%A IN (1,1,8) DO (
  cmake --build . --config %CMAKE_CONFIG% --target basicstuff_%%A
)
ctest -R basicstuff*
if errorlevel 1 exit 1
goto :eof

:TRIM
  SetLocal EnableDelayedExpansion
  Call :TRIMSUB %%%1%%
  EndLocal & set %1=%tempvar%
  GOTO :eof

  :TRIMSUB
  set tempvar=%*
  GOTO :eof
