# CTest / CDash configuration.
#
# 2026-09-08: this file used to point at CDash project "cpp-project-template"
# on my.cdash.org -- the UPSTREAM author's dashboard. Every CI test, coverage
# and memcheck run was submitting results into someone else's project. Same
# class of problem as the README badges (Phase 13) and CODEOWNERS (Phase 15).
#
# Submission is now OPT-IN. Nothing is submitted unless CDASH_SUBMIT is
# explicitly enabled AND a project name is provided, so the default behaviour
# is "run tests locally, submit nowhere". Local `ctest -D Experimental` and
# `ctest -T Test` keep working exactly as before.
#
# To enable for this fork: register a project at https://my.cdash.org, then
# configure with
#   -D CDASH_SUBMIT=ON -D CDASH_PROJECT_NAME=<your-project>
# or set CDASH_DROP_SITE for a self-hosted dashboard.
#
# 2026-09-08, VERIFICATION PASS: an independent review found that this file's
# CDASH_SUBMIT (a CMake CACHE variable, set via `option()`, meant for a normal
# `cmake -D CDASH_SUBMIT=ON` + interactive `ctest` workflow) and
# .github/scripts/test.cmake's CDASH_SUBMIT check (which read
# $ENV{CDASH_SUBMIT}, an OS environment variable) were two different
# mechanisms that do not talk to each other. Following this file's own
# instructions above (-D CDASH_SUBMIT=ON) would NOT have actually triggered
# a submission from test.cmake. This file is unchanged -- the fix is in
# test.cmake, which now checks its own script-scope variable first (set via
# `ctest -S test.cmake -D CDASH_SUBMIT=1`) and falls back to the environment
# variable, so it works however it ends up being invoked. See test.cmake.

set(CTEST_PROJECT_NAME "${CMAKE_PROJECT_NAME}")
set(CTEST_NIGHTLY_START_TIME "00:00:00 UTC")

option(CDASH_SUBMIT "Submit CTest results to a CDash dashboard" OFF)
set(CDASH_PROJECT_NAME "" CACHE STRING "CDash project name for this fork (required when CDASH_SUBMIT is ON)")
set(CDASH_DROP_SITE "my.cdash.org" CACHE STRING "CDash server hostname")

if(CDASH_SUBMIT)
    if(CDASH_PROJECT_NAME STREQUAL "")
        message(FATAL_ERROR
            "CDASH_SUBMIT is ON but CDASH_PROJECT_NAME is empty. Set it to THIS "
            "fork's own CDash project -- do not submit to the upstream project.")
    endif()
    set(CTEST_DROP_METHOD "https")
    set(CTEST_DROP_SITE "${CDASH_DROP_SITE}")
    set(CTEST_DROP_LOCATION "/submit.php?project=${CDASH_PROJECT_NAME}")
    set(CTEST_DROP_SITE_CDASH TRUE)
    message(STATUS "CDash submission enabled: https://${CDASH_DROP_SITE} project '${CDASH_PROJECT_NAME}'")
else()
    # No drop site configured -> ctest runs tests and writes local Testing/
    # output, but has nowhere to submit.
    set(CTEST_DROP_SITE_CDASH FALSE)
endif()
