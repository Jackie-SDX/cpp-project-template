# Installation Guide

- Setup
  - Linux
    - [Arch Linux / Manjaro Linux](#arch-linux--manjaro-linux)
    - [Debian / Linux Mint / Ubuntu](#debian--linux-mint--ubuntu)
    - [RedHat / Fedora / CentOS](#redhat--fedora--centos)
  - [Windows](#windows)
    - [MSVC](#msvc)
    - [MinGW](#mingw)
    - [Dependencies](#dependencies)
      - [vcpkg](#vcpkg)
  - [macOS](#macos)
- [Package manager selection](#package-manager)
- [Compile](#compile)
  - [Linux & Mac](#linux--mac)
  - [Windows](#windows-compile)
- [Package](#package)
  - [Archive](#archive)
  - Windows
    - [NSIS](#NSIS)
    - [WiX](#WiX)
  - Ubuntu
    - [DEB](#deb)
    - [RPM](#rpm)
  - MacOS
    - [DMG](#dmg)
    - [ProductBuild](#productbuild)
- [Documentation](#documentation)

## Linux

<a id="arch-linux--manjaro-linux"></a>
### Arch Linux / Manjaro Linux

Build tools:

```sh
sudo pacman -Sy git gcc clang llvm cmake make ninja 
```

wxWidgets:

```sh
sudo pacman -Sy wxgtk3
```

Documentation:

```sh
sudo pacman -Sy doxygen python-sphinx python-breathe python-sphinx_rtd_theme
```

Static analysis:

```sh
sudo pacman -Sy cppcheck llvm
```

Debugging:

```sh
sudo pacman -Sy gdb lldb
```

Memory checker:

```sh
sudo pacman -Sy valgrind
```

CPack DEB:

```sh
sudo pacman -Sy dpkg
```

CPack RPM:

```sh
sudo pacman -Sy rpm-tools
```

GoogleTest:

```sh
sudo pacman -Sy gtest
```

Coverage:

```sh
sudo pacman -Sy lcov gcovr
```

<a id="debian--linux-mint--ubuntu"></a>
### Debian / Linux Mint / Ubuntu

Build tools:

```sh
sudo apt install git cmake make ninja-build build-essential clang llvm
```

wxWidgets:

```sh
sudo apt install libwxgtk3.2-dev
```

Documentation:

```sh
sudo apt install doxygen sphinx-common python3-breathe python3-sphinx-rtd-theme
```

Static analysis:

```sh
sudo apt install cppcheck clang-tidy
```

Formatting:

```sh
sudo apt install clang-format
```

Debugging:

```sh
sudo apt install gdb lldb
```

Memory checker:

```sh
sudo apt install valgrind
```

CPack DEB:

```sh
sudo apt install dpkg
```

CPack RPM:

```sh
sudo apt install rpm
```

GoogleTest:

```sh
sudo apt install libgtest-dev
```

Coverage:

```sh
sudo apt install lcov gcovr
```

<a id="redhat--fedora--centos"></a>
### RedHat / Fedora / CentOS

Build tools:

```sh
sudo yum -y install git cmake make ninja-build gcc gcc-c++ clang llvm
```

wxWidgets:

```sh
sudo yum -y install wxBase3 wxGTK3 wxGTK-devel
```

Documentation:

```sh
sudo yum -y install doxygen sphinx python3-breathe python3-sphinx_rtd_theme
```

Static analysis & Formatting:

```sh
sudo yum -y install cppcheck clang-tools-extra
```

Debugging:

```sh
sudo yum -y install gdb lldb
```

Memory checker:

```sh
sudo yum -y install valgrind
```

CPack DEB:

```sh
sudo yum -y install dpkg
```

CPack RPM:

```sh
sudo yum -y install rpm-build
```

GoogleTest:

```sh
sudo yum -y install gtest
```

Coverage:

```sh
sudo yum -y install lcov gcovr
```

<a id="windows"></a>
## Windows

<a id="msvc"></a>
### MSVC

Download and install [Visual Studio](https://www.visualstudio.com/).

In Visual Studio Installer, click "Modify" and install "Desktop development with C++".

<a id="mingw"></a>
### MinGW

Download latest [MinGW builds](https://github.com/niXman/mingw-builds-binaries/releases/).

Example:
- [Architecture: i686](https://github.com/niXman/mingw-builds-binaries/releases/download/12.2.0-rt_v10-rev2/i686-12.2.0-release-posix-dwarf-msvcrt-rt_v10-rev2.7z) - for compiling 32 bit programs
- [Architecture: x86_64](https://github.com/niXman/mingw-builds-binaries/releases/download/12.2.0-rt_v10-rev2/x86_64-12.2.0-release-posix-seh-msvcrt-rt_v10-rev2.7z) - for compiling 64 bit programs

Put the MinGW bin folder in the path for the intended architecture.

<a id="dependencies"></a>
### Dependencies

- [git](https://git-scm.com/)
- [CMake](https://cmake.org/download/)
- [Doxygen](https://www.doxygen.nl/download.html)
- Sphinx:
  - Get Python at the Windows Store, and run in an elevated command shell:
  - `pip install sphinx`
  - `pip install breathe`
  - `pip install sphinx_rtd_theme`
- [cppcheck](https://cppcheck.sourceforge.io/)
  - Add `C:\Program Files\Cppcheck` to the Path environment variable
- [LLVM](https://releases.llvm.org/download.html) (includes clang-tidy and clang-format). Tick option to add to PATH during installation.
- [OpenCppCoverage](https://github.com/OpenCppCoverage/OpenCppCoverage/releases/latest)
- [NSIS](https://nsis.sourceforge.io/Download)
- [WiX Toolset](https://wixtoolset.org/)
- Ninja:
  - Open an elevated command shell (cmd/powershell), and type: `choco install ninja`

<a id="wxwidgets"></a>
#### wxWidgets (manual install not recommended, prefer vcpkg)

1. Download Windows binaries from: https://www.wxwidgets.org/downloads

We need the **Header Files**, the **Development Files**, and the **Release DLLs** for the chosen compiler and architecture.

After extracting the files to a directory (e.g. `C:\wxwidgets`), we should end up with a file tree like this:

```
C:\wxwidgets
├───build
│   └───msw
├───include
│   ├───msvc
│   │   └───wx
│   └───wx
│       ├───android
│       ├───...
│       └───xrc
└───lib
    └───vc14x_x64_dll
        ├───mswu
        │   └───wx
        │       └───msw
        └───mswud
            └───wx
                └───msw
```

```sh
# https://stackoverflow.com/a/48947121/3049315
set wxWidgets_ROOT_DIR=C:\wxwidgets
set wxWidgets_LIB_DIR=C:\wxwidgets\lib\vc14x_x64_dll
cd <project_root>
mkdir build && cd build
cmake .. -DBUILD_TESTING=OFF
cmake --build . --config Release
```

Instructions at: https://docs.wxwidgets.org/stable/plat_msw_binaries.html

<a id="google-test"></a>
#### Google Test (manual install not recommended, prefer vcpkg)

Install Google Test:

```sh
cd C:
git clone https://github.com/google/googletest.git -b v1.13.0
cd googletest
mkdir build && cd build
cmake .. #-DBUILD_GMOCK=OFF
cmake --build . --config Debug
cmake --build . --config Release
```

```sh
cd <project_root>
# https://stackoverflow.com/a/32749652/3049315
cd <project_root>
mkdir build && cd build
cmake .. -DGTEST_ROOT:PATH="C:\googletest\googletest" -DGTEST_LIBRARY:PATH="C:\googletest\build\lib\Release\gtest.lib" -DGTEST_MAIN_LIBRARY:PATH="C:\googletest\build\lib\Release\gtest_main.lib" #-DBUILD_PROJECTWX=OFF
cmake --build . --config Release
```

<a id="vcpkg"></a>
#### vcpkg (recommended)

```sh
cd <project_root>

# Install vcpkg - A C++ package manager
# https://docs.microsoft.com/en-us/cpp/build/vcpkg?view=vs-2019
# https://devblogs.microsoft.com/cppblog/vcpkg-updates-static-linking-is-now-available/
git clone https://github.com/Microsoft/vcpkg
cd .\vcpkg
.\bootstrap-vcpkg.bat

# Search library example (optional, just to see if it's available)
.\vcpkg.exe search zlib

## Install libraries (x86 for 32-bit, x64 for 64-bit)
# wxWidgets with vcpkg: https://www.wxwidgets.org/blog/2019/01/wxwidgets-and-vcpkg/
#.\vcpkg.exe install wxwidgets:x86-windows
#.\vcpkg.exe install wxwidgets:x64-windows
#.\vcpkg.exe install wxwidgets:x64-windows-release

## With MSVC:
.\vcpkg.exe install wxwidgets:x64-windows-static
.\vcpkg.exe install gtest:x64-windows-static

## With MinGW:
.\vcpkg.exe install wxwidgets:x64-mingw-static
.\vcpkg.exe install gtest:x64-mingw-static

## With Clang:
git clone https://github.com/Neumann-A/my-vcpkg-triplets.git
.\vcpkg.exe install wxwidgets:x64-win-llvm-static-md-release --overlay-triplets=my-vcpkg-triplets
.\vcpkg.exe install gtest:x64-win-llvm-static-md-release  --overlay-triplets=my-vcpkg-triplets

# Make libraries available
.\vcpkg.exe integrate install

# Build project
cd ..
mkdir build && cd build

# Note: toolchain file must by specified with full path.

## With MSVC:
cmake .. -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_TOOLCHAIN_FILE=<project_root>/vcpkg/scripts/buildsystems/vcpkg.cmake -DVCPKG_TARGET_TRIPLET=x64-windows-static -DVCPKG_HOST_TRIPLET=x64-windows-static

## With MinGW:
cmake .. -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_TOOLCHAIN_FILE=<project_root>/vcpkg/scripts/buildsystems/vcpkg.cmake -DVCPKG_TARGET_TRIPLET=x64-mingw-static -DVCPKG_HOST_TRIPLET=x64-mingw-static

## With Clang:
cmake .. -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_TOOLCHAIN_FILE=<project_root>/vcpkg/scripts/buildsystems/vcpkg.cmake -DVCPKG_TARGET_TRIPLET=x64-win-llvm-static-md-release -DVCPKG_HOST_TRIPLET=x64-win-llvm-static-md-release -G "Ninja Multi-Config" -DCMAKE_CXX_COMPILER=clang++
#-DVCPKG_OVERLAY_TRIPLETS=vcpkg/my-vcpkg-triplets

# If your generator is a single-config generator like "Unix Makefiles" or "Ninja", then the build type is specified by the CMAKE_BUILD_TYPE variable, which can be set in the configure command by using -DCMAKE_BUILD_TYPE:STRING=Release. For multi-config generators like the Visual Studio generators and "Ninja Multi-Config", the config to build is specified in the build command using the --config argument argument like --config Release. A default value can be specified at configure time by setting the value of the CMAKE_DEFAULT_BUILD_TYPE variable, which will be used if the --config argument isn't passed to the build command.
# https://stackoverflow.com/a/74077157/3049315
cmake --build . --config Release
```

<a id="macos"></a>
## macOS

```sh
brew install wxwidgets googletest
```

<a id="package-manager"></a>
## Package manager selection (vcpkg / Conan 2)

wxWidgets and GoogleTest can come from two first-class, independently
selectable backends — **vcpkg** (the default) and **Conan 2** — plus a third
mode, `system`, that uses whatever the host provides. One CMake variable
selects between them: `PACKAGE_MANAGER` = `vcpkg` | `conan2` | `system`,
resolved in `cmake/PackageManager.cmake`.

* The two backends never share a build tree, generated dependency metadata,
  cache storage or CMake discovery: Conan provisions into `build/conan2/`,
  vcpkg/system configure into their own tree, and naming a manager that
  contradicts the toolchain file is a configure-time `FATAL_ERROR` rather
  than a late `find_package` failure.
* Because every backend has its own binary directory, switching managers is
  always "configure a different directory", never an in-place migration.
  Nothing has to be deleted to go from one to the other and back.

> **To build/package with vcpkg, change/run** `cmake --preset vcpkg-release`
> with `VCPKG_ROOT` exported (equivalently: `-D PACKAGE_MANAGER=vcpkg`
> `-D CMAKE_TOOLCHAIN_FILE=<vcpkg>/scripts/buildsystems/vcpkg.cmake`).
>
> **To build/package with Conan, change/run**
> `scripts/conan_install.sh --profile conan/profiles/<profile>` and then
> `cmake --preset conan-release` (equivalently: `-D PACKAGE_MANAGER=conan2`
> `-D CMAKE_TOOLCHAIN_FILE=build/conan2/build/<BuildType>/generators/conan_toolchain.cmake`).

### vcpkg

```sh
# one-time, anywhere outside the repository
git clone https://github.com/microsoft/vcpkg
./vcpkg/bootstrap-vcpkg.sh -disableMetrics     # vcpkg.bat on Windows
export VCPKG_ROOT="$PWD/vcpkg"                 # persistent: set it in your shell profile

cd cpp-project-template
cmake --preset vcpkg-release                   # build/vcpkg-release
cmake --build --preset vcpkg-release
ctest --preset vcpkg-release
cpack --config build/vcpkg-release/CPackConfig.cmake -G TGZ
```

The `vcpkg-release` preset sets `PACKAGE_MANAGER=vcpkg` and
`CMAKE_TOOLCHAIN_FILE=$penv{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake`
(`vcpkg-debug` is the Debug twin). vcpkg then runs in **manifest mode**: the
committed `vcpkg.json` plus its `builtin-baseline` pin wxWidgets and GTest, so
`cmake --preset vcpkg-release` is all it takes — no manual `vcpkg install`.
Windows triplet/overlay instructions (including the
`my-vcpkg-triplets` overlays used by the LLVM legs) are under
[Dependencies → vcpkg](#vcpkg) above.

By hand, without a preset:

```sh
cmake -S . -B build/vcpkg-release \
  -D PACKAGE_MANAGER=vcpkg \
  -D CMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
  -D CMAKE_BUILD_TYPE=Release -G Ninja
```

### Conan 2

```sh
pip install "conan>=2,<3"

cd cpp-project-template
export CONAN_HOME="$PWD/.conan2"   # optional; CI points it at the workspace
                                   # so actions/cache can restore/save it

scripts/conan_install.sh --profile conan/profiles/linux-gcc-x86_64
cmake --preset conan-release       # build/conan2/build/Release
cmake --build --preset conan-release
ctest --preset conan-release
cpack --config build/conan2/build/Release/CPackConfig.cmake -G TGZ
```

`scripts/conan_install.sh` is the canonical install and does the whole
reproducibility contract in one step:

* resolves the graph from the **committed profile** in `conan/profiles/`
  (one per OS/compiler/arch/ABI, e.g. `linux-gcc-x86_64`,
  `windows-msvc-x86_64`, `macos-apple-clang-armv8`) and the **committed
  lockfile** in `conan/locks/<profile>.lock`, which it appends to every
  `conan` call (regenerate with
  `conan lock create conanfile.py -pr <profile> --lockfile-out conan/locks/<profile>.lock`);
* writes the generated `CMakeDeps`/`CMakeToolchain` files into
  `build/conan2` — never into `build/`, so it can never collide with the
  vcpkg/system tree;
* prints before/after `cache-evidence` lines (`host=… cache=… build=…
  missing=…`) so a cold install and a warm one are distinguishable from the
  log alone;
* emits `CMakeUserPresets.json` at the source root (git-ignored), which is
  what makes `cmake --preset conan-release` work. The preset name follows
  the install's build type.

Useful flags: `--output-folder <dir>` (must not be `build/`),
`--build-policy missing|never`, `--no-lock`, `--no-evidence`.

### Choosing the manager in CI

A release run resolves exactly one mode before any build job:

* a tag push (`v*`) reads the committed one-line `packaging/release-package-manager.txt`
  — so the tag alone decides, and the release logs show the chosen mode;
* a manually dispatched run overrides it with the `package_manager` input.

### If configure fails

* *"PACKAGE_MANAGER=vcpkg but CMAKE_TOOLCHAIN_FILE points at a Conan
  toolchain"* — you passed Conan's toolchain while explicitly asking for
  vcpkg. Pick one; the two must never be mixed in a single build tree.
* *"PACKAGE_MANAGER=conan2 but CMAKE_TOOLCHAIN_FILE is not set"* — run
  `scripts/conan_install.sh --profile …` first; it is what generates the
  toolchain.
* *"PACKAGE_MANAGER=vcpkg but CMAKE_TOOLCHAIN_FILE is not set"* (warning) —
  nothing provisioned the dependencies, so `find_package()` will only find
  what the host has installed (apt/brew/choco). Export `VCPKG_ROOT` and use
  the `vcpkg-release` preset, or install the dependencies another way.

### What each CI mode actually provisions

Preserved exactly as it was before Conan 2 was added:

| Runner | `vcpkg` mode | `conan2` mode |
|---|---|---|
| Windows | vcpkg (classic mode, `wxwidgets` + `gtest`, per-triplet binary cache) | Conan 2 profile + lockfile |
| Linux / macOS | host packages from `apt`/`brew` (no vcpkg toolchain on those runners) | Conan 2 profile + lockfile |

Only Windows runners check out and bootstrap vcpkg; that is pre-existing
behaviour, kept unchanged. The Conan 2 mode is available on every leg that
has a profile in `conan/profiles/`.

<a id="compile"></a>
## Compile

Tip: Use Ninja. It can run faster, is less noisy, defaults to multiple cores, and can use the same directory for debug and release builds.

```sh
cmake .. -G "Ninja Multi-Config"
ninja
```

Building for release:

```sh
cmake --build . --config Release
```

Clean:

```sh
cmake --build . --target clean
```

Reference: https://cmake.org/cmake/help/v3.22/guide/user-interaction/index.html#invoking-the-buildsystem

<a id="linux--mac"></a>
### Linux & Mac

```sh
git clone --recursive -j4 https://github.com/MangaD/cpp-project-template
cd cpp-project-template
mkdir build && cd build
cmake .. -G "Ninja"
ninja
```

<a id="windows-compile"></a>
### Windows

```bat
git clone --recursive -j4 https://github.com/MangaD/cpp-project-template
cd cpp-project-template
mkdir build && cd build

# without vcpkg:
cmake ..
# with vcpkg:
cmake .. -DCMAKE_TOOLCHAIN_FILE=<project_root>/vcpkg/scripts/buildsystems/vcpkg.cmake -DVCPKG_TARGET_TRIPLET=x64-windows-static -DVCPKG_HOST_TRIPLET=x64-windows-static

cmake --build . --config Release
```

<a id="package"></a>
## Package

<a id="archive"></a>
### Archive

Current standalone archive policy (2026-09-23, strict; see `docs/PROJECT_DOCUMENTATION.md` § 6.5
and § 13):

| Platform | Archive to download |
|---|---|
| Windows | `.zip` |
| Linux | `.tar.gz` |
| macOS | `.zip` |

Each platform ships exactly one standalone archive per toolchain. `.7z` archives are never
published, and the former Linux `.zip` / macOS `.tar.gz` convenience archives have been removed.
Installers and source archives are unaffected.

**Package the binary:**
```sh
# following is necessary with MSVC:
cmake --build . --config Release
cpack
# or, on linux:
make package
```

**Package the source code:**
```sh
cpack --config CPackSourceConfig.cmake
# or, on linux:
make package_source
```

### Windows

<a id="NSIS"></a>
#### NSIS

Download and Install the Null Soft Installer (NSIS) from [here](https://nsis.sourceforge.io/Download).

```sh
cmake ..
cmake --build . --config Release
cpack -G NSIS64
```

<a id="WiX"></a>
#### WiX

Download and Install the WiX Toolset from [here](https://wixtoolset.org/)

```sh
cmake ..
cmake --build . --config Release
cpack -G WIX
```

### Ubuntu

<a id="deb"></a>
#### DEB

```sh
cmake ..
cpack -G DEB
```

<a id="rpm"></a>
#### RPM

```sh
cmake ..
cpack -G RPM
```

### MacOS

<a id="dmg"></a>
#### DMG

```sh
cmake ..
cpack -G DragNDrop
```

<a id="productbuild"></a>
#### ProductBuild

```sh
cmake ..
cpack -G productbuild
```

<a id="documentation"></a>
## Documentation

```sh
# Doxygen:
cmake --build . --target doxygen
# Sphinx:
cmake --build . --target sphinx
```