############################
### C++ Project Template ###
############################

cmake_minimum_required (VERSION 3.21)

if(CMAKE_CURRENT_BINARY_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
	message(FATAL_ERROR "Building in-source is not supported!\nCreate a \"build\" dir and remove:\n- ${CMAKE_SOURCE_DIR}/CMakeCache.txt\n- ${CMAKE_SOURCE_DIR}/CMakeFiles")
endif()

option(BUILD_SOURCE "Build primary libraries and executables." ON)

if(POLICY CMP0091)
	cmake_policy(SET CMP0091 NEW)
endif()
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

set(PROJECT_LANGUAGES NONE)
if(${BUILD_SOURCE})
	set(PROJECT_LANGUAGES CXX)
endif()

if(NOT DEFINED CPP_PROJECT_TEMPLATE_VERSION)
	set(CPP_PROJECT_TEMPLATE_VERSION "0.0.1.0")
endif()

project (cpp-project-template
	VERSION ${CPP_PROJECT_TEMPLATE_VERSION}
	DESCRIPTION "C++ Project Template"
	HOMEPAGE_URL "https://github.com/NaylaCruz/cpp-project-template"
	LANGUAGES ${PROJECT_LANGUAGES})

set(AUTHOR_NAME "NaylaCruz")
set(ORGANIZATION "NaylaCruz")
set(CPACK_PACKAGE_VENDOR "${ORGANIZATION}")
set(CPACK_PACKAGE_CONTACT "${AUTHOR_NAME}")
set(CPACK_RESOURCE_FILE_README "${CMAKE_CURRENT_SOURCE_DIR}/README.md")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")
set(PROJECT_LANGUAGE_NEUTRAL 0)
string(TIMESTAMP COPYRIGHT_YEAR "%Y")
set(CPACK_PACKAGE_COPYRIGHT "© ${COPYRIGHT_YEAR} ${CPACK_PACKAGE_VENDOR}")
set(SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)
set(ASSETS_DIR ${CMAKE_CURRENT_SOURCE_DIR}/assets)
set(PACKAGING_DIR ${CMAKE_CURRENT_SOURCE_DIR}/packaging)
set(DOCS_DIR ${CMAKE_CURRENT_SOURCE_DIR}/docs)
set(DOXYGEN_DIR ${DOCS_DIR}/doxygen)
set(SPHINX_DIR ${DOCS_DIR}/sphinx)

set(CPACK_WIX_UPGRADE_GUID "02FBAAA4-B5EE-435B-AF4A-ADA99C5EAFA0")

file(READ ${CPACK_RESOURCE_FILE_LICENSE} LICENSE NEWLINE_CONSUME ENCODING "UTF-8")
string(REGEX REPLACE "\n\n" ")#license#\"\"\\\\n\\\\n\" R\"#license#(" LICENSE "${LICENSE}")
string(REGEX REPLACE "\n" " " LICENSE "${LICENSE}")
string(REGEX REPLACE "  +" " " LICENSE "${LICENSE}")

configure_file("${SOURCE_DIR}/config.h.in" config.h)

set(CMAKE_CXX_STANDARD 20 CACHE STRING "The C++ standard to use")
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

#####################
### CMake modules ###
#####################

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")
include(cmake/doxygen.cmake)
include(cmake/sphinx.cmake)
include(cmake/clang-format.cmake)
include(cmake/PackageManager.cmake)

if (CMAKE_BUILD_TYPE STREQUAL "Coverage")
	include(CodeCoverage)
endif()

###############
### TARGETS ###
###############

if(${BUILD_SOURCE})
	set(PROJECT_LIB_NAME projectlib)
	set(PROJECT_LIB_DIR ${SOURCE_DIR}/${PROJECT_LIB_NAME})
	add_subdirectory(${PROJECT_LIB_DIR}/src)

	set(PROJECT_CLI_NAME projectcli)
	set(PROJECT_CLI_DIR ${SOURCE_DIR}/${PROJECT_CLI_NAME})
	add_subdirectory(${PROJECT_CLI_DIR})

	set(PROJECT_WX_NAME projectwx)
	option(BUILD_PROJECTWX "Build ${PROJECT_WX_NAME}" ON)
	set(PROJECT_WX_DIR ${SOURCE_DIR}/${PROJECT_WX_NAME})
	if(BUILD_PROJECTWX)
		add_subdirectory(${PROJECT_WX_DIR}/src)
	endif()
endif()

#############
### CTEST ###
#############

enable_testing()
include (CTest)

if(BUILD_SOURCE AND BUILD_TESTING)
	add_test(NAME Runs COMMAND $<TARGET_FILE:${PROJECT_CLI_NAME}>)
	add_test(NAME Runs-v COMMAND $<TARGET_FILE:${PROJECT_CLI_NAME}> -v)
	add_test(NAME Runs-h COMMAND $<TARGET_FILE:${PROJECT_CLI_NAME}> -h)
	add_test(NAME Runs-invalid COMMAND $<TARGET_FILE:${PROJECT_CLI_NAME}> --invalid)
	set_tests_properties(Runs-invalid PROPERTIES WILL_FAIL TRUE)
	include(cmake/memcheck.cmake)
	add_subdirectory(${PROJECT_LIB_DIR}/test)
endif()

#############
### CPACK ###
#############

if(${BUILD_SOURCE})
	install(TARGETS ${PROJECT_CLI_NAME} DESTINATION bin)
	if(BUILD_PROJECTWX)
		install(TARGETS ${PROJECT_WX_NAME} DESTINATION bin)
	endif()
	install(DIRECTORY "${ASSETS_DIR}/images" DESTINATION ".")
	include(cmake/cpack_module.cmake)
endif()
