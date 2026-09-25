#!/usr/bin/env bash
# =============================================================================
# vcpkg_cache_key.sh - single source of truth for the vcpkg binary-cache key
# contract (ADR 006).
# =============================================================================
# Why this exists
# ---------------
# The workflows used to build their cache keys inline with five different
# layouts (release/warmup, CI, both packaging smokes, the experimental
# matrix), so a cache seeded by one workflow could never satisfy another while
# a single key could be written by producers with different ABI inputs. The
# result was "exact cache hit, 0 packages usable" and 12-35 minute Windows
# legs that never self-healed (the save step is skipped on an exact hit).
#
# Every key/prefix/restore-key now comes from this script:
#
#   key           = <family_prefix>-<build_type>-<image_fp>-<vcpkg_fp>-
#                   <triplets_fp>-<extra_fp>-<manifest_hash>
#   family_prefix = <family>[-<toolchain>]-<namespace>-<arch>
#
#   family_prefix values
#     release family (release.yml + vcpkg-cache-warmup.yml):
#         windows[-mingw|-llvm]-<namespace>-<arch>
#     CI family (ci.yml):
#         windows-ci[-mingw|-llvm]-<namespace>-<arch>
#     packaging smokes:
#         windows-smoke[-mingw|-llvm]-<namespace>-<arch>
#         windows-arm64-smoke-<namespace>-<arch>
#     experimental matrix:
#         windows-exp[-mingw|-llvm]-<namespace>-<arch>
#
#   image_fp     = sha256(ImageVersion) first 8 chars       (runner image drift:
#                                                            VS toolset, MSYS2, LLVM)
#   vcpkg_fp     = sha256(VCPKG_GIT_REF) first 8 chars      (ports revision)
#   triplets_fp  = sha256(MY_VCPKG_TRIPLETS_COMMIT) first 8 chars (overlay triplets)
#   extra_fp     = --extra-fingerprint value or "none"      (e.g. CI compiler hash)
#   manifest_hash= sha256(sha256(vcpkg.json with CRLF folded to LF))
#
# A family owns its keys: producers from different families never write the
# same key, so they cannot poison each other. That is what makes
# "save only when the exact key is missing" safe.
#
# restore-keys always start with "<family_prefix>-<build_type>-" (which also
# matches every pre-ADR-006 key for that family/toolchain/arch/build type) and
# then list the remaining legacy layouts this family used to write, so the
# change re-uses existing warm caches instead of going cold.
#
# Usage
# -----
#   vcpkg_cache_key.sh hash-manifest <file>
#   vcpkg_cache_key.sh prefix       <options>
#   vcpkg_cache_key.sh key          <options>
#   vcpkg_cache_key.sh restore-keys <options>
#   vcpkg_cache_key.sh record-key   --key <key> [--run-id <id>]
#   vcpkg_cache_key.sh github-env   <options>
#   vcpkg_cache_key.sh selftest
#
# Options
#   --family            release|ci|smoke|arm64-smoke|experimental (default: release)
#   --toolchain         msvc|mingw|llvm|clangarm64                (required)
#   --arch              x64|x86|arm64                             (required)
#   --build-type        Release|Debug                             (default: Release)
#   --namespace         cache namespace token (default: $VCPKG_CACHE_NAMESPACE or master)
#   --manifest          path to vcpkg.json                        (required for key)
#   --vcpkg-ref         VCPKG_GIT_REF value                       (default: env)
#   --triplets-ref      MY_VCPKG_TRIPLETS_COMMIT value            (default: env)
#   --extra-fingerprint extra ABI fingerprint segment             (default: none)
#   --run-id            run id for record-key                     (default: $GITHUB_RUN_ID)
#
# github-env writes VCPKG_CACHE_PREFIX, VCPKG_CACHE_KEY and
# VCPKG_CACHE_RESTORE_KEYS (multiline) to $GITHUB_ENV when that file is set.
#
# Exits 2 on usage errors so a bad contract cannot silently produce a key.
# =============================================================================
set -euo pipefail

usage() {
  printf '%s\n' \
    'usage: vcpkg_cache_key.sh <hash-manifest|prefix|key|restore-keys|record-key|github-env|selftest> [options]' \
    '       see the header comment of this file for the option list'
}

