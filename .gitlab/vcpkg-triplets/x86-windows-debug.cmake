set(VCPKG_TARGET_ARCHITECTURE x86)
set(VCPKG_CRT_LINKAGE static)
set(VCPKG_LIBRARY_LINKAGE dynamic)
# Deliberately NOT setting VCPKG_BUILD_TYPE here; both debug and release
# artifacts are required for the multi-config dependency graph.
