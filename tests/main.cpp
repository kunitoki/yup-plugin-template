#include <yup_test_runner.h>

// Provides the test executable's entry point, reusing YUP's shared GoogleTest
// runner so the runner logic is not duplicated in the template. See
// yup::runGoogleTests() for a function-call alternative.
YUP_IMPLEMENT_GTEST_MAIN()
