cmake_minimum_required(VERSION 3.15)
project(EigenABITest LANGUAGES CXX)

# Find Eigen3
find_package(Eigen3 REQUIRED)

# Get the expected value from command line option
if(NOT DEFINED EXPECTED_EIGEN_MAX_ALIGN_BYTES)
    message(FATAL_ERROR "EXPECTED_EIGEN_MAX_ALIGN_BYTES must be provided")
endif()

# Create the test executable
add_executable(test_abi test_abi.cc)

# Link against Eigen3
target_link_libraries(test_abi Eigen3::Eigen)

# Pass the expected value as a compile definition
target_compile_definitions(test_abi PRIVATE 
    EXPECTED_EIGEN_MAX_ALIGN_BYTES=${EXPECTED_EIGEN_MAX_ALIGN_BYTES})
