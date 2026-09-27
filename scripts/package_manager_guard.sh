#!/usr/bin/env bash
# =============================================================================
# package_manager_guard.sh - regression test for cmake/PackageManager.cmake
# =============================================================================
# Why this exists
# ---------------
# PackageManager.cmake has two jobs that pull in opposite directions:
#
#   1. keep vcpkg and Conan 2 strictly isolated -- an EXPLICIT selection that
#      contradicts the toolchain in the build tree is a configure-time error,
#      never a silent "it mostly works";
#   2. not punish a caller for following the documented commands.
#
# Conan's CMakeToolchain generates a preset that carries only `toolchainFile`
# (and `binaryDir`), never `PACKAGE_MANAGER`. Before issue #152's fix, running
# exactly the documented
#
#     scripts/conan_install.sh --profile conan/profiles/linux-gcc-x86_64
#     cmake --preset conan-release
#
# therefore died with "PACKAGE_MANAGER=vcpkg but CMAKE_TOOLCHAIN_FILE points
# at a Conan toolchain" -- the default had been selected for the user and then
# used against them. The toolchain file is the ground truth for who provisioned
# the build tree, so when (and only when) the caller did not name a manager,
# the Conan toolchain now selects conan2.
#
# This script pins that contract. Every case below is a real `cmake` configure
# of this repository in a throwaway directory; nothing is mocked except the two
# toolchain FILES, which PackageManager.cmake only pattern-matches by name.
#
# Usage
#   scripts/package_manager_guard.sh --selftest
#
# Exit status: 0 all cases behaved, 1 a case regressed, 2 usage/environment.
# Bash 3.2 compatible (macOS runners).
# =============================================================================
set -euo pipefail

die() {
  printf 'package_manager_guard: %s\n' "$*" >&2
  exit 2
}

case "${1:-}" in
  --selftest) ;;
  -h|--help) sed -n '2,36p' "$0"; exit 0 ;;
  *) die "unknown argument: ${1:-<none>} (only --selftest is supported)" ;;
esac

command -v cmake >/dev/null 2>&1 || die "cmake not found on PATH"

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$repo_root/cmake/PackageManager.cmake" ] ||
  die "run from inside the repository (cmake/PackageManager.cmake not found)"

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/pkg-guard.XXXXXX")"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

# Two stub toolchains. PackageManager.cmake decides which manager provisioned a
# build tree by matching the FILE NAME, so the contents only have to be valid
# CMake for the configure to get as far as the selection logic.
mkdir -p "$tmpdir/vcpkg-root/scripts/buildsystems"
printf '# stub vcpkg toolchain (name is what PackageManager.cmake matches)\n' \
  > "$tmpdir/vcpkg-root/scripts/buildsystems/vcpkg.cmake"
printf '# stub conan toolchain (name is what PackageManager.cmake matches)\n' \
  > "$tmpdir/conan_toolchain.cmake"

failures=0
assert_eq() {
  if [ "$1" != "$2" ]; then
    printf 'package_manager_guard: FAIL: %s (expected %s, got %s)\n' "$3" "$2" "$1" >&2
    failures=$((failures + 1))
  else
    printf 'package_manager_guard: ok: %s\n' "$3"
  fi
}

# run_case <label> <expected_rc:0|nonzero> <expected_regex> <forbidden_regex|-> <extra cmake args...>
run_case() {
  local label="$1" want_rc="$2" want="$3" forbid="$4"
  shift 4
  local build="$tmpdir/build-$label" out="$tmpdir/$label.log" rc=0

  # BUILD_PROJECTWX/BUILD_TESTING off keep the configure free of find_package()
  # so this stays a test of the SELECTION logic, not of dependency availability.
  cmake -S "$repo_root" -B "$build" \
    -DBUILD_PROJECTWX=OFF -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=Release \
    "$@" >"$out" 2>&1 || rc=$?

  if [ "$want_rc" = "0" ]; then
    assert_eq "$rc" "0" "$label: configure succeeds"
  elif [ "$rc" != "0" ]; then
    assert_eq "nonzero" "nonzero" "$label: configure fails"
  else
    assert_eq "0" "nonzero" "$label: configure fails"
  fi

  if grep -Eq "$want" "$out"; then
    assert_eq "yes" "yes" "$label: output matches '$want'"
  else
    assert_eq "no" "yes" "$label: output matches '$want'"
    printf -- '----- %s output -----\n%s\n---------------------\n' "$label" "$out" >&2
  fi

  if [ "$forbid" != "-" ] && grep -Eq "$forbid" "$out"; then
    assert_eq "present" "absent" "$label: output does not match '$forbid'"
    printf -- '----- %s output -----\n%s\n---------------------\n' "$label" "$out" >&2
  fi
}

conan_tc="$tmpdir/conan_toolchain.cmake"
vcpkg_tc="$tmpdir/vcpkg-root/scripts/buildsystems/vcpkg.cmake"

# 1. The documented command: Conan toolchain, no -D PACKAGE_MANAGER at all.
#    Must infer conan2 -- this is the case that used to FATAL_ERROR.
run_case conan-inferred 0 \
  'Package manager: conan2 \(inferred from CMAKE_TOOLCHAIN_FILE' 'points at a Conan' \
  -D "CMAKE_TOOLCHAIN_FILE=$conan_tc"

# 2. Explicit vcpkg + a Conan toolchain is contamination: hard stop.
run_case conan-vs-explicit-vcpkg nonzero \
  'PACKAGE_MANAGER=vcpkg but CMAKE_TOOLCHAIN_FILE points at a Conan' '-' \
  -D "CMAKE_TOOLCHAIN_FILE=$conan_tc" -D PACKAGE_MANAGER=vcpkg

# 3. Explicit conan2 is honoured and reported as an explicit choice.
run_case conan-explicit 0 \
  '^-- Package manager: conan2$' 'inferred from CMAKE_TOOLCHAIN_FILE' \
  -D "CMAKE_TOOLCHAIN_FILE=$conan_tc" -D PACKAGE_MANAGER=conan2

# 4. Explicit conan2 with nothing provisioned: actionable error, not a
#    late find_package failure.
run_case conan-no-toolchain nonzero \
  'PACKAGE_MANAGER=conan2 but CMAKE_TOOLCHAIN_FILE is not set' '-' \
  -D PACKAGE_MANAGER=conan2

# 5. The vcpkg side is untouched: a vcpkg toolchain with no -D stays vcpkg.
run_case vcpkg-default 0 \
  '^-- Package manager: vcpkg$' 'inferred from CMAKE_TOOLCHAIN_FILE' \
  -D "CMAKE_TOOLCHAIN_FILE=$vcpkg_tc"

# 6. Plain configure with neither toolchain keeps the historical default
#    (vcpkg) plus its "you forgot the toolchain" warning.
run_case bare-default 0 \
  'PACKAGE_MANAGER=vcpkg but CMAKE_TOOLCHAIN_FILE is not set' 'inferred from'

if [ "$failures" -ne 0 ]; then
  printf 'package_manager_guard: %d case(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'package_manager_guard: selftest ok (6 cases)\n'
