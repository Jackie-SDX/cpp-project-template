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
  local env_file
  env_file="$(mktemp)"
  # cmd's own quoting: the batch file must stay one quoted argument.
  if ! cmd //c "\"${ENVIRONMENT_SCRIPT}\" && set" >"$env_file"; then
    rm -f "$env_file"
    die "failed to evaluate ENVIRONMENT_SCRIPT: $ENVIRONMENT_SCRIPT"
  fi
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
      [A-Za-z_][A-Za-z0-9_]*=*) export "$line" ;;
    esac
  done <"$env_file"
  rm -f "$env_file"
  printf 'conan_install: loaded Windows environment from %s\n' "$ENVIRONMENT_SCRIPT"
}
load_windows_environment

# Conan always needs a *build* profile; --profile supplies the host one, and
# the build profile falls back to $CONAN_HOME/profiles/default. A fresh
# CONAN_HOME (cold CI cache on a new runner) has no auto-detected default
# yet -- detect it once, inside the loaded compiler environment so the
# detected compiler matches this leg. Never overwrite an existing default:
# warm cache restores already carry one.
conan_home="${CONAN_HOME:-${HOME}/.conan2}"
if [ ! -f "${conan_home}/profiles/default" ]; then
  printf 'conan_install: detecting default build profile in %s\n' "$conan_home"
  "$CONAN" profile detect || die "conan profile detect failed"
fi

profile_name="$(basename "$profile")"
if [ "$use_lock" = "1" ] && [ -z "$lockfile" ]; then
  lockfile="${lockfile_dir}/${profile_name}.lock"
fi
if [ "$use_lock" = "1" ] && [ ! -f "$lockfile" ]; then
  die "lockfile not found: $lockfile (regenerate: conan lock create conanfile.py -pr $profile --lockfile-out $lockfile)"
fi

# run_conan <args...>: appends the lockfile when locking is enabled.
run_conan() {
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
