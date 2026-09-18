# Configure the project from the CI environment.

if ("$ENV{RUNNER_OS}" STREQUAL "Windows" AND NOT "x$ENV{ENVIRONMENT_SCRIPT}" STREQUAL "x")
	execute_process(
		COMMAND "$ENV{ENVIRONMENT_SCRIPT}" && set
		OUTPUT_FILE environment_script_output.txt
		RESULT_VARIABLE env_result
	)
	if (NOT env_result EQUAL 0)
		message(FATAL_ERROR "Failed to initialize the Windows compiler environment")
	endif()
	file(STRINGS environment_script_output.txt output_lines)
	foreach(line IN LISTS output_lines)
		if (line MATCHES "^([a-zA-Z0-9_-]+)=(.*)$")
			set(ENV{${CMAKE_MATCH_1}} "${CMAKE_MATCH_2}")
		endif()
	endforeach()
endif()

set(path_separator ":")
if ("$ENV{RUNNER_OS}" STREQUAL "Windows")
	set(path_separator ";")
endif()
set(ENV{PATH} "$ENV{GITHUB_WORKSPACE}${path_separator}$ENV{PATH}")

set(actual_build_type "$ENV{BUILD_TYPE}")
if (actual_build_type STREQUAL "")
	set(actual_build_type "Release")
endif()
if ("$ENV{RUNNER_OS}" STREQUAL "Linux" AND "$ENV{CC}" STREQUAL "gcc" AND "$ENV{BUILD_TYPE}" STREQUAL "Debug")
	set(actual_build_type "Coverage")
endif()

set(package_toolchain_arg "")
if (NOT "$ENV{PACKAGE_TOOLCHAIN}" STREQUAL "")
	set(package_toolchain_arg "-D")	
endif()

if ("$ENV{RUNNER_OS}" STREQUAL "Linux" AND NOT "$ENV{ANDROID_ABI}" STREQUAL "")
	file(TO_CMAKE_PATH "$ENV{ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake" android_toolchain_file)
	if (NOT EXISTS "${android_toolchain_file}")
		message(FATAL_ERROR "Android NDK CMake toolchain not found: ${android_toolchain_file}")
	endif()
	if ("$ENV{BUILD_PROJECTWX}" STREQUAL "")
		set(android_build_projectwx "OFF")
	else()
		set(android_build_projectwx "$ENV{BUILD_PROJECTWX}")
	endif()
	if ("$ENV{BUILD_TESTING}" STREQUAL "")
		set(android_build_testing "OFF")
	else()
		set(android_build_testing "$ENV{BUILD_TESTING}")
	endif()
	execute_process(
		COMMAND cmake
			-S .
			-B build
			-D CMAKE_BUILD_TYPE=${actual_build_type}
			-G "Ninja"
			-D CMAKE_MAKE_PROGRAM=ninja
			-D CMAKE_C_COMPILER_LAUNCHER=ccache
			-D CMAKE_CXX_COMPILER_LAUNCHER=ccache
			-D CMAKE_TOOLCHAIN_FILE=${android_toolchain_file}
			-D ANDROID_ABI=$ENV{ANDROID_ABI}
			-D ANDROID_PLATFORM=$ENV{ANDROID_PLATFORM}
			-D BUILD_PROJECTWX=${android_build_projectwx}
			-D BUILD_TESTING=${android_build_testing}
			-D PACKAGE_TOOLCHAIN=android
			--fresh
		RESULT_VARIABLE result
	)
elseif ("$ENV{RUNNER_OS}" STREQUAL "macOS" AND "$ENV{PACKAGE_TOOLCHAIN}" STREQUAL "llvm")
	set(llvm_archive_tool_args
		-D CMAKE_AR=/usr/bin/ar
		-D CMAKE_RANLIB=/usr/bin/ranlib
	)
else()
	set(llvm_archive_tool_args)
endif()

if ("$ENV{RUNNER_OS}" STREQUAL "Windows" AND NOT "$ENV{USE_VCPKG}" STREQUAL "OFF")
	file(TO_CMAKE_PATH "$ENV{GITHUB_WORKSPACE}/vcpkg/scripts/buildsystems/vcpkg.cmake" toolchain_file)
	set(llvm_x86_target_args)
	if ("$ENV{VCPKG_TRIPLET}" STREQUAL "x86-win-llvm")
		list(APPEND llvm_x86_target_args
			-D CMAKE_C_FLAGS_INIT=/clang:--target=i686-pc-windows-msvc
			-D CMAKE_CXX_FLAGS_INIT=/clang:--target=i686-pc-windows-msvc
		)
	endif()
	set(vcpkg_host_triplet_arg "")
	if (NOT "$ENV{VCPKG_HOST_TRIPLET}" STREQUAL "")
		set(vcpkg_host_triplet_arg -D VCPKG_HOST_TRIPLET=$ENV{VCPKG_HOST_TRIPLET})
	else()
		set(vcpkg_host_triplet_arg -D VCPKG_HOST_TRIPLET=x64-windows)
	endif()
	execute_process(
		COMMAND cmake
			-S .
			-B build
			-D CMAKE_BUILD_TYPE=${actual_build_type}
			-G "Ninja"
			-D CMAKE_MAKE_PROGRAM=ninja
			-D CMAKE_C_COMPILER_LAUNCHER=ccache
			-D CMAKE_CXX_COMPILER_LAUNCHER=ccache
			-D CMAKE_TOOLCHAIN_FILE=${toolchain_file}
			-D VCPKG_TARGET_TRIPLET=$ENV{VCPKG_TRIPLET}
			${vcpkg_host_triplet_arg}
			-D VCPKG_MANIFEST_MODE=OFF
			-D PACKAGE_TOOLCHAIN=$ENV{PACKAGE_TOOLCHAIN}
			${llvm_x86_target_args}
			${llvm_archive_tool_args}
			--fresh
		RESULT_VARIABLE result
	)
else()
	execute_process(
		COMMAND cmake
			-S .
			-B build
			-D CMAKE_BUILD_TYPE=${actual_build_type}
			-G "Ninja"
			-D CMAKE_MAKE_PROGRAM=ninja
			-D CMAKE_C_COMPILER_LAUNCHER=ccache
			-D CMAKE_CXX_COMPILER_LAUNCHER=ccache
			-D PACKAGE_TOOLCHAIN=$ENV{PACKAGE_TOOLCHAIN}
			--fresh
		RESULT_VARIABLE result
	)
endif()

if (NOT result EQUAL 0)
	message(FATAL_ERROR "CMake configure failed with exit status ${result}")
endif()