die() {
  printf 'vcpkg_cache_key: %s\n' "$*" >&2
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

# hex string -> raw bytes (for the outer hash of the manifest digest)
hex_to_raw() {
  if command -v xxd >/dev/null 2>&1; then
    xxd -r -p
  elif command -v perl >/dev/null 2>&1; then
    perl -e 'local $/; $_=<STDIN>; s/\s+//g; print pack("H*", $_)'
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys,binascii; sys.stdout.buffer.write(binascii.unhexlify(sys.stdin.read().replace(chr(10),"").replace(" ","")))'
  else
    die "no xxd/perl/python3 available to decode the manifest digest"
  fi
}

short() {
  # first N chars of a hex digest / ref; "unknown" stays "unknown"
  printf '%s' "$1" | cut -c1-"${2:-8}"
}

# GitHub's hashFiles() hashes sha256(raw file bytes) for every match and then
# hashes the concatenation of those digests. Fold CRLF first so the value is
# independent of the checkout's line-ending policy (actions/checkout leaves
# core.autocrlf at the runner default on Windows, so hashFiles('project/
# vcpkg.json') returns a different value there than on Linux).
manifest_hash() {
  local file="$1"
  [ -f "$file" ] || die "manifest not found: $file"
  local normalized inner
  normalized="$(mktemp)"
  tr -d '\r' < "$file" > "$normalized"
  inner="$(sha256_file "$normalized")"
  rm -f "$normalized"
  printf '%s' "$(printf '%s' "$inner" | hex_to_raw | sha256_hex)"
}

run_selftest() {
  local failures=0 tmpdir tmpfile got want m
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  # Canonical inputs for every key produced by this test.
  export ImageVersion="20260920.314.1"
  export VCPKG_GIT_REF="e0a6b8572cf0ac716fdc11466522cf744e97e0bd"
  export MY_VCPKG_TRIPLETS_COMMIT="e5f3f2d06430fa475feccbb34a5d61023807b854"
  export VCPKG_CACHE_NAMESPACE="master"

  assert_eq() {
    if [ "$1" = "$2" ]; then
      printf 'ok   - %s\n' "$3"
    else
      printf 'FAIL - %s\n     want: %s\n     got : %s\n' "$3" "$2" "$1"
      failures=$((failures + 1))
    fi
  }

  # 1. manifest hashing is stable and independent of line endings.
  tmpfile="$tmpdir/vcpkg.json"
  printf '{"name":"x","version-string":"1"}\n' > "$tmpfile"
  got="$(manifest_hash "$tmpfile")"
  want="4336481e1401ee672a4775b26111693ab243f2eb8a41414c93cb91d9528b7287"
  assert_eq "$got" "$want" "manifest_hash matches the reference double-sha256"
  printf '{"name":"x","version-string":"1"}\r\n' > "$tmpfile"
  got="$(manifest_hash "$tmpfile")"
  assert_eq "$got" "$want" "manifest_hash folds CRLF to LF"
  assert_eq "$(manifest_hash "$tmpfile")" "$want" "manifest_hash is deterministic"

  # 2. key shape.
  printf '{"name":"x","version-string":"1"}\n' > "$tmpfile"
  got="$("$0" key --family release --toolchain msvc --arch x64 --build-type Release --manifest "$tmpfile")"
  if printf '%s\n' "$got" | grep -Eq '^windows-master-x64-Release-[0-9a-f]{8}-[0-9a-f]{8}-[0-9a-f]{8}-none-[0-9a-f]{64}$'; then m=0; else m=1; fi
  assert_eq "$m" "0" "release key shape: prefix-build-fp-vcpkg-triplets-extra-manifest"

  got="$("$0" key --family ci --toolchain msvc --arch x64 --build-type Debug --manifest "$tmpfile")"
  if printf '%s\n' "$got" | grep -Eq '^windows-ci-master-x64-Debug-[0-9a-f]{8}-[0-9a-f]{8}-[0-9a-f]{8}-none-[0-9a-f]{64}$'; then m=0; else m=1; fi
  assert_eq "$m" "0" "ci keys live in their own namespace"

  # 3. image / ref / triplet / manifest drift all re-key, prefix does not.
  local k_base k_other
  k_base="$("$0" key --family release --toolchain msvc --arch x64 --build-type Release --manifest "$tmpfile")"
  k_other="$(ImageVersion="20260801.1.1" "$0" key --family release --toolchain msvc --arch x64 --build-type Release --manifest "$tmpfile")"
  assert_eq "$([ "$k_base" != "$k_other" ] && echo changed || echo same)" "changed" "runner image drift re-keys"
  k_other="$(VCPKG_GIT_REF=deadbeef "$0" key --family release --toolchain msvc --arch x64 --build-type Release --manifest "$tmpfile")"
  assert_eq "$([ "$k_base" != "$k_other" ] && echo changed || echo same)" "changed" "vcpkg ref drift re-keys"
  k_other="$(MY_VCPKG_TRIPLETS_COMMIT=deadbeef "$0" key --family release --toolchain msvc --arch x64 --build-type Release --manifest "$tmpfile")"
  assert_eq "$([ "$k_base" != "$k_other" ] && echo changed || echo same)" "changed" "triplet ref drift re-keys"
  printf '{"name":"y"}\n' > "$tmpdir/other.json"
  k_other="$("$0" key --family release --toolchain msvc --arch x64 --build-type Release --manifest "$tmpdir/other.json")"
  assert_eq "$([ "$k_base" != "$k_other" ] && echo changed || echo same)" "changed" "manifest drift re-keys"
  k_other="$("$0" key --family release --toolchain msvc --arch x64 --build-type Release --manifest "$tmpfile" --extra-fingerprint 0123456789abcdef)"
  assert_eq "$([ "$k_base" != "$k_other" ] && echo changed || echo same)" "changed" "extra fingerprint re-keys"
  assert_eq "$("$0" prefix --family release --toolchain msvc --arch x64)" \
    "$(ImageVersion="20250101.1.1" "$0" prefix --family release --toolchain msvc --arch x64)" \
    "prefix is stable across drift (legacy restore keeps working)"

  # 4. restore-keys: primary first, legacy prefixes present, no duplicates.
  local keys
  keys="$("$0" restore-keys --family ci --toolchain msvc --arch x64 --build-type Release --manifest "$tmpfile")"
  assert_eq "$(printf '%s\n' "$keys" | head -1)" "windows-ci-master-x64-Release-" "primary restore key is the new prefix"
  if printf '%s\n' "$keys" | grep -qx 'windows-master-x64-Release-'; then m=0; else m=1; fi
  assert_eq "$m" "0" "ci keeps the pre-ADR-006 legacy prefix as a fallback"
  assert_eq "$(printf '%s\n' "$keys" | sort | uniq -d | wc -l | tr -d ' ')" "0" "restore keys are de-duplicated"
  keys="$("$0" restore-keys --family release --toolchain llvm --arch x64 --build-type Release --manifest "$tmpfile")"
  if printf '%s\n' "$keys" | grep -qx "windows-llvm-master-${MY_VCPKG_TRIPLETS_COMMIT}-x64-Release-"; then m=0; else m=1; fi
  assert_eq "$m" "0" "release LLVM keeps the legacy triplets-in-the-middle prefix"
  keys="$("$0" restore-keys --family release --toolchain llvm --arch arm64 --build-type Release --manifest "$tmpfile")"
  if printf '%s\n' "$keys" | grep -qx 'windows-master-arm64-Release-'; then m=0; else m=1; fi
  assert_eq "$m" "0" "release LLVM ARM64 keeps the pre-ADR-006 shared MSVC ARM64 prefix"
  keys="$("$0" restore-keys --family release --toolchain msvc --arch x64 --build-type Debug --manifest "$tmpfile")"
  if printf '%s\n' "$keys" | grep -qx 'windows-master-x64-Debug-'; then m=0; else m=1; fi
  assert_eq "$m" "0" "release MSVC Debug uses the Debug-specific legacy prefix"

  # 5. families never collide.
  local rel ci smk arm
  rel="$(ImageVersion="20260920.314.1" "$0" key --family release --toolchain msvc --arch x64 --build-type Release --manifest "$tmpfile")"
  ci="$(ImageVersion="20260920.314.1" "$0" key --family ci --toolchain msvc --arch x64 --build-type Release --manifest "$tmpfile")"
  smk="$(ImageVersion="20260920.314.1" "$0" key --family smoke --toolchain mingw --arch x64 --build-type Release --manifest "$tmpfile")"
  arm="$(ImageVersion="20260920.314.1" "$0" key --family arm64-smoke --toolchain msvc --arch arm64 --build-type Release --manifest "$tmpfile")"
  assert_eq "$(printf '%s\n%s\n%s\n%s\n' "$rel" "$ci" "$smk" "$arm" | sort -u | wc -l | tr -d ' ')" "4" \
    "release/ci/smoke/arm64-smoke keys are distinct namespaces"

  # 6. record keys are unique per run and scoped to the canonical key.
  assert_eq "$("$0" record-key --key "$rel" --run-id 42)" "vcpkg-seed-${rel}-42" "record key embeds the canonical key and run id"

  # 7. the experimental family restores its old bags per matrix leg
  #    (old cache_id == windows-<toolchain>-<arch>), never pool-wide.
  keys="$("$0" restore-keys --family experimental --toolchain llvm --arch x64 --build-type Release --manifest "$tmpfile")"
  assert_eq "$(printf '%s\n' "$keys" | sed -n '2p')" \
    "vcpkg-experimental-windows-llvm-x64-" \
    "experimental legacy restore key targets its own matrix leg"
  keys_mingw="$("$0" restore-keys --family experimental --toolchain mingw --arch x64 --build-type Release --manifest "$tmpfile")"
  assert_eq "$([ "$keys" != "$keys_mingw" ] && echo different || echo same)" "different" \
    "experimental restore keys differ per matrix leg"

  # 8. github-env prints the cache-miss diagnostic inputs line.
  out="$(GITHUB_ENV='' "$0" github-env --family release --toolchain msvc --arch x64 --manifest "$tmpfile")"
  assert_eq "$(printf '%s\n' "$out" | grep -c '^inputs: family=release toolchain=msvc arch=x64 build-type=Release')" "1" \
    "github-env prints the inputs diagnostic line"

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
toolchain=""
arch=""
build_type="Release"
namespace=""
manifest=""
vcpkg_ref=""
triplets_ref=""
extra_fp="none"
run_id="${GITHUB_RUN_ID:-0}"
key_for_record=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --family) family="$2"; shift 2 ;;
    --toolchain) toolchain="$2"; shift 2 ;;
    --arch) arch="$2"; shift 2 ;;
    --build-type) build_type="$2"; shift 2 ;;
    --namespace) namespace="$2"; shift 2 ;;
    --manifest) manifest="$2"; shift 2 ;;
    --vcpkg-ref) vcpkg_ref="$2"; shift 2 ;;
    --triplets-ref) triplets_ref="$2"; shift 2 ;;
    --extra-fingerprint) extra_fp="$2"; shift 2 ;;
    --run-id) run_id="$2"; shift 2 ;;
    --key) key_for_record="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      if [ "$cmd" = "hash-manifest" ] && [ -z "$manifest" ]; then
        manifest="$1"
        shift
      else
        die "unknown argument: $1"
      fi
      ;;
  esac
