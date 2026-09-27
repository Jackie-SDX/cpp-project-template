#!/usr/bin/env bash
# =============================================================================
# conan_cache_key.sh - single source of truth for the Conan 2 binary-cache
# key contract (issue #152, the Conan twin of ADR 006).
# =============================================================================
# Why this exists
# ---------------
# Every workflow that restores or saves a Conan package cache must derive the
# key from the same inputs, otherwise one workflow's producer can never satisfy
# another's consumer, and a single shared key could be written by producers
# with different binary-validity inputs (compiler, profile, lock state).
#
# Key shape
# ---------
#   key        = <prefix>-<build_type>-<conan_fp>-<profile_fp>-
#                <lock_fp>-<recipe_fp>[-<extra_fp>]
#   prefix     = conan-<family>-<namespace>-<profile_name>
#
#   family       release (release.yml) | ci (conan.yml / ci family) |
#                smoke (package smokes) - each family owns its keys, so
#                producers from different families never write the same key.
#   namespace    logical cache namespace token (branch/major line).
#   profile_name basename of the profile (carries OS/compiler/arch identity,
#                e.g. windows-msvc-x86_64, macos-gcc-armv8).
#   conan_fp     sha256(`conan --version`) first 8 chars (cache format and
#                recipe-engine drift).
#   profile_fp   sha256 of the profile file, comments/blank lines/CRLF folded
#                away so a comment edit does not invalidate a warm cache but
#                any settings/options/conf change does.
#   lock_fp      sha256 of the committed lockfile (the full transitive graph:
#                recipe revisions for every requirement).
#   recipe_fp    sha256 of conanfile.py (requires/options/generators).
#   extra_fp     --extra-fingerprint value or "none".
#
# Why no restore-keys (unlike vcpkg_cache_key.sh): a Conan package cache is
# keyed by package_id internally, so a stale restore can never satisfy a
# different configuration -- it would only add dead weight. The exact key
# already re-keys on every binary-validity input above, so a prefix fallback
# would buy hit-rate only on comment-only edits (already handled by
# profile_fp) while making cold/warm evidence ambiguous.
#
# Usage
# -----
#   conan_cache_key.sh key        <options>
#   conan_cache_key.sh github-env <options>
#   conan_cache_key.sh selftest
#
# Options
#   --family            release|ci|smoke          (default: release)
#   --profile           profile path               (required)
#   --lockfile          lockfile path              (default: conan/locks/<profile>.lock)
#   --recipe            conanfile path             (default: conanfile.py)
#   --build-type        Release|Debug              (default: Release)
#   --namespace         namespace token             (default: $CONAN_CACHE_NAMESPACE or master)
#   --extra-fingerprint extra ABI fingerprint segment (default: none)
#
# github-env writes CONAN_CACHE_KEY to $GITHUB_ENV when that file is set.
#
# Exits 2 on usage errors so a bad contract cannot silently produce a key.
# =============================================================================
set -euo pipefail

usage() {
  printf '%s\n' \
    'usage: conan_cache_key.sh <key|github-env|selftest> [options]' \
    '       see the header comment of this file for the option list'
}

die() {
  printf 'conan_cache_key: %s\n' "$*" >&2
  exit 2
}

sha256_hex() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    openssl dgst -sha256 -hex | awk '{print $NF}'
  fi
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    openssl dgst -sha256 -hex "$1" | awk '{print $NF}'
  fi
}

short() {
  printf '%s' "$1" | cut -c1-"${2:-8}"
}

# Hash of a text file with CRLF folded to LF. With --ignore-comments, blank
# lines and comment lines (#...) are dropped first, so documentation edits
# inside a profile do not invalidate a warm cache but every semantic line
# still does.
text_hash() {
  local file="$1" ignore_comments="${2:-}"
  [ -f "$file" ] || die "file not found: $file"
  local normalized
  normalized="$(mktemp)"
  tr -d '\r' < "$file" > "$normalized"
  if [ -n "$ignore_comments" ]; then
    local stripped
    stripped="$(mktemp)"
    grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$normalized" > "$stripped" || true
    mv "$stripped" "$normalized"
  fi
  sha256_file "$normalized" | cut -c1-16
  rm -f "$normalized"
}

conan_version_string() {
  if [ -n "${CONAN_BIN:-}" ]; then
    "$CONAN_BIN" --version 2>/dev/null | head -1
  elif command -v conan >/dev/null 2>&1; then
    conan --version 2>/dev/null | head -1
  else
    printf 'conan unknown'
  fi
}

