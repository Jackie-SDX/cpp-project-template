#!/usr/bin/env bash
# =============================================================================
# conan_install.sh - the canonical Conan 2 dependency install for this repo.
# =============================================================================
# Why this exists
# ---------------
# The install has to do four things the same way everywhere (docs, local
# development, conan.yml, release.yml):
#
#   1. resolve the graph from a committed profile + committed lockfile so a
#      "same source" build cannot silently float to newer ConanCenter
#      revisions;
#   2. generate CMakeDeps/CMakeToolchain into an output folder isolated from
#      the vcpkg build tree (default build/conan2 -- never plain build/);
#   3. prove cache state with evidence instead of vibes: run the graph BEFORE
#      the install (what is already local vs what must be built/downloaded),
#      time the install, then run it again AFTER (everything must be Cache);
#   4. append that evidence to $GITHUB_STEP_SUMMARY when running in CI so
#      cold vs warm runs are visible without opening raw logs.
#
# Usage
# -----
#   scripts/conan_install.sh --profile conan/profiles/linux-gcc-x86_64 \
#       [--lockfile conan/locks/linux-gcc-x86_64.lock] \
#       [--output-folder build/conan2] \
#       [--build-policy missing|never] \
#       [--no-lock] [--no-evidence] [-- <extra conan args>]
#
# Environment
#   CONAN_BIN              conan executable (default: conan on PATH)
#   CONAN_HOME             left to the caller; CI points it at the workspace
#                          so actions/cache can restore/save it
#
# Exit status: conan's own exit status (non-zero install = non-zero here).
# Bash 3.2 compatible (macOS runners): no bash-4-only array expansions.
# =============================================================================
set -euo pipefail

die() {
  printf 'conan_install: %s\n' "$*" >&2
  exit 2
}

profile=""
lockfile=""
lockfile_dir="conan/locks"
output_folder="build/conan2"
build_policy="missing"
use_lock=1
evidence=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile) profile="$2"; shift 2 ;;
    --lockfile) lockfile="$2"; shift 2 ;;
    --lockfile-dir) lockfile_dir="$2"; shift 2 ;;
    --output-folder) output_folder="$2"; shift 2 ;;
    --build-policy) build_policy="$2"; shift 2 ;;
    --no-lock) use_lock=0; shift ;;
    --no-evidence) evidence=0; shift ;;
    --) shift; break ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
# Everything after "--" is passed verbatim to `conan install` (kept in "$@").

[ -n "$profile" ] || die "--profile is required (see conan/profiles/)"
[ -f "$profile" ] || die "profile not found: $profile"
case "$build_policy" in missing|never) ;; *) die "unsupported build policy: $build_policy" ;; esac

# Never let the Conan output folder collide with the vcpkg/system build tree:
# cross-contamination of generated dependency metadata is exactly what
# PACKAGE_MANAGER selection exists to prevent.
case "$output_folder" in
  build|./build) die "--output-folder '$output_folder' is the vcpkg/system build tree; use build/conan2 (default) or another dedicated folder" ;;
esac

CONAN="${CONAN_BIN:-conan}"
if ! command -v "$CONAN" >/dev/null 2>&1; then
  die "conan not found on PATH (pip install conan / see docs)"
fi
CONAN="$(command -v "$CONAN")"

if command -v python3 >/dev/null 2>&1; then
  PYTHON=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON=python
else
  PYTHON=""
fi

