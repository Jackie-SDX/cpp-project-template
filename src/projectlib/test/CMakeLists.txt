##############
# GoogleTest #
##############

find_package(GTest REQUIRED)

file(GLOB TEST_LIB_FILES "*.cpp")

add_executable("${PROJECT_LIB_NAME}_gtest" ${TEST_LIB_FILES})

target_include_directories("${PROJECT_LIB_NAME}_gtest" PUBLIC
	${GTEST_INCLUDE_DIRS}
	"${PROJECT_LIB_DIR}/src")

# 1. Optionally link `GTest::gtest_main` to generate a default
# main function for us.
# 2. May need to link with -pthread on some operating systems
# (tested with Raspbian). See: https://stackoverflow.com/a/21116684/3049315
target_link_libraries("${PROJECT_LIB_NAME}_gtest" PRIVATE
	${GTEST_LIBRARIES} -pthread)

if (MINGW)
	target_link_libraries("${PROJECT_LIB_NAME}_gtest" PRIVATE
		$<$<CONFIG:Release>:-static-libgcc -static-libstdc++ -static>
	)
elseif (MSVC AND NOT "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
	# Match the static Windows vcpkg triplets used by CI. Skipped under
	# clang-cl (CMAKE_CXX_COMPILER_ID "Clang" with MSVC-compatible syntax):
	# the x64-win-llvm/x86-win-llvm triplets chainload their own toolchain,
	# which sets a dynamic-CRT default instead -- see the
	# CMAKE_MSVC_RUNTIME_LIBRARY_DEFAULT comment in the top-level
	# CMakeLists.txt. Forcing static here too would mismatch that and break
	# the link.
	set_property(TARGET "${PROJECT_LIB_NAME}_gtest" PROPERTY
		MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
	target_link_options("${PROJECT_LIB_NAME}_gtest" PUBLIC
		$<$<CONFIG:Release>:/INCREMENTAL:NO /NODEFAULTLIB:MSVCRT>
	)
endif()

# Discover tests in the target environment so runtime DLLs copied by vcpkg's
# z-applocal step are available. A longer timeout also covers Windows LLVM
# debug startup overhead.
include(GoogleTest)
gtest_discover_tests("${PROJECT_LIB_NAME}_gtest"
	DISCOVERY_MODE PRE_TEST
	DISCOVERY_TIMEOUT 60
)