done

[ -n "$namespace" ] || namespace="${VCPKG_CACHE_NAMESPACE:-master}"
[ -n "$vcpkg_ref" ] || vcpkg_ref="${VCPKG_GIT_REF:-unknown}"
[ -n "$triplets_ref" ] || triplets_ref="${MY_VCPKG_TRIPLETS_COMMIT:-unknown}"
[ -n "$extra_fp" ] || extra_fp="none"
case "$extra_fp" in
  *[!A-Za-z0-9._-]*) die "unsupported extra fingerprint: $extra_fp" ;;
esac

# Commands that do not need the family/toolchain/arch contract.
case "$cmd" in
  hash-manifest)
    [ -n "$manifest" ] || manifest="${1:-}"
    [ -n "$manifest" ] || die "hash-manifest requires a file"
    manifest_hash "$manifest"
    exit 0
    ;;
  record-key)
    [ -n "$key_for_record" ] || die "record-key requires --key"
    printf 'vcpkg-seed-%s-%s\n' "$key_for_record" "$run_id"
    exit 0
    ;;
esac

case "$family" in
  release|ci|smoke|arm64-smoke|experimental) ;;
  *) die "unsupported family: $family" ;;
esac
[ -n "$toolchain" ] || die "--toolchain is required"
[ -n "$arch" ] || die "--arch is required"
case "$toolchain" in msvc|mingw|llvm|clangarm64) ;; *) die "unsupported toolchain: $toolchain" ;; esac
case "$arch" in x64|x86|arm64) ;; *) die "unsupported arch: $arch" ;; esac
case "$build_type" in Release|Debug) ;; *) die "unsupported build type: $build_type" ;; esac

