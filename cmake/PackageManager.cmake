# cmake/PackageManager.cmake
#
# Selects between vcpkg and Conan 2 for this project's third-party
# dependencies. vcpkg remains the default until Conan is provisioned in CI.

set(PACKAGE_MANAGER_DEFAULT "vcpkg")
set(PACKAGE_MANAGER "${PACKAGE_MANAGER_DEFAULT}" CACHE STRING
    "Which package manager provides third-party dependencies: vcpkg or conan2")
set_property(CACHE PACKAGE_MANAGER PROPERTY STRINGS vcpkg conan2)

string(TOLOWER "${PACKAGE_MANAGER}" _pm)

if(_pm STREQUAL "vcpkg")
    if(NOT DEFINED CMAKE_TOOLCHAIN_FILE OR NOT EXISTS "${CMAKE_TOOLCHAIN_FILE}")
        message(WARNING
            "PACKAGE_MANAGER=vcpkg but CMAKE_TOOLCHAIN_FILE is not set or does not exist. "
            "Pass -D CMAKE_TOOLCHAIN_FILE=<vcpkg>/scripts/buildsystems/vcpkg.cmake.")
    endif()
elseif(_pm STREQUAL "conan2")
    if(NOT DEFINED CMAKE_TOOLCHAIN_FILE OR NOT EXISTS "${CMAKE_TOOLCHAIN_FILE}")
        message(WARNING
            "PACKAGE_MANAGER=conan2 but CMAKE_TOOLCHAIN_FILE is not set or does not exist. "
            "Run conan install first and pass the generated conan_toolchain.cmake file.")
    endif()
else()
    message(FATAL_ERROR
        "PACKAGE_MANAGER must be 'vcpkg' or 'conan2', got: '${PACKAGE_MANAGER}'.")
endif()

message(STATUS "Package manager: ${PACKAGE_MANAGER}")
