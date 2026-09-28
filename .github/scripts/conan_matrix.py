#!/usr/bin/env python3
"""Emit the conan.yml build matrix as JSON.

Usage
-----
  conan_matrix.py                 all 19 legs
  conan_matrix.py <profile>       exactly one leg (exact conan/profiles name)
  conan_matrix.py --selftest      validate the table against conan/profiles/

Why this exists
---------------
conan.yml must DECLARE the full supported matrix (never shrink it), while a
dispatch input may SELECT a subset for fast iteration. The selection happens
here so the workflow itself stays declarative: `plan` runs this script, and
`conan-leg` receives `matrix.include` as JSON. The table is the single place
where profile -> runner/toolchain identity is mapped, and --selftest fails
if a committed profile has no leg (or a leg references a missing profile).
"""
import json
import os
import sys

# Keep in sync with conan/profiles/ and the release.yml leg mappings.
# toolchain values feed PACKAGE_TOOLCHAIN in configure.cmake (macOS compiler
# selection); linux_multilib drives the i386 apt/-m32 environment; the
# msys2_*/environment_script fields mirror the release workflow setup steps.
LEGS = [
    dict(profile="windows-msvc-x86_64", os="windows-latest", compiler="msvc",
         cc="cl", cxx="cl", arch="x64", environment_script="vcvars64.bat"),
    dict(profile="windows-msvc-i686", os="windows-latest", compiler="msvc",
         cc="cl", cxx="cl", arch="x86", environment_script="vcvars32.bat"),
    dict(profile="windows-msvc-armv8", os="windows-11-arm", compiler="msvc",
         cc="cl", cxx="cl", arch="arm64", environment_script="vcvars-arm64.bat"),
    dict(profile="windows-clangcl-x86_64", os="windows-latest", compiler="llvm",
         cc="clang-cl", cxx="clang-cl", arch="x64", environment_script="vcvars64.bat"),
    dict(profile="windows-clangcl-i686", os="windows-latest", compiler="llvm",
         cc="clang-cl", cxx="clang-cl", arch="x86", environment_script="vcvars32.bat"),
    dict(profile="windows-clangcl-armv8", os="windows-11-arm", compiler="llvm",
         cc="clang-cl", cxx="clang-cl", arch="arm64", environment_script="vcvars-arm64.bat"),
    dict(profile="windows-mingw-x86_64", os="windows-latest", compiler="mingw",
         cc="gcc", cxx="g++", arch="x64",
         msys2_msystem="MINGW64", msys2_toolchain="mingw-w64-x86_64-toolchain",
         msys2_bin="mingw64/bin"),
    dict(profile="windows-mingw-i686", os="windows-latest", compiler="mingw",
         cc="gcc", cxx="g++", arch="x86",
         msys2_msystem="MINGW32", msys2_toolchain="mingw-w64-i686-toolchain",
         msys2_bin="mingw32/bin"),
    dict(profile="linux-gcc-x86_64", os="ubuntu-24.04", compiler="gcc",
         cc="gcc", cxx="g++", arch="x64", linux_multilib=False),
    dict(profile="linux-gcc-armv8", os="ubuntu-24.04-arm", compiler="gcc",
         cc="gcc", cxx="g++", arch="arm64", linux_multilib=False),
    dict(profile="linux-gcc-x86", os="ubuntu-24.04", compiler="gcc",
         cc="gcc", cxx="g++", arch="x86", linux_multilib=True),
    dict(profile="linux-clang-x86_64", os="ubuntu-24.04", compiler="clang",
         cc="clang", cxx="clang++", arch="x64", linux_multilib=False),
    dict(profile="linux-clang-armv8", os="ubuntu-24.04-arm", compiler="clang",
         cc="clang", cxx="clang++", arch="arm64", linux_multilib=False),
    dict(profile="macos-apple-clang-armv8", os="macos-latest", compiler="apple-clang",
         cc="clang", cxx="clang++", arch="arm64"),
    dict(profile="macos-apple-clang-x86_64", os="macos-15-intel", compiler="apple-clang",
         cc="clang", cxx="clang++", arch="x64"),
    dict(profile="macos-gcc-armv8", os="macos-latest", compiler="gcc",
         cc="gcc", cxx="g++", arch="arm64",
         build_projectwx="OFF", build_testing="OFF"),
    dict(profile="macos-gcc-x86_64", os="macos-15-intel", compiler="gcc",
         cc="gcc", cxx="g++", arch="x64",
         build_projectwx="OFF", build_testing="OFF"),
    dict(profile="macos-clang-armv8", os="macos-latest", compiler="llvm",
         cc="clang", cxx="clang++", arch="arm64"),
    dict(profile="macos-clang-x86_64", os="macos-15-intel", compiler="llvm",
         cc="clang", cxx="clang++", arch="x64"),
]


def _profile_dir() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(here, "..", "..", "conan", "profiles"))


def selftest() -> int:
    on_disk = {n for n in os.listdir(_profile_dir())
               if not n.startswith(".") and not n.endswith((".lock", ".md"))}
    table = {leg["profile"] for leg in LEGS}
    missing_legs = sorted(on_disk - table)
    missing_profiles = sorted(table - on_disk)
    errors = []
    if missing_legs:
        errors.append(f"profiles without a matrix leg: {missing_legs}")
    if missing_profiles:
        errors.append(f"legs referencing unknown profiles: {missing_profiles}")
    if len(table) != len(LEGS):
        errors.append("duplicate profile entries in the table")
    for leg in LEGS:
        for key in ("profile", "os", "compiler", "cc", "cxx", "arch"):
            if not leg.get(key):
                errors.append(f"{leg.get('profile', '?')}: missing {key}")
    if errors:
        for e in errors:
            print(f"conan_matrix: {e}", file=sys.stderr)
        return 1
    print(f"conan_matrix: selftest ok ({len(LEGS)} legs, {len(on_disk)} profiles)")
    return 0


def main(argv) -> int:
    if len(argv) == 2 and argv[1] == "--selftest":
        return selftest()
    if len(argv) > 2:
        print(__doc__, file=sys.stderr)
        return 2
    if len(argv) == 2:
        wanted = argv[1]
        legs = [leg for leg in LEGS if leg["profile"] == wanted]
        if not legs:
            print(
                f"conan_matrix: no leg for profile '{wanted}' "
                f"(known: {', '.join(leg['profile'] for leg in LEGS)})",
                file=sys.stderr,
            )
            return 1
    else:
        legs = LEGS
    # Compact, single-line JSON: the workflow writes this straight into
    # $GITHUB_OUTPUT, where embedded newlines would corrupt the value.
    print(json.dumps(legs, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
