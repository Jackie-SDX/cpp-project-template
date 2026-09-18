set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE static)
set(VCPKG_LIBRARY_LINKAGE dynamic)
# Deliberately NOT setting VCPKG_BUILD_TYPE here (unlike the -release triplet).
# zlib's real portfile.cmake passes OPTIONS_DEBUG -DSKIP_INSTALL_HEADERS=ON --
# it skips installing headers on the debug pass and expects the release pass
# to populate include/, which never runs in a debug-only build. That crashes
# with "file failed to open for reading: .../include/zconf.h". wxWidgets pulls
# in zlib transitively, and several of its other deps (libpng, tiff, pcre2,
# libjpeg-turbo, expat) likely use the same OPTIONS_DEBUG pattern, so this
# isn't a one-port problem -- debug-only restriction just isn't safe here.
# Confirmed against microsoft/vcpkg's actual zlib portfile.cmake, 2026-08-29.
