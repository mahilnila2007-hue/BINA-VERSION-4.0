cmake_minimum_required(VERSION 3.10)
project(rehabrep_native LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include_directories(include)

# Shared library for Dart FFI / Android NDK
add_library(rehabrep_native SHARED
    src/angle.cpp
    src/rep_engine.cpp
    src/emg.cpp
)

# Unit test binary
add_executable(test_rep_engine
    tests/test_rep_engine.cpp
    src/angle.cpp
    src/rep_engine.cpp
    src/emg.cpp
)
