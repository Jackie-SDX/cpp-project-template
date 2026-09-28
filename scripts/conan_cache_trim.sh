#!/usr/bin/env bash
# conan_cache_trim.sh -- shrink a Conan 2 home before a CI cache step archives it.
#
# Why this exists
# ---------------
# Caching $CONAN_HOME as-is archives three kinds of folders Conan itself calls
# "non-critical":
#
#   <home>/p/**/b   build folders   object files, CMake trees, extracted trees
#   <home>/p/**/d   download folders  .tgz copies of packages already unpacked
#   <home>/p/**/t   temporary folders
#
# On this project's matrix a single profile's home measures ~3.7 GB, of which
# ~62% is a single wxWidgets build folder. Nineteen profiles therefore need
# ~19 GB, but GitHub Actions keeps only 10 GB of caches per repository, so the
# oldest (Linux/macOS) entries were evicted before the next run could reuse
# them -- the next run rebuilt wxWidgets and every transitive dependency from
# source, and one leg then failed on a transient upstream source download.
#
# What this script does
# ---------------------
# Runs `conan cache clean "*" -b -d -t` (build/download/temp only) and then
# asserts the only thing that matters: the *package* folders -- headers and
# libraries the consumer links against -- are byte-for-byte unchanged. Source
# and export folders are kept deliberately: a source folder belongs to the
# recipe, not to one package_id, so keeping it lets a later option/profile
# change rebuild without touching the network.
#
# Usage
# -----
#   conan_cache_trim.sh [--home DIR] [--conan BIN] [--dry-run]
#
# Environment: CONAN_HOME, CONAN_BIN (both overridden by the flags).
# Exit codes: 0 trimmed (or nothing to trim), 1 invariant violated, 2 usage.
set -euo pipefail

usage() {
  cat <<'EOF'
usage: conan_cache_trim.sh [--home DIR] [--conan BIN] [--dry-run]

Report the size of a Conan 2 home, remove its build/download/temporary
folders, and assert that every package folder survived. --dry-run only
reports.
EOF
}

home=${CONAN_HOME:-${HOME:-}/.conan2}
conan_bin=${CONAN_BIN:-conan}
dry_run=0

while [ $# -gt 0 ]; do
  case "$1" in
    --home) home=${2:?--home needs a path}; shift 2 ;;
    --conan) conan_bin=${2:?--conan needs a path}; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) echo "conan_cache_trim: unknown argument $1" >&2; usage >&2; exit 2 ;;
  esac
done

# Package folders are <home>/p/<storage>/p for downloaded packages and
# <home>/p/b/<storage>/p for locally built ones. Depth 2..3 from <home>/p
# matches both and nothing else Conan stores there.
package_bytes() {
  local root=$1
  [ -d "$root" ] || { printf '0\n'; return 0; }
  find "$root" -mindepth 2 -maxdepth 3 -type d -name p -exec du -sk {} + 2>/dev/null |
    awk '{ s += $1 } END { printf "%d\n", s * 1024 }'
}

tree_bytes() {
  local dir=$1
  [ -e "$dir" ] || { printf '0\n'; return 0; }
  du -sk "$dir" 2>/dev/null | awk '{ printf "%d\n", $1 * 1024 }'
}

human() { # bytes -> human readable
  awk -v b="$1" 'BEGIN {
    split("B KB MB GB TB", u, " ")
    i = 1
    while (b >= 1024 && i < 5) { b /= 1024; i++ }
    printf (i == 1 ? "%d %s" : "%.1f %s"), b, u[i]
  }'
}

if [ ! -d "$home/p" ]; then
  echo "conan_cache_trim: no Conan storage at $home/p -- nothing to trim"
  exit 0
fi

before_total=$(tree_bytes "$home")
before_pkg=$(package_bytes "$home/p")
before_build=$(tree_bytes "$home/p/b")

echo "conan_cache_trim: home=$home"
echo "conan_cache_trim: before: total=$(human "$before_total") packages=$(human "$before_pkg") build-tree=$(human "$before_build")"

if [ "$dry_run" = "1" ]; then
  echo "conan_cache_trim: --dry-run, no changes made"
  exit 0
fi

if ! command -v "$conan_bin" >/dev/null 2>&1 && [ ! -x "$conan_bin" ]; then
  echo "conan_cache_trim: conan executable not found: $conan_bin" >&2
  exit 1
fi

"$conan_bin" cache clean "*" -b -d -t

after_total=$(tree_bytes "$home")
after_pkg=$(package_bytes "$home/p")
after_build=$(tree_bytes "$home/p/b")

echo "conan_cache_trim: after:  total=$(human "$after_total") packages=$(human "$after_pkg") build-tree=$(human "$after_build")"

if [ "$after_pkg" -ne "$before_pkg" ]; then
  echo "conan_cache_trim: INVARIANT VIOLATED -- package folders changed from $before_pkg to $after_pkg bytes" >&2
  exit 1
fi
if [ "$after_total" -gt "$before_total" ]; then
  echo "conan_cache_trim: INVARIANT VIOLATED -- home grew from $before_total to $after_total bytes" >&2
  exit 1
fi

if [ "$before_total" -gt 0 ]; then
  pct=$(awk -v a="$before_total" -v b="$after_total" 'BEGIN { printf "%.0f", (1 - b / a) * 100 }')
else
  pct=0
fi
echo "conan_cache_trim: total $(human "$before_total") -> $(human "$after_total") (-${pct}%), package folders unchanged ($(human "$after_pkg"))"