# toolchain token inside the family prefix (msvc carries no token so the
# pre-ADR-006 release prefix keeps matching for a prefix restore).
toolchain_token=""
case "$toolchain" in
  mingw) toolchain_token="mingw-" ;;
  llvm) toolchain_token="llvm-" ;;
  clangarm64) toolchain_token="clangarm64-" ;;
  msvc) toolchain_token="" ;;
esac

case "$family" in
  release) family_head="windows" ;;
  ci) family_head="windows-ci" ;;
  smoke) family_head="windows-smoke" ;;
  arm64-smoke) family_head="windows-arm64-smoke" ;;
  experimental) family_head="windows-exp" ;;
esac

image_version="${ImageVersion:-unknown}"
image_fp="$(printf '%s' "$image_version" | sha256_hex | cut -c1-8)"
vcpkg_fp="$(short "$vcpkg_ref" 8)"
triplets_fp="$(short "$triplets_ref" 8)"

prefix="${family_head}-${toolchain_token}${namespace}-${arch}"
key="${prefix}-${build_type}-${image_fp}-${vcpkg_fp}-${triplets_fp}-${extra_fp}"

case "$cmd" in
  prefix)
    printf '%s\n' "$prefix"
    exit 0
    ;;
esac

if [ -n "$manifest" ]; then
  key="${key}-$(manifest_hash "$manifest")"
