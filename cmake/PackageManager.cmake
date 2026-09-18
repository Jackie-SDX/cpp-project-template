# cmake/PackageManager.cmake
#
# Selects between vcpkg and Conan 2 for this project's third-party
# dependencies (currently: wxWidgets, GTest), controlled by one variable so
# either can be used without editing this file:
#
#   vcpkg:   cmake -S . -B build -D PACKAGE_MANAGER=vcpkg -D CMAKE_TOOLCHAIN_FILE=<path-to-vcpkg>/scripts/buildsystems/vcpkg.cmake
#   conan2:  conan install . --output-folder=build --build=missing
#            cmake -S . -B build -D PACKAGE_MANAGER=conan2 -D CMAKE_TOOLCHAIN_FILE=build/conan_toolchain.cmake
#
# 2026-09-10: added per employer request -- support both, with Conan 2
# intended as the eventual default. Defaults to vcpkg FOR NOW: every CI
# config in this project (GitLab, both GitHub workflows, CircleCI) currently
# only provisions vcpkg, and switching the default here without that wiring
# in place would break every pipeline the moment this file lands, not add a
# new option. PACKAGE_MANAGER_DEFAULT below is the only line that needs to
# change once `conan install` exists in the CI configs that need it.
#
# Both package managers are consumed the SAME way everywhere else in this
# project: through ordinary find_package(wxWidgets ...) / find_package(GTest
# ...) calls. Neither needs special-casing outside this file -- vcpkg's
# toolchain file and Conan's generated CMakeToolchain/CMakeDeps files both
# work by making find_package() resolve to their packages transparently.
# That's the whole reason this selection logic is isolated here instead of
# spreading `if(vcpkg) ... else() ...` branches through the rest of the
# build.

set(PACKAGE_MANAGER_DEFAULT "vcpkg") # change to "conan2" once CI provisions it everywhere it's needed

set(PACKAGE_MANAGER "${PACKAGE_MANAGER_DEFAULT}" CACHE STRING
    "Which package manager provides third-party dependencies: vcpkg or conan2")
set_property(CACHE PACKAGE_MANAGER PROPERTY STRINGS vcpkg conan2)

string(TOLOWER "${PACKAGE_MANAGER}" _pm)

if(_pm STREQUAL "vcpkg")
    if(NOT DEFINED CMAKE_TOOLCHAIN_FILE OR NOT EXISTS "${CMAKE_TOOLCHAIN_FILE}")
        message(WARNING
            "PACKAGE_MANAGER=vcpkg but CMAKE_TOOLCHAIN_FILE is not set (or "
            "doesn't exist). It needs to point at vcpkg's "
            "scripts/buildsystems/vcpkg.cmake, passed with "
            "-D CMAKE_TOOLCHAIN_FILE=... on the configure command line -- "
            "the same way this project's existing CI already does it. The "
            "find_package() calls elsewhere in this project will fail "
            "without it.")
    endif()

elseif(_pm STREQUAL "conan2")
    # Conan's generated toolchain file has to be produced and passed in
    # BEFORE this configure step runs -- CMAKE_TOOLCHAIN_FILE loads before
    # the rest of CMakeLists.txt is even processed, so this can only warn
    # here if it's missing, not fix it retroactively.
    if(NOT DEFINED CMAKE_TOOLCHAIN_FILE OR NOT EXISTS "${CMAKE_TOOLCHAIN_FILE}")
        message(WARNING
            "PACKAGE_MANAGER=conan2 but CMAKE_TOOLCHAIN_FILE is not set (or "
            "doesn't exist). Run this first, from the source root:\n"
            "  conan install . --output-folder=build --build=missing\n"
            "then configure with:\n"
            "  -D CMAKE_TOOLCHAIN_FILE=build/conan_toolchain.cmake\n"
            "(the exact generated filename can vary slightly by Conan "
            "profile/generator -- check the `conan install` output if this "
            "path doesn't match.) The find_package() calls elsewhere in "
            "this project will fail without it.")
    endif()

else()
    message(FATAL_ERROR
        "PACKAGE_MANAGER must be 'vcpkg' or 'conan2', got: '${PACKAGE_MANAGER}'. "
        "Set it with -D PACKAGE_MANAGER=vcpkg or -D PACKAGE_MANAGER=conan2.")
endif()

message(STATUS "Package manager: ${PACKAGE_MANAGER}")

