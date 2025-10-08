#include <Eigen/Dense>

// This value will be set by CMake during configuration
#ifndef EXPECTED_EIGEN_MAX_ALIGN_BYTES
#error "EXPECTED_EIGEN_MAX_ALIGN_BYTES must be defined by CMake"
#endif

// Compile-time check that EIGEN_MAX_ALIGN_BYTES is defined and matches expected value
#ifdef EIGEN_MAX_ALIGN_BYTES
    // Compile-time assertion to ensure the values match
    static_assert(EIGEN_MAX_ALIGN_BYTES == EXPECTED_EIGEN_MAX_ALIGN_BYTES,
                  "EIGEN_MAX_ALIGN_BYTES does not match the expected value");
#else
    #error "EIGEN_MAX_ALIGN_BYTES macro is not defined"
#endif

// Minimal main function - not actually executed since compilation success is the test
int main() {
    return 0;
}
