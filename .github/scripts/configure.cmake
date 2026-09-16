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

if ("$ENV{RUNNER_OS}" STREQUAL "Windows")
	file(TO_CMAKE_PATH "$ENV{GITHUB_WORKSPACE}/vcpkg/scripts/buildsystems/vcpkg.cmake" toolchain_file)
	set(llvm_x86_target_args)
	if ("$ENV{VCPKG_TRIPLET}" STREQUAL "x86-win-llvm")
		# The upstream LLVM overlay triplet chainloads a shared toolchain, but
		# CMake's initial clang-cl compiler probe on current Windows runners can
		# still select the host x64 linker target. Force the documented clang
		# target triple for this 32-bit Windows configuration at compiler-init time.
		list(APPEND llvm_x86_target_args
			-D CMAKE_C_FLAGS_INIT=/clang:-target=i686-pc-windows-msvc
			-D CMAKE_CXX_FLAGS_INIT=/clang:-target=i686-pc-windows-msvc
		)
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
			-D VCPKG_HOST_TRIPLET=$ENV{VCPKG_TRIPLET}
			-D VCPKG_MANIFEST_MODE=OFF
			-D PACKAGE_TOOLCHAIN=$ENV{PACKAGE_TOOLCHAIN}
			${llvm_x86_target_args}
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