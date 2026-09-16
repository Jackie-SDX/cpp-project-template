# CPack configuration shared by GitLab and GitHub release pipelines.
# Package identity is intentionally explicit: OS + toolchain + architecture.

include(InstallRequiredSystemLibraries)

set(CPACK_PACKAGE_NAME ${PROJECT_NAME})
set(CPACK_PACKAGE_DESCRIPTION ${PROJECT_DESCRIPTION})
set(CPACK_PACKAGE_VERSION_MAJOR ${CMAKE_PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${CMAKE_PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${CMAKE_PROJECT_VERSION_PATCH})
set(CPACK_PACKAGE_ICON "${PACKAGING_DIR}/apple/icon.png")
set(CPACK_OUTPUT_FILE_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/package")
set(CPACK_PACKAGE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})

string(TOLOWER "${CMAKE_SYSTEM_NAME}" _sys)
string(TOLOWER "${PROJECT_NAME}" _project_lower)

# Determine the target architecture. Visual Studio exposes the target through
# CMAKE_VS_PLATFORM_NAME; Ninja/vcvars32 does not, so pointer size is used as
# the final correction for a 32-bit target on a 64-bit Windows host.
if(MSVC AND CMAKE_VS_PLATFORM_NAME)
    set(_arch_raw "${CMAKE_VS_PLATFORM_NAME}")
elseif(CMAKE_SYSTEM_PROCESSOR)
    set(_arch_raw "${CMAKE_SYSTEM_PROCESSOR}")
else()
    set(_arch_raw "unknown")
endif()
string(TOLOWER "${_arch_raw}" _arch)
if(_arch MATCHES "^(x64|amd64|x86_64)$")
    set(_arch "x86_64")
elseif(_arch MATCHES "^(win32|x86|i[3-6]86)$")
    set(_arch "i686")
elseif(_arch MATCHES "^(arm64|aarch64)$")
    set(_arch "arm64")
endif()
if(_arch STREQUAL "x86_64" AND DEFINED CMAKE_SIZEOF_VOID_P AND CMAKE_SIZEOF_VOID_P EQUAL 4)
    set(_arch "i686")
endif()

set(_arch_display "${_arch}")
if(_arch_display STREQUAL "i686")
    set(_arch_display "x86")
endif()

# PACKAGE_TOOLCHAIN is supplied by the non-default toolchain jobs. MSVC is the
# default label so every release asset has a complete identity even when the
# compiler is selected through vcvars rather than an explicit CMake variable.
set(_toolchain_suffix "msvc")
if(DEFINED PACKAGE_TOOLCHAIN AND NOT PACKAGE_TOOLCHAIN STREQUAL "")
    set(_toolchain_suffix "${PACKAGE_TOOLCHAIN}")
endif()

set(CPACK_PACKAGE_FILE_NAME "${_project_lower}_${PROJECT_VERSION}_${_sys}-${_toolchain_suffix}-${_arch_display}")
set(CPACK_SOURCE_PACKAGE_FILE_NAME "${_project_lower}_${PROJECT_VERSION}_source")

message(STATUS "-- CPack package target: ${_sys}-${_toolchain_suffix}-${_arch_display}")

file(READ ${CMAKE_CURRENT_LIST_DIR}/.cpack_ignore _cpack_ignore)
string(REGEX REPLACE "\n" ";" _cpack_ignore ${_cpack_ignore})
set(CPACK_SOURCE_IGNORE_FILES "${_cpack_ignore}")

if(BUILD_PROJECTWX)
    set(CPACK_PACKAGE_EXECUTABLES "${PROJECT_WX_NAME}" "${PROJECT_WX_NAME}")
    set(CPACK_CREATE_DESKTOP_LINKS "${PROJECT_WX_NAME}")
endif()

if(WIN32)
    # CPack serializes these values into build/CPackConfig.cmake. Always use
    # forward slashes here: raw Windows backslashes become CMake escape
    # sequences (for example \p) when the generated config is parsed.
    file(TO_CMAKE_PATH "${PACKAGING_DIR}/windows/icon.ico" _nsis_icon)
    file(TO_CMAKE_PATH "${PACKAGING_DIR}/windows/nsis/icon.bmp" _nsis_bitmap)
    file(TO_CMAKE_PATH "${PACKAGING_DIR}/windows/nsis/welcomefinishpage.bmp" _nsis_welcome_bitmap)
    file(TO_CMAKE_PATH "${PACKAGING_DIR}/windows/wix/banner.bmp" _wix_banner)
    file(TO_CMAKE_PATH "${PACKAGING_DIR}/windows/wix/dialog.bmp" _wix_dialog)

    set(CPACK_NSIS_MANIFEST_DPI_AWARE ON)
    set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
    set(CPACK_NSIS_MODIFY_PATH ON)
    set(CPACK_NSIS_HELP_LINK ${CMAKE_PROJECT_HOMEPAGE_URL})
    set(CPACK_NSIS_URL_INFO_ABOUT ${CMAKE_PROJECT_HOMEPAGE_URL})
    set(CPACK_NSIS_MENU_LINKS
        "share/docs/${PROJECT_NAME}/README.md" "README"
        "${CMAKE_PROJECT_HOMEPAGE_URL}" "${PROJECT_NAME} Web Site")
    set(CPACK_NSIS_MUI_ICON "${_nsis_icon}")
    set(CPACK_NSIS_MUI_UNIICON "${_nsis_icon}")
    set(CPACK_NSIS_INSTALLED_ICON_NAME "bin/${PROJECT_CLI_NAME}.exe")
    set(CPACK_PACKAGE_ICON "${_nsis_bitmap}")
    set(CPACK_NSIS_MUI_WELCOMEFINISHPAGE_BITMAP "${_nsis_welcome_bitmap}")
    set(CPACK_NSIS_MUI_UNWELCOMEFINISHPAGE_BITMAP "${_nsis_welcome_bitmap}")
    if(BUILD_PROJECTWX)
        set(CPACK_NSIS_MUI_FINISHPAGE_RUN "${PROJECT_WX_NAME}")
    endif()

    file(READ ${CPACK_RESOURCE_FILE_LICENSE} LICENSE NEWLINE_CONSUME ENCODING "UTF-8")
    string(REGEX REPLACE "\n\n" "#CMAKE_DOUBLE_NEWLINE#" LICENSE "${LICENSE}")
    string(REGEX REPLACE "\n" " " LICENSE "${LICENSE}")
    string(REGEX REPLACE "#CMAKE_DOUBLE_NEWLINE#" "\n\n" LICENSE "${LICENSE}")
    string(REGEX REPLACE "  +" " " LICENSE "${LICENSE}")
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/License.txt" "${LICENSE}")
    execute_process(COMMAND cscript "${CMAKE_CURRENT_SOURCE_DIR}/cmake/utf8_to_utf8bom.vbs" "${CMAKE_CURRENT_BINARY_DIR}/License.txt" "${CMAKE_CURRENT_BINARY_DIR}/License_utf8bom.txt")
    if(NOT EXISTS "${CMAKE_CURRENT_BINARY_DIR}/License_utf8bom.txt")
        message(FATAL_ERROR "UTF-8 BOM license conversion failed")
    endif()
    file(RENAME "${CMAKE_CURRENT_BINARY_DIR}/License_utf8bom.txt" "${CMAKE_CURRENT_BINARY_DIR}/License.txt")
    set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_BINARY_DIR}/License.txt")

    if(${PROJECT_LANGUAGE_NEUTRAL} EQUAL 0)
        set(VER_VERSION_LANG "1033")
    else()
        set(VER_VERSION_LANG "0")
    endif()
    set(CPACK_NSIS_DEFINES
        "${CPACK_NSIS_DEFINES}
        VIProductVersion ${CPACK_PACKAGE_VERSION_MAJOR}.${CPACK_PACKAGE_VERSION_MINOR}.${CPACK_PACKAGE_VERSION_PATCH}.${CMAKE_PROJECT_VERSION_TWEAK}
        VIFileVersion ${CPACK_PACKAGE_VERSION_MAJOR}.${CPACK_PACKAGE_VERSION_MINOR}.${CPACK_PACKAGE_VERSION_PATCH}.${CMAKE_PROJECT_VERSION_TWEAK}
        VIAddVersionKey /LANG=${VER_VERSION_LANG} \"CompanyName\" \"${CPACK_PACKAGE_VENDOR}\"
        VIAddVersionKey /LANG=${VER_VERSION_LANG} \"FileDescription\" \"${PROJECT_DESCRIPTION} Installer\"
        VIAddVersionKey /LANG=${VER_VERSION_LANG} \"FileVersion\" \"v${CPACK_PACKAGE_VERSION_MAJOR}.${CPACK_PACKAGE_VERSION_MINOR}.${CPACK_PACKAGE_VERSION_PATCH}.${CMAKE_PROJECT_VERSION_TWEAK}\"
        VIAddVersionKey /LANG=${VER_VERSION_LANG} \"InternalName\" \"${CPACK_PACKAGE_NAME} Installer\"
        VIAddVersionKey /LANG=${VER_VERSION_LANG} \"LegalCopyright\" \"${CPACK_PACKAGE_COPYRIGHT}\"
        VIAddVersionKey /LANG=${VER_VERSION_LANG} \"OriginalFilename\" \"${CPACK_PACKAGE_FILE_NAME}.exe\"
        VIAddVersionKey /LANG=${VER_VERSION_LANG} \"ProductName\" \"${CPACK_PACKAGE_NAME}\"
        VIAddVersionKey /LANG=${VER_VERSION_LANG} \"ProductVersion\" \"v${CPACK_PACKAGE_VERSION_MAJOR}.${CPACK_PACKAGE_VERSION_MINOR}.${CPACK_PACKAGE_VERSION_PATCH}.${CMAKE_PROJECT_VERSION_TWEAK}\"
        VIAddVersionKey /LANG=${VER_VERSION_LANG} \"Comments\" \"${CPACK_PACKAGE_DESCRIPTION}\"")

    set(CPACK_WIX_PRODUCT_ICON "${_nsis_icon}")
    set(CPACK_WIX_UI_BANNER "${_wix_banner}")
    set(CPACK_WIX_UI_DIALOG "${_wix_dialog}")

elseif(APPLE)
    set(MACOSX_BUNDLE_BUNDLE_NAME ${CPACK_PACKAGE_NAME})
    set(MACOSX_BUNDLE_ICON_FILE "${PACKAGING_DIR}/apple/icon.icns")
    set_source_files_properties("${PACKAGING_DIR}/apple/icon.icns" PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
    set(CPACK_DMG_VOLUME_NAME "${PROJECT_NAME}")
    set(CPACK_DMG_BACKGROUND_IMAGE "${PACKAGING_DIR}/apple/icon.png")

elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    find_program(RPMBUILD_PATH rpmbuild)
    if(RPMBUILD_PATH)
        message(STATUS "Found rpmbuild: ${RPMBUILD_PATH}")
    endif()
    set(CPACK_DEBIAN_PACKAGE_DEPENDS "libc6 (>= 2.32), libstdc++6 (>= 12)")
    set(CPACK_RPM_PACKAGE_REQUIRES "glibc >= 2.32, libstdc++ >= 12")
    set(CPACK_RPM_PACKAGE_LICENSE "MIT")
    set(CPACK_RPM_PACKAGE_URL "${CMAKE_PROJECT_HOMEPAGE_URL}")

    if(BUILD_PROJECTWX)
        set(CPACK_DEBIAN_PACKAGE_DEPENDS "${CPACK_DEBIAN_PACKAGE_DEPENDS}, libwxgtk3.2-1 | libwxgtk3.2-dev")
        set(CPACK_RPM_PACKAGE_REQUIRES "${CPACK_RPM_PACKAGE_REQUIRES}, wxGTK3")
        configure_file("${PACKAGING_DIR}/linux/template.desktop.in" "${PROJECT_WX_NAME}.desktop")
        install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_WX_NAME}.desktop" DESTINATION share/applications/ PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ)
        install(FILES "${PACKAGING_DIR}/linux/icon_256x256.png" RENAME ${PROJECT_WX_NAME}.png DESTINATION "share/icons/hicolor/256x256/apps/" PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ)
    endif()

    install(FILES "${CPACK_RESOURCE_FILE_LICENSE}" DESTINATION "share/doc/${PROJECT_NAME}/" PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ RENAME copyright)
endif()

install(FILES ${CPACK_RESOURCE_FILE_README} ${CPACK_RESOURCE_FILE_LICENSE} DESTINATION share/docs/${PROJECT_NAME})
include(CPack)
