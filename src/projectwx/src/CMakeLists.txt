### DEPENDENCIES

# https://docs.wxwidgets.org/trunk/overview_cmake.html
# https://wiki.wxwidgets.org/CMake
# Need to link against adv because using wxSplashScreen
# https://forums.wxwidgets.org/viewtopic.php?t=31482
# https://docs.wxwidgets.org/2.8/wx_librarieslist.html

if (WIN32 AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(ARM64|aarch64)$")
	find_package(wxWidgets CONFIG REQUIRED)
else()
	find_package(wxWidgets REQUIRED
		COMPONENTS
		core
		base
		adv)

	# Bring the headers into the project
	include(${wxWidgets_USE_FILE})
endif()

file(GLOB SRC_FILES "*.cpp")

# Version information on windows
if (WIN32)
	set(ORIGINAL_FILE_NAME "${PROJECT_WX_NAME}.exe")
	configure_file("${PACKAGING_DIR}/windows/version.rc.in" "${PROJECT_BINARY_DIR}/${PROJECT_WX_NAME}_version.rc")
endif()

# macOS application bundle (CORE-4). These MACOSX_BUNDLE_* variables are
# consumed when add_executable() runs below, so they must be set here, in the
# same directory scope as the target. The bundle identifier is derived from
# the repository owner (GitHub organization Jackie-SDX, reversed to reverse
# DNS) rather than the upstream fork it was copied from, so consumers see a
# stable, project-owned identity.
if (APPLE)
	string(TOLOWER "${ORGANIZATION}" _wx_org_id)
	string(REPLACE "-" "" _wx_org_id "${_wx_org_id}")
	string(TOLOWER "${PROJECT_NAME}" _wx_project_id)
	set(MACOSX_BUNDLE_BUNDLE_NAME "${PROJECT_WX_NAME}")
	set(MACOSX_BUNDLE_GUI_IDENTIFIER "com.github.${_wx_org_id}.${_wx_project_id}")
	set(MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}")
	set(MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}")
	set(MACOSX_BUNDLE_LONG_VERSION_STRING "${PROJECT_VERSION}")
	set(MACOSX_BUNDLE_INFO_STRING "${PROJECT_WX_NAME} ${PROJECT_VERSION} - ${PROJECT_DESCRIPTION}")
	set(MACOSX_BUNDLE_ICON_FILE "${PROJECT_WX_NAME}.icns")
	set(MACOSX_BUNDLE_COPYRIGHT "${CPACK_PACKAGE_COPYRIGHT}")
	set(_wx_bundle_keyword MACOSX_BUNDLE)
	set_source_files_properties("${PACKAGING_DIR}/apple/icon.icns"
		PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
	set(_wx_icon_source "${PACKAGING_DIR}/apple/icon.icns")
endif()

add_executable(${PROJECT_WX_NAME} ${_wx_bundle_keyword} WIN32 ${SRC_FILES}
	${_wx_icon_source}
	$<$<PLATFORM_ID:Windows>:${PACKAGING_DIR}/windows/icon.rc>
	$<$<PLATFORM_ID:Windows>:${PROJECT_BINARY_DIR}/${PROJECT_WX_NAME}_version.rc>)

target_compile_definitions(${PROJECT_WX_NAME} PUBLIC
	UNICODE _UNICODE wxUSE_DPI_AWARE_MANIFEST=2
)

# For including config.h and version.rc
# See: https://cmake.org/cmake/help/latest/guide/tutorial/A%20Basic%20Starting%20Point.html
target_include_directories(${PROJECT_WX_NAME} PUBLIC "${PROJECT_BINARY_DIR}")

target_include_directories(${PROJECT_WX_NAME} PUBLIC "${PROJECT_LIB_DIR}/src")
target_link_libraries(${PROJECT_WX_NAME} PUBLIC ${PROJECT_LIB_NAME})

if (WIN32 AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(ARM64|aarch64)$")
	target_link_libraries(${PROJECT_WX_NAME} PUBLIC
		wx::core
		wx::base
		wx::adv)
else()
	target_link_libraries(${PROJECT_WX_NAME} PUBLIC ${wxWidgets_LIBRARIES})
endif()

# Static compile on Windows for Release - inspired by: https://stackoverflow.com/a/24671474/3049315
# only makes sense for single-target generators, like Makefiles, see: https://stackoverflow.com/a/59314670/3049315
if (MINGW AND NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
	target_link_libraries(${PROJECT_WX_NAME} PRIVATE
		$<$<CONFIG:Release>:-static-libgcc -static-libstdc++ -static>
	)
	# https://stackoverflow.com/a/51602330/3049315
	target_link_libraries(${PROJECT_WX_NAME} PRIVATE
		$<$<CONFIG:Release>:-static gcc stdc++ winpthread -dynamic>
	)
elseif (MSVC)
	# MT vs MD vs MTd vs MDd https://social.msdn.microsoft.com/Forums/en-US/9474efb9-49cd-46e1-8935-ee2bebe95203/difference-in-mt-and-md-run-time-lib-setting?forum=vcgeneral
	# Might have to use MDd with wxWidgets because: https://forums.wxwidgets.org/viewtopic.php?t=47650
	set_property(TARGET ${PROJECT_WX_NAME} PROPERTY
		MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
		#MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")

	target_link_options(${PROJECT_WX_NAME} PUBLIC
		$<$<CONFIG:Release>:/INCREMENTAL:NO /NODEFAULTLIB:MSVCRT>
	)
endif()

# Bring project files to the executable's directory
file(COPY "${ASSETS_DIR}/images" DESTINATION "${PROJECT_BINARY_DIR}")