elif [ "$cmd" = "key" ] || [ "$cmd" = "github-env" ]; then
  die "--manifest is required for $cmd"
fi

# Legacy layouts this family used to write (ADR 006), most specific first.
legacy_restore_keys() {
  case "$family" in
    release)
      case "$toolchain" in
        llvm)
          # pre-ADR-006 release layout put the triplets ref before the arch.
          printf '%s\n' "windows-llvm-${namespace}-${triplets_ref}-${arch}-${build_type}-"
          if [ "$arch" = "arm64" ]; then
            # pre-ADR-006 LLVM ARM64 shared the MSVC ARM64 key (no dedicated
            # seed exists); keep restoring it so expanded-package builds still
            # find the arm64 cache content instead of starting from nothing.
            printf '%s\n' "windows-${namespace}-arm64-${build_type}-"
          fi
          ;;
      esac
      ;;
    ci)
      case "$toolchain" in
        msvc)
          printf '%s\n' "windows-${namespace}-${arch}-${build_type}-"
          ;;
        mingw)
          printf '%s\n' "windows-mingw-${namespace}-${arch}-${build_type}-"
          ;;
        llvm)
          printf '%s\n' "windows-llvm-${namespace}-${arch}-${build_type}-"
          ;;
      esac
      ;;
    smoke)
      case "$toolchain" in
        mingw)
          # best effort: the release/warmup MinGW seed first (identical inputs
          # once the smoke pins the same vcpkg/triplet refs), then the smoke's
          # own pre-ADR-006 private namespace.
          printf '%s\n' "windows-mingw-${namespace}-${arch}-${build_type}-"
          printf '%s\n' "windows-a1cae005c39be7b18ba319fced856b68d7276271-x64-mingw-dynamic-${build_type}-"
          ;;
      esac
      ;;
    arm64-smoke)
      printf '%s\n' "windows-arm64-"
      ;;
    experimental)
      # The old experimental layout embedded the matrix cache_id, which is
      # exactly "windows-<toolchain>-<arch>". Restore per leg, not pool-wide:
      # "vcpkg-experimental-" alone would happily restore another
      # architecture's bag and rebuild everything anyway.
      printf '%s\n' "vcpkg-experimental-windows-${toolchain}-${arch}-"
      ;;
  esac
}

emit_restore_keys() {
  printf '%s-\n' "${prefix}-${build_type}"
  legacy_restore_keys | while IFS= read -r legacy; do
    if [ -z "$legacy" ] || [ "$legacy" = "${prefix}-${build_type}-" ]; then
      continue
    fi
    printf '%s\n' "$legacy"
  done | awk '!seen[$0]++'
}

case "$cmd" in
  key)
    printf '%s\n' "$key"
    ;;
  restore-keys)
    emit_restore_keys
    ;;
  github-env)
    [ -n "$manifest" ] || die "--manifest is required for github-env"
    if [ -n "${GITHUB_ENV:-}" ]; then
      {
        printf 'VCPKG_CACHE_PREFIX=%s\n' "$prefix"
        printf 'VCPKG_CACHE_KEY=%s\n' "$key"
        printf 'VCPKG_CACHE_RESTORE_KEYS<<__VCPKG_CACHE_RESTORE_KEYS_EOF__\n'
        emit_restore_keys
        printf '__VCPKG_CACHE_RESTORE_KEYS_EOF__\n'
      } >> "$GITHUB_ENV"
    fi
    printf 'prefix=%s\n' "$prefix"
    printf 'key=%s\n' "$key"
    # Cache-miss diagnostics (TASKS "explain why a cache was invalidated"):
    # diff the inputs line of two runs to see exactly which segment moved.
    printf 'inputs: family=%s toolchain=%s arch=%s build-type=%s namespace=%s' \
      "$family" "$toolchain" "$arch" "$build_type" "$namespace"
    printf ' image=%s image-fp=%s vcpkg-ref=%s triplets-ref=%s extra-fp=%s manifest=%s\n' \
      "$image_version" "$image_fp" "$vcpkg_ref" "$triplets_ref" "$extra_fp" "$manifest"
    printf 'restore-keys:\n'
    emit_restore_keys | sed 's/^/  /'
    ;;
  *)
    die "unknown command: $cmd (expected hash-manifest|prefix|key|restore-keys|record-key|github-env|selftest)"
    ;;
esac