# Load the Windows compiler environment (vcvars/VsDevCmd) when the caller
# provides one: `conan install --build=missing` compiles wxWidgets from
# source and must run under the same environment the CI build uses (INCLUDE,
# LIB, PATH -> cl/clang-cl). Mirrors the ENVIRONMENT_SCRIPT handling in
# .github/scripts/configure.cmake. On non-Windows legs the variable is unset
# and this is a no-op.
load_windows_environment() {
  [ -n "${ENVIRONMENT_SCRIPT:-}" ] || return 0
  [ -f "$ENVIRONMENT_SCRIPT" ] || die "ENVIRONMENT_SCRIPT not found: $ENVIRONMENT_SCRIPT"
  if ! command -v cmd >/dev/null 2>&1; then
    die "ENVIRONMENT_SCRIPT is set but cmd is not on PATH (not a Windows shell?)"
  fi
  local wrapper env_file
  # A .bat wrapper instead of `cmd //c '"..." && set'`: MSYS re-quotes
  # embedded quotes as \" on the way to cmd.exe, which then treats the
  # batch path as a literal program name (run 36287538030, exit 2:
  # "'\"...vcvars64.bat\"' is not recognized as an internal or external
  # command"). cmd parses the quotes inside the wrapper file itself,
  # where they are correct.
  wrapper="${RUNNER_TEMP:-/tmp}/conan-env-load-$$.bat"
  case "$wrapper" in
    *' '*) die "wrapper path contains spaces: $wrapper" ;;
  esac
  env_file="$(mktemp)"
  if ! printf '@echo off\r\ncall "%s" || exit /b 1\r\nset\r\n' \
      "$ENVIRONMENT_SCRIPT" >"$wrapper"; then
    rm -f "$env_file"
    die "failed to write wrapper $wrapper"
  fi
  if ! cmd //c "$wrapper" >"$env_file"; then
    rm -f "$wrapper" "$env_file"
    die "failed to evaluate ENVIRONMENT_SCRIPT: $ENVIRONMENT_SCRIPT"
  fi
  rm -f "$wrapper"
  local line name raw_path=""
  local orig_path="$PATH"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
      [A-Za-z_]*=*) ;;
      *) continue ;;
    esac
    name="${line%%=*}"
    # 'set' also prints names like CommonProgramFiles(x86)=..., which are
    # not valid shell identifiers -- exporting those aborts the script.
    case "$name" in
      ''|[0-9]*|*[!A-Za-z0-9_]*) continue ;;
    esac
    case "$name" in
      [Pp][Aa][Tt][Hh])
        # vcvars PATH is ';'-separated native Windows directories. Merging
        # it instead of exporting keeps rm/grep/... from the bash PATH.
        raw_path="${line#*=}"
        continue
        ;;
    esac
    export "$line"
  done <"$env_file"
  rm -f "$env_file"
  if [ -n "$raw_path" ]; then
    local merged="" entry lc_entry orig_lc old_ifs="$IFS"
    # vcvars *prepends* to the PATH it inherited, so $raw_path already contains
    # $orig_path. Prepending it verbatim on top of $orig_path therefore roughly
    # doubles PATH, and the second activation Conan runs for its own
    # conanvcvars.bat then overflows cmd.exe's 8191-character limit ("The input
    # line is too long", run 36294183365, Windows MSVC ARM64). Keep only the
    # entries that are genuinely new; Windows paths are case-insensitive, so
    # compare lowercased, and track what we have already added so a single
    # vcvars call cannot duplicate entries either.
    orig_lc=":$(printf '%s' "$orig_path" | tr '[:upper:]' '[:lower:]'):"
    IFS=';'
    for entry in $raw_path; do
      [ -n "$entry" ] || continue
      entry="$(cygpath -u "$entry" 2>/dev/null || printf '%s' "$entry")"
      lc_entry="$(printf '%s' "$entry" | tr '[:upper:]' '[:lower:]')"
      case "$orig_lc" in
        *":$lc_entry:"*) continue ;;
      esac
      orig_lc="${orig_lc}${lc_entry}:"
      merged="${merged:+$merged:}$entry"
    done
    IFS="$old_ifs"
    if [ -n "$merged" ]; then
      export PATH="${merged}:${orig_path}"
    fi
  fi
  printf 'conan_install: loaded Windows environment from %s (PATH length=%s chars)\n' \
    "$ENVIRONMENT_SCRIPT" "${#PATH}"
}
load_windows_environment

