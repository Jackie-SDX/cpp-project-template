#!/usr/local/bin/cmake -P

include(ProcessorCount)
ProcessorCount(N)

set(ENV{CTEST_OUTPUT_ON_FAILURE} "ON")

# CDash: https://cmake.org/cmake/help/book/mastering-cmake/chapter/CDash.html
# GitHub Actions checks out pull requests as detached merge commits, so the
# CTest Update/Submit dashboard steps are not meaningful there and can fail on
# repository operations. Keep the actual Configure/Build/Test/MemCheck/Coverage
# stages while making dashboard integration opt-in through CTEST_DASHBOARD.
set(CTEST_STEPS Start Configure Build Test)

if("$ENV{CTEST_DASHBOARD}" STREQUAL "ON")
  list(INSERT CTEST_STEPS 1 Update)
endif()

if("$ENV{RUNNER_OS}" STREQUAL "Linux")
  list(APPEND CTEST_STEPS MemCheck)
endif()

if("$ENV{CC}" STREQUAL "gcc")
  list(APPEND CTEST_STEPS Coverage)
endif()

if("$ENV{CTEST_DASHBOARD}" STREQUAL "ON")
  list(APPEND CTEST_STEPS Submit)
endif()

foreach(step IN LISTS CTEST_STEPS)
  execute_process(
    COMMAND ctest -j ${N} -C $ENV{BUILD_TYPE} -D Continuous${step}
    WORKING_DIRECTORY build
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE output
    ECHO_OUTPUT_VARIABLE ECHO_ERROR_VARIABLE
  )
  if(NOT result EQUAL 0)
    string(REGEX MATCH "[0-9]+% tests.*[0-9.]+ sec.*$" test_results "${output}")
    string(REPLACE "\n" "%0A" test_results "${test_results}")
    message("::error::${test_results}")
    message(FATAL_ERROR "Running ctest -D Continuous${step} failed!")
  endif()
endforeach()