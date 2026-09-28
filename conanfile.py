# conanfile.py
#
# Conan 2 recipe, mirroring vcpkg.json's dependencies (wxWidgets, GTest).
# See cmake/PackageManager.cmake for how this gets selected and consumed.
#
# 2026-09-27: replaced conanfile.txt as part of the Conan 2 first-class
# backend work (issue #152). The manifest format needed two things a .txt
# cannot express:
#
#   - Options `gui` and `tests` let CLI-only legs (e.g. the macOS GCC
#     BUILD_PROJECTWX=OFF/BUILD_TESTING=OFF matrix entries) resolve an empty
#     dependency graph instead of compiling wxWidgets it will never link.
#   - A recipe layout() keeps the generated CMakeDeps/CMakeToolchain files
#     and the CMake binary directory in the same place as before
#     (cmake_layout), so `conan install . --output-folder=...` keeps
#     producing <output>/build/<BuildType>/{generators/,CPackConfig.cmake,...}
#     and the `conan-release` / `conan-debug` CMake presets keep working.
#
# Versions are PINNED (not ranges) because releases must be reproducible:
# a floating range lets ConanCenter publish a new revision and silently
# change what a "same source" release links against. Lockfiles under
# conan/locks/ pin the full transitive graph per profile; bump versions here
# deliberately, then regenerate the locks (see docs, "Maintenance").
#
# compiler.cppstd: set per-profile to gnu17 (this package's profiles, e.g.
# conan/profiles/linux-gcc-x86_64). That value matches ConanCenter's
# prebuilt Linux binaries (so gtest and the dependency stack download rather
# than build) and satisfies gtest's recipe, which errors with "The
# compiler.cppstd is not defined" when it is absent. Because CMakeToolchain
# then injects `set(CMAKE_CXX_STANDARD 17)` into conan_toolchain.cmake as a
# NORMAL variable -- which would shadow this project's own
# `set(CMAKE_CXX_STANDARD 20 CACHE ...)` -- every profile also sets
# `tools.cmake.cmaketoolchain:extra_variables=CMAKE_CXX_STANDARD=20`, which
# CMakeToolchain emits after the standard block so 20 wins.
#
# If `conan install` reports a recipe as not found, check that your Conan 2
# install's default remote points at ConanCenter's Conan-2-specific index
# (center2.conan.io) rather than the legacy Conan-1-only one -- ConanCenter
# split the two in 2025. `conan remote list` shows what's currently
# configured.

from conan import ConanFile
from conan.tools.cmake import cmake_layout


class ProjectRecipe(ConanFile):
    name = "cpp-project-template"
    version = "0.0.1.0"

    settings = "os", "compiler", "build_type", "arch"
    options = {
        "gui": [True, False],
        "tests": [True, False],
    }
    default_options = {
        "gui": True,
        "tests": True,
    }

    generators = "CMakeDeps", "CMakeToolchain"

    def requirements(self):
        if self.options.gui:
            self.requires("wxwidgets/3.2.11")
        if self.options.tests:
            self.requires("gtest/1.17.0")

    def layout(self):
        cmake_layout(self)
