# Windows runtime dependency closure (CORE-1).
#
# Adds a last-in-order install step that deploys and verifies the complete
# runtime DLL closure of the install tree (and therefore of every Windows
# package: ZIP, NSIS, MSI), and writes a JSON report used as CI evidence.
#
# Rejected alternatives (documented in Resolve-WindowsRuntimeDeps.ps1):
#   * file(GET_RUNTIME_DEPENDENCIES): needs objdump/dumpbin on PATH at install
#     time (unavailable on MSVC legs) and only follows CMake target-level
#     dependencies, which does not cover raw FindwxWidgets paths.
#   * X_VCPKG_APPLOCAL_DEPS_INSTALL: experimental, imported-target only.
if(NOT WIN32)
	return()
endif()
if(NOT BUILD_SOURCE)
	return()
endif()

# ---------------------------------------------------------------------------
# Architecture vocabulary must match cmake/cpack_module.cmake: x86_64|i686|arm64
# ---------------------------------------------------------------------------
set(_wrt_arch "x86_64")
if(CMAKE_SYSTEM_PROCESSOR)
	string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _wrt_proc)
	if(_wrt_proc MATCHES "^(win32|x86|i[3-6]86)$")
		set(_wrt_arch "i686")
	elseif(_wrt_proc MATCHES "^(arm64|aarch64)$")
		set(_wrt_arch "arm64")
	elseif(_wrt_proc MATCHES "^(x64|amd64|x86_64)$")
		set(_wrt_arch "x86_64")
	endif()
endif()
if(_wrt_arch STREQUAL "x86_64" AND DEFINED CMAKE_SIZEOF_VOID_P AND CMAKE_SIZEOF_VOID_P EQUAL 4)
	set(_wrt_arch "i686")
endif()
if(MSVC AND CMAKE_VS_PLATFORM_NAME)
	string(TOLOWER "${CMAKE_VS_PLATFORM_NAME}" _wrt_vs_arch)
	if(_wrt_vs_arch STREQUAL "x64")
		set(_wrt_arch "x86_64")
	elseif(_wrt_vs_arch MATCHES "^(x86|win32)$")
		set(_wrt_arch "i686")
	elseif(_wrt_vs_arch STREQUAL "arm64")
		set(_wrt_arch "arm64")
	endif()
endif()

# ---------------------------------------------------------------------------
# Search directories for runtime dependencies that must be bundled
# ---------------------------------------------------------------------------
set(_wrt_search_dirs "")

macro(_wrt_add_search_dir dir)
	if(EXISTS "${dir}")
		list(APPEND _wrt_search_dirs "${dir}")
	endif()
endmacro()

_wrt_add_search_dir("${PROJECT_BINARY_DIR}/bin")
_wrt_add_search_dir("${PROJECT_BINARY_DIR}/lib")

foreach(_p IN LISTS CMAKE_PREFIX_PATH)
	_wrt_add_search_dir("${_p}")
	_wrt_add_search_dir("${_p}/bin")
	_wrt_add_search_dir("${_p}/debug/bin")
endforeach()

if(DEFINED VCPKG_INSTALLED_DIR AND DEFINED VCPKG_TARGET_TRIPLET)
	_wrt_add_search_dir("${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/bin")
	_wrt_add_search_dir("${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/debug/bin")
endif()

foreach(_p IN LISTS CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES)
	_wrt_add_search_dir("${_p}")
endforeach()

# Directories of the MSVC runtime libraries selected by
# InstallRequiredSystemLibraries (included from cmake/cpack_module.cmake,
# which must therefore be included before this module).
foreach(_f IN LISTS CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS)
	get_filename_component(_dir "${_f}" DIRECTORY)
	_wrt_add_search_dir("${_dir}")
endforeach()

# MinGW/MSYS2 toolchain runtime DLLs (libstdc++-6.dll, libwinpthread-1.dll,
# libgcc_s_*.dll, ...) live in the compiler's bin directory. That directory
# is NOT part of CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES (which lists lib/ and
# lib/gcc/... only), so a MinGW leg could build wxWidgets from vcpkg yet
# fail the closure with "MISSING libstdc++-6.dll". The compiler's own bin
# directory plus the MSYS2 prefix dirs cover MINGW32/MINGW64/UCRT64/CLANG*
# environments.
if(CMAKE_CXX_COMPILER)
	get_filename_component(_wrt_cxx_bin "${CMAKE_CXX_COMPILER}" DIRECTORY)
	_wrt_add_search_dir("${_wrt_cxx_bin}")
endif()
if(DEFINED ENV{MINGW_PREFIX})
	_wrt_add_search_dir("$ENV{MINGW_PREFIX}/bin")
endif()
if(DEFINED ENV{MSYSTEM_PREFIX})
	_wrt_add_search_dir("$ENV{MSYSTEM_PREFIX}/bin")
endif()

if(_wrt_search_dirs)
	list(REMOVE_DUPLICATES _wrt_search_dirs)
endif()

set(WRT_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/cmake/windows/Resolve-WindowsRuntimeDeps.ps1")
set(WRT_REPORT "${CMAKE_CURRENT_BINARY_DIR}/windows-runtime-dependencies.json")
set(WRT_ARCH "${_wrt_arch}")

configure_file(
	"${CMAKE_CURRENT_SOURCE_DIR}/cmake/WindowsRuntimeDeps.cmake.in"
	"${CMAKE_CURRENT_BINARY_DIR}/WindowsRuntimeDeps.cmake"
	@ONLY
)

# Declared after every install(FILES/TARGETS/DIRECTORY) rule (including the
# ones inside cmake/cpack_module.cmake) so the closure step sees the finished
# tree, both for `cmake --install` and for CPack staging.
install(SCRIPT "${CMAKE_CURRENT_BINARY_DIR}/WindowsRuntimeDeps.cmake")

message(STATUS "-- Windows runtime closure step registered (arch: ${_wrt_arch})")