# Conan always needs a *build* profile; --profile supplies the host one, and
# the build profile falls back to $CONAN_HOME/profiles/default. A fresh
# CONAN_HOME (cold CI cache on a new runner) has no auto-detected default
# yet -- detect it once, inside the loaded compiler environment so the
# detected compiler matches this leg. Never overwrite an existing default:
# warm cache restores already carry one.
conan_home="${CONAN_HOME:-${HOME}/.conan2}"
default_profile="${conan_home}/profiles/default"
if [ ! -f "$default_profile" ] || ! grep -q '^compiler=' "$default_profile"; then
  # Also repairs a warm cache whose default profile was saved without a
  # compiler (that makes build-require package ids invalid).
  printf 'conan_install: detecting default build profile in %s\n' "$conan_home"
  "$CONAN" profile detect --force || die "conan profile detect failed"
fi

# conan profile detect writes the runner's exact compiler version, which
# may not exist in this conan release's bundled settings.yml schema (e.g.
# Homebrew clang 23 vs conan 2.32 -> "Invalid setting '23' is not a valid
# 'settings.compiler.version' value"). The build profile's compiler IS
# consulted: build-require package ids evaluate it ("Invalid:
# 'settings.compiler' value not defined"), so never strip it. Instead
# extend THIS conan home's settings.yml when the detected version is
# missing.
settings_file="${conan_home}/settings.yml"
if [ -f "$default_profile" ] && [ -f "$settings_file" ]; then
  settings_py=""
  if [ -n "${CONAN_BIN:-}" ] && [ -x "$(dirname "$CONAN_BIN")/python" ]; then
    settings_py="$(dirname "$CONAN_BIN")/python"
  else
    settings_py="$(command -v python3 || command -v python || true)"
  fi
  if [ -n "$settings_py" ]; then
    "$settings_py" - "$default_profile" "$settings_file" <<'PYEOF' \
      || die "failed to reconcile $settings_file with $default_profile"
import re
import sys

profile_path, settings_path = sys.argv[1], sys.argv[2]
compiler = version = None
with open(profile_path, encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if line.startswith("compiler.version="):
            version = line.split("=", 1)[1].strip().strip("\"'")
        elif line.startswith("compiler="):
            compiler = line.split("=", 1)[1].strip().strip("\"'")
if not (compiler and version):
    sys.exit(0)

with open(settings_path, encoding="utf-8") as handle:
    text = handle.read()
# settings.yml: compiler names indent 4 spaces, their keys 8.
head = re.search(r"(?m)^    %s:\s*$" % re.escape(compiler), text)
if not head:
    sys.exit(0)
rest = text[head.end():]
next_key = re.search(r"(?m)^(?=    \S|\S)", rest)
block = rest[: next_key.start() if next_key else len(rest)]
vstart = re.search(r"(?m)^        version:\s*\[", block)
if vstart is None:
    sys.exit(0)
offset = head.end() + vstart.end()  # text offset just past '['
close = text.find("]", offset)
if close < 0:
    sys.exit(0)
segment = text[offset:close]
values = [v.strip().strip("\"'") for v in segment.split(",") if v.strip()]
if version in values:
    sys.exit(0)
raw_first = segment.split(",")[0].strip() if segment.strip() else ""
quoted = raw_first[:1] in ('"', "'")
new_value = '"%s"' % version if quoted else version
separator = ", " if segment.strip() else ""
updated = (
    text[:offset]
    + segment
    + separator
    + new_value
    + text[close:]
)
with open(settings_path, "w", encoding="utf-8") as handle:
    handle.write(updated)
print(
    "conan_install: extended %s: %s version %s"
    % (settings_path, compiler, version)
)
PYEOF
  else
    printf 'conan_install: WARNING: no python found to reconcile %s\n' \
      "$settings_file"
  fi
fi

# Third-party source hosts (e.g. www.cairographics.org) time out when all
# CI legs fetch them concurrently; conan defaults to 2 retries / 5s for
# recipe downloads. Bump retries in this CONAN_HOME only (never the user's
# home config) and never clobber settings that are already present.
conf_file="${conan_home}/global.conf"
ensure_conf() {
  [ -f "$conf_file" ] || : >"$conf_file"
  grep -q "^$1[=:]" "$conf_file" || printf '%s\n' "$2" >>"$conf_file"
}
ensure_conf "core.download:retry" "core.download:retry=6"
ensure_conf "core.download:retry_wait" "core.download:retry_wait=10"
ensure_conf "tools.files.download:retry" "tools.files.download:retry=6"
ensure_conf "tools.files.download:retry_wait" "tools.files.download:retry_wait=15"
printf 'conan_install: download retries in %s: package=6/10s source=6/15s\n' \
  "$conf_file"

profile_name="$(basename "$profile")"
if [ "$use_lock" = "1" ] && [ -z "$lockfile" ]; then
  lockfile="${lockfile_dir}/${profile_name}.lock"
fi
if [ "$use_lock" = "1" ] && [ ! -f "$lockfile" ]; then
  die "lockfile not found: $lockfile (regenerate: conan lock create conanfile.py -pr $profile --lockfile-out $lockfile)"
fi

# ---------------------------------------------------------------------------
# Windows MinGW legs: pin the *MinGW* compiler for every conan invocation.
#
# tools.build:compiler_executables becomes CC/CXX in Autotools/Meson/CMake
# toolchains, and the mingw profiles declare the bare names ("gcc"/"g++").
# Bare names are resolved through the PATH inside the msys2 bash Conan runs
# recipes in, and that PATH is led by the conan-installed msys2 package --
# whose recipe default packages are "base-devel,binutils,gcc", i.e. it ships a
# cygwin-hosted MSYS gcc. libiconv (a tool_require of wxWidgets through
# gettext) then configures with that compiler: gnulib sees _WIN32, emits its
# `struct _stati64` replacements, and cygwin's <sys/stat.h> has no such type,
# so the build dies with "invalid use of undefined type 'const struct
# _stati64'" (run 36294183365). Absolute paths remove the ambiguity for every
# generator at once; command-line -c wins over the profile value (verified
# against conan 2.32), and Conan accepts absolute Windows paths in these confs.
# ---------------------------------------------------------------------------
extra_conf=""
if grep -q '^os=Windows$' "$profile" && grep -q '^compiler=gcc$' "$profile"; then
  mingw_cc="$(command -v gcc || true)"
  mingw_cxx="$(command -v g++ || true)"
  if [ -z "$mingw_cc" ] || [ -z "$mingw_cxx" ]; then
    die "profile $profile needs gcc/g++ on PATH (the MinGW toolchain is not installed on this runner)"
  fi
  if command -v cygpath >/dev/null 2>&1; then
    mingw_cc="$(cygpath -m "$mingw_cc")"
    mingw_cxx="$(cygpath -m "$mingw_cxx")"
  fi
  extra_conf="tools.build:compiler_executables={\"c\": \"$mingw_cc\", \"cpp\": \"$mingw_cxx\"}"
  printf 'conan_install: MinGW compilers pinned by absolute path c=%s cpp=%s\n' \
    "$mingw_cc" "$mingw_cxx"
fi

# ---------------------------------------------------------------------------
# Build-context tool_requires (gettext -> libiconv, pulled in by wxWidgets)
# take their settings from the *detected* build profile, not from the committed
# host profile. Conan's Windows clang detection hard-codes
#   "WARN: Assuming LLVM/Clang in Windows with VS 17 2022"
# and writes compiler.runtime_version=v143 there, so VCVars for those packages
# asks for VS 17 + toolset 14.3, which windows-latest (VS 18 only) and
# windows-11-arm (14.4x only) do not have (run 36306665122: "VS non-existing
# installation: Visual Studio 17" and "Toolset directory for version '14.3'
# was not found"). The build compiler is the same clang-cl installation the
# host profile describes, so carry the host profile's runtime_version into the
# build context. Only the windows-clangcl-* profiles define runtime_version at
# all, and the detected build profile must actually be clang -- msvc has no
# such setting and Conan would reject it.
b_runtime_version=""
if grep -q '^compiler\.runtime_version=' "$profile"; then
  if [ -f "$default_profile" ] && grep -q '^compiler=clang$' "$default_profile"; then
    b_runtime_version="$(sed -n 's/^compiler\.runtime_version=//p' "$profile" | head -1)"
    printf 'conan_install: build context compiler.runtime_version=%s\n' \
      "$b_runtime_version"
  fi
fi

# run_conan <args...>: appends the lockfile when locking is enabled.
run_conan() {
  if [ -n "$extra_conf" ]; then
    # :a -- build-context packages see the same value as host ones; the MinGW
    # pin is meaningless for only half of the graph.
    set -- "$@" -c:a "$extra_conf"
  fi
  if [ -n "$b_runtime_version" ]; then
    set -- "$@" -s:b "compiler.runtime_version=$b_runtime_version"
  fi
  if [ "$use_lock" = "1" ]; then
    "$CONAN" "$@" --lockfile "$lockfile"
  else
    "$CONAN" "$@"
  fi
}

printf 'conan_install: profile=%s lock=%s output=%s build-policy=%s conan=%s\n' \
  "$profile_name" "${lockfile:-<none>}" "$output_folder" "$build_policy" \
  "$("$CONAN" --version 2>/dev/null | head -1)"

# Graph-state probe used before/after the install. mode=report overrides the
# profile's package-manager mode so probing never triggers apt/brew and works
# for foreign-arch profiles too -- it does not change the resolved graph
# (verified: lockfiles produced with mode=install and mode=report are
# byte-identical).
probe_graph() {
  if [ -z "$PYTHON" ]; then
    printf 'cache-evidence: probe-unavailable (no python)\n'
    return 0
  fi
  if ! run_conan graph info . \
      --profile "$profile" \
      -c tools.system.package_manager:mode=report \
      --format=json 2>/dev/null | "$PYTHON" -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("cache-evidence: probe-unavailable (bad json)")
    sys.exit(0)
from collections import Counter
nodes = data.get("graph", {}).get("nodes", {})
counts = Counter()
for n in nodes.values():
    if n.get("context") != "host":
        continue
    b = n.get("binary")
    if b is None:
        counts["consumer"] += 1
    else:
        counts[b] += 1
host = sum(v for k, v in counts.items() if k != "consumer")
other = host - counts.get("Cache", 0) - counts.get("Build", 0) - counts.get("Missing", 0)
print("cache-evidence: host=%d cache=%d build=%d missing=%d other=%d" % (
    host, counts.get("Cache", 0), counts.get("Build", 0),
    counts.get("Missing", 0), other))
'; then
    printf 'cache-evidence: probe-failed\n'
  fi
}

num_field() {
  # num_field <label> <evidence-string>
  printf '%s' "$2" | grep -oE "$1=[0-9]+" | head -1 | cut -d= -f2
}

summary_line() {
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"
  fi
}

pre="probe-unavailable"
post="probe-unavailable"
if [ "$evidence" = "1" ]; then
  pre="$(probe_graph | tail -1)"
  printf 'conan_install: before install: %s\n' "$pre"
fi

start_ts="$(date +%s)"
set +e
run_conan install . \
  --output-folder "$output_folder" \
  --build="$build_policy" \
  --profile "$profile" \
  "$@"
status=$?
set -e
end_ts="$(date +%s)"
elapsed=$((end_ts - start_ts))
printf 'conan_install: install exit=%s elapsed=%ss\n' "$status" "$elapsed"
[ "$status" -eq 0 ] || exit "$status"

if [ "$evidence" = "1" ]; then
  post="$(probe_graph | tail -1)"
  printf 'conan_install: after install:  %s\n' "$post"
  summary_line "### Conan install (${profile_name})"
  summary_line ""
  summary_line "| stage | evidence |"
  summary_line "| --- | --- |"
  summary_line "| before | \`${pre}\` |"
  summary_line "| install | exit=${status}, ${elapsed}s, build-policy=${build_policy} |"
  summary_line "| after | \`${post}\` |"
  summary_line ""
  post_build="$(num_field build "$post")"
  post_missing="$(num_field missing "$post")"
  if [ "${post_build:-x}" = "0" ] && [ "${post_missing:-x}" = "0" ]; then
    printf 'conan_install: OK - graph fully local after install\n'
  else
    printf 'conan_install: WARNING - post-install evidence not fully local: %s\n' "$post" >&2
  fi
fi

printf 'conan_install: done -> %s\n' "$output_folder"