# Fingerprint of the Conan version (cache format drift): hash the numeric
# version so e.g. 2.31.0 -> 2.32.0 moves the key. "Conan version" prefix is
# stripped first -- hashing the full banner would freeze the first 8 hex
# chars to the constant word "Conanversion".
conan_fp_hex() {
  local ver
  ver="$(conan_version_string | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)"
  [ -n "$ver" ] || ver="unknown"
  printf '%s' "$ver" | sha256_hex | cut -c1-8
}

run_selftest() {
  local failures=0 tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  assert_eq() {
    if [ "$1" = "$2" ]; then
      printf 'ok   - %s\n' "$3"
    else
      printf 'FAIL - %s\n     want: %s\n     got : %s\n' "$3" "$2" "$1"
      failures=$((failures + 1))
    fi
  }

  local prof lock recipe
  prof="$tmpdir/linux-gcc-x86_64"
  lock="$tmpdir/linux-gcc-x86_64.lock"
  recipe="$tmpdir/conanfile.py"
  printf '[settings]\nos=Linux\narch=x86_64\ncompiler=gcc\ncompiler.version=13\ncompiler.cppstd=gnu17\nbuild_type=Release\n' > "$prof"
  printf '{"version":"0.5","requires":["wxwidgets/3.2.11#rev1"]}\n' > "$lock"
  printf 'class R: pass\n' > "$recipe"

  # 1. key shape.
  local k_base got m
  k_base="$("$0" key --profile "$prof" --lockfile "$lock" --recipe "$recipe" --namespace master)"
  if printf '%s\n' "$k_base" | grep -Eq '^conan-release-master-linux-gcc-x86_64-Release-[0-9a-f]{8}-[0-9a-f]{16}-[0-9a-f]{16}-[0-9a-f]{16}$'; then m=0; else m=1; fi
  assert_eq "$m" "0" "key shape: prefix-build-conan-profile-lock-recipe"

  # 2. comment/blank/CRLF edits do not re-key; semantic edits do.
  #    The copy keeps the profile's basename: the key prefix embeds it.
  local profdir="$tmpdir/variant" prof2 k2
  mkdir -p "$profdir"
  prof2="$profdir/linux-gcc-x86_64"
  { printf '# a comment\n'; tr -d '\r' < "$prof"; printf '\n# trailing comment\n'; } > "$prof2"
  k2="$("$0" key --profile "$prof2" --lockfile "$lock" --recipe "$recipe" --namespace master)"
  assert_eq "$k2" "$k_base" "comment/blank/CRLF edits keep the key stable"
  printf '[settings]\nos=Linux\narch=x86_64\ncompiler=gcc\ncompiler.version=14\ncompiler.cppstd=gnu17\nbuild_type=Release\n' > "$prof2"
  k2="$("$0" key --profile "$prof2" --lockfile "$lock" --recipe "$recipe" --namespace master)"
  assert_eq "$([ "$k2" != "$k_base" ] && echo changed || echo same)" "changed" "compiler version drift re-keys"
  printf '{"version":"0.5","requires":["wxwidgets/3.2.11#rev2"]}\n' > "$tmpdir/l.lock"
  k2="$("$0" key --profile "$prof" --lockfile "$tmpdir/l.lock" --recipe "$recipe" --namespace master)"
  assert_eq "$([ "$k2" != "$k_base" ] && echo changed || echo same)" "changed" "lockfile drift re-keys"
  printf 'class R2: pass\n' > "$tmpdir/c.py"
  k2="$("$0" key --profile "$prof" --lockfile "$lock" --recipe "$tmpdir/c.py" --namespace master)"
  assert_eq "$([ "$k2" != "$k_base" ] && echo changed || echo same)" "changed" "recipe drift re-keys"

  # 3. families and namespaces never collide.
  local ci smoke
  ci="$("$0" key --family ci --profile "$prof" --lockfile "$lock" --recipe "$recipe" --namespace master)"
  smoke="$("$0" key --family smoke --profile "$prof" --lockfile "$lock" --recipe "$recipe" --namespace master)"
  assert_eq "$(printf '%s\n%s\n%s\n' "$k_base" "$ci" "$smoke" | sort -u | wc -l | tr -d ' ')" "3" \
    "release/ci/smoke keys are distinct namespaces"
  k2="$("$0" key --profile "$prof" --lockfile "$lock" --recipe "$recipe" --namespace other)"
  assert_eq "$([ "$k2" != "$k_base" ] && echo changed || echo same)" "changed" "namespace drift re-keys"

  # 4. github-env prints the cache-miss diagnostic inputs line.
  local out
  out="$(GITHUB_ENV='' "$0" github-env --profile "$prof" --lockfile "$lock" --recipe "$recipe" --namespace master)"
  assert_eq "$(printf '%s\n' "$out" | grep -c '^inputs: family=release namespace=master profile=linux-gcc-x86_64 build-type=Release')" "1" \
    "github-env prints the inputs diagnostic line"

  # 5. default lock path resolves next to the profile name.
  mkdir -p "$tmpdir/locks"
  cp "$lock" "$tmpdir/locks/linux-gcc-x86_64.lock"
  k2="$("$0" key --profile "$prof" --lockfile-dir "$tmpdir/locks" --recipe "$recipe" --namespace master)"
  assert_eq "$k2" "$k_base" "--lockfile-dir defaults to <dir>/<profile>.lock"

  if [ "$failures" -ne 0 ]; then
    printf 'selftest: %s failure(s)\n' "$failures" >&2
    return 1
  fi
  printf 'selftest: all checks passed\n'
  return 0
}

