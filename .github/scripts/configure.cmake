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
set(extra_config_args)
if (NOT "$ENV{BUILD_PROJECTWX}" STREQUAL "")
	list(APPEND extra_config_args "-DBUILD_PROJECTWX:BOOL=$ENV{BUILD_PROJECTWX}")
endif()
if (NOT "$ENV{BUILD_TESTING}" STREQUAL "")
	list(APPEND extra_config_args "-DBUILD_TESTING:BOOL=$ENV{BUILD_TESTING}")
endif()
# Release identity (CORE-10): both release pipelines resolve the version from
# the git tag once and export CPP_PROJECT_TEMPLATE_VERSION before configure.
# Every generated artifact reads it (version.rc, template.desktop, config.h,
# CPACK_PACKAGE_VERSION -> DEB/RPM Version:). Before this line GitHub's
# packaging legs configured the 0.0.1.0 placeholder instead, which is how a
# DEB named ..._0.0.9_....deb ended up declaring "Version: 0.0.1".
if (NOT "$ENV{CPP_PROJECT_TEMPLATE_VERSION}" STREQUAL "")
	list(APPEND extra_config_args "-D CPP_PROJECT_TEMPLATE_VERSION=$ENV{CPP_PROJECT_TEMPLATE_VERSION}")
endif()
if ("$ENV{USE_VCPKG}" STREQUAL "OFF")
	list(APPEND extra_config_args "-D PACKAGE_MANAGER=system")
endif()
if ("$ENV{RUNNER_OS}" STREQUAL "Linux" AND "$ENV{CC}" STREQUAL "gcc" AND "$ENV{BUILD_TYPE}" STREQUAL "Debug")
	set(actual_build_type "Coverage")
endif()

set(package_toolchain_arg "")
if (NOT "$ENV{PACKAGE_TOOLCHAIN}" STREQUAL "")
	set(package_toolchain_arg "-D")	
endif()

if ("$ENV{RUNNER_OS}" STREQUAL "macOS")
	if ("$ENV{PACKAGE_TOOLCHAIN}" STREQUAL "apple-clang")
		set(ENV{CC} "/usr/bin/clang")
		set(ENV{CXX} "/usr/bin/clang++")
	elseif ("$ENV{PACKAGE_TOOLCHAIN}" STREQUAL "llvm")
		execute_process(
			COMMAND brew --prefix llvm
			OUTPUT_VARIABLE llvm_prefix
			OUTPUT_STRIP_TRAILING_WHITESPACE
			RESULT_VARIABLE llvm_prefix_result
		)
		if (NOT llvm_prefix_result EQUAL 0 OR NOT EXISTS "${llvm_prefix}/bin/clang++")
			message(FATAL_ERROR "Homebrew LLVM installation was not found")
		endif()
		set(ENV{CC} "${llvm_prefix}/bin/clang")
		set(ENV{CXX} "${llvm_prefix}/bin/clang++")
	elseif ("$ENV{PACKAGE_TOOLCHAIN}" STREQUAL "gcc")
		execute_process(
			COMMAND brew --prefix gcc
			OUTPUT_VARIABLE gcc_prefix
			OUTPUT_STRIP_TRAILING_WHITESPACE
			RESULT_VARIABLE gcc_prefix_result
		)
		if (NOT gcc_prefix_result EQUAL 0)
			message(FATAL_ERROR "Homebrew GCC installation was not found")
		endif()
		file(GLOB gcc_bins "${gcc_prefix}/bin/gcc-[0-9]*")
		file(GLOB gxx_bins "${gcc_prefix}/bin/g++-[0-9]*")
		list(SORT gcc_bins COMPARE NATURAL ORDER DESCENDING)
		list(SORT gxx_bins COMPARE NATURAL ORDER DESCENDING)
		if (NOT gcc_bins OR NOT gxx_bins)
			message(FATAL_ERROR "Versioned Homebrew GCC binaries were not found")
		endif()
		list(GET gcc_bins 0 gcc_bin)
		list(GET gxx_bins 0 gxx_bin)
		set(ENV{CC} "${gcc_bin}")
		set(ENV{CXX} "${gxx_bin}")
	endif()
endif()

if ("$ENV{RUNNER_OS}" STREQUAL "macOS" AND "$ENV{PACKAGE_TOOLCHAIN}" STREQUAL "llvm")
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
			${extra_config_args}
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
			${extra_config_args}
			${llvm_archive_tool_args}
			--fresh
		RESULT_VARIABLE result
	)
endif()

if (NOT result EQUAL 0)
	message(FATAL_ERROR "CMake configure failed with exit status ${result}")
endif()