[ "$#" -gt 0 ] || { usage; exit 2; }
cmd="$1"
shift

if [ "$cmd" = "selftest" ]; then
  run_selftest
  exit $?
fi
if [ "$cmd" = "-h" ] || [ "$cmd" = "--help" ]; then
  usage
  exit 0
fi

family="release"
namespace=""
profile=""
lockfile=""
lockfile_dir="conan/locks"
recipe="conanfile.py"
build_type="Release"
extra_fp="none"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --family) family="$2"; shift 2 ;;
    --namespace) namespace="$2"; shift 2 ;;
    --profile) profile="$2"; shift 2 ;;
    --lockfile) lockfile="$2"; shift 2 ;;
    --lockfile-dir) lockfile_dir="$2"; shift 2 ;;
    --recipe) recipe="$2"; shift 2 ;;
    --build-type) build_type="$2"; shift 2 ;;
    --extra-fingerprint) extra_fp="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

case "$family" in release|ci|smoke) ;; *) die "unsupported family: $family" ;; esac
[ -n "$profile" ] || die "--profile is required"
[ -f "$profile" ] || die "profile not found: $profile"
[ -n "$namespace" ] || namespace="${CONAN_CACHE_NAMESPACE:-master}"
case "$build_type" in Release|Debug) ;; *) die "unsupported build type: $build_type" ;; esac
case "$extra_fp" in
  *[!A-Za-z0-9._-]*) die "unsupported extra fingerprint: $extra_fp" ;;
esac

profile_name="$(basename "$profile")"
if [ -z "$lockfile" ]; then
  lockfile="${lockfile_dir}/${profile_name}.lock"
fi
[ -f "$lockfile" ] || die "lockfile not found: $lockfile (generate with: conan lock create conanfile.py -pr $profile --lockfile-out $lockfile)"
[ -f "$recipe" ] || die "recipe not found: $recipe"

conan_fp="$(conan_fp_hex)"
profile_fp="$(text_hash "$profile" ignore-comments)"
lock_fp="$(text_hash "$lockfile")"
recipe_fp="$(text_hash "$recipe")"

prefix="conan-${family}-${namespace}-${profile_name}"
key="${prefix}-${build_type}-${conan_fp}-${profile_fp}-${lock_fp}-${recipe_fp}"
if [ "$extra_fp" != "none" ]; then
  key="${key}-${extra_fp}"
fi

case "$cmd" in
  key)
    printf '%s\n' "$key"
    ;;
  github-env)
    if [ -n "${GITHUB_ENV:-}" ]; then
      printf 'CONAN_CACHE_KEY=%s\n' "$key" >> "$GITHUB_ENV"
    fi
    printf 'prefix=%s\n' "$prefix"
    printf 'key=%s\n' "$key"
    printf 'inputs: family=%s namespace=%s profile=%s build-type=%s' \
      "$family" "$namespace" "$profile_name" "$build_type"
    printf ' conan=%s profile-fp=%s lock-fp=%s recipe-fp=%s extra-fp=%s' \
      "$conan_fp" "$profile_fp" "$lock_fp" "$recipe_fp" "$extra_fp"
    printf ' profile=%s lockfile=%s recipe=%s\n' "$profile" "$lockfile" "$recipe"
    ;;
  *)
    die "unknown command: $cmd (expected key|github-env|selftest)"
    ;;
esac
