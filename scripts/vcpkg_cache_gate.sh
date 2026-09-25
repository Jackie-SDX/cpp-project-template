#!/usr/bin/env bash
# =============================================================================
# vcpkg_cache_gate.sh - release cache contract gate (ADR 006)
# =============================================================================
# Decides whether a release job may proceed given the state of the vcpkg
# binary cache for its exact cache key.
#
# The rule (from the operator requirement "a cache miss must never fail fast,
# but a seed we know should exist must be noticed"):
#
#   exact hit                       -> PASS (the saved cache is used)
#   no seed record                  -> PASS + notice (cold start, fork, first
#                                      run after a key change, expired record:
#                                      build slowly and let the producer save)
#   seed record older than --max-age-hours -> PASS + notice (the record no
#                                      longer proves anything)
#   fresh seed record + exact miss  -> FAIL in block mode, WARN in warn mode
#                                      (warmup seeded this exact key recently
#                                      and it is gone: re-run vcpkg-cache-warmup)
#
# Mode selection (overridable with --mode):
#   block : upstream repository and not a pull_request
#   warn  : everything else (forks, PRs, unknown state)
#
# The vcpkg *tool* cache is only ever reported (--tool-hit): a miss costs a
# bootstrap, never a 30 minute rebuild, so it must not block a release.
#
# Usage
#   vcpkg_cache_gate.sh --key K --hit true|false --record-file F
#                       [--tool-hit true|false] [--mode block|warn]
#                       [--max-age-hours 24] [--label text] [--selftest]
#
# Exit codes: 0 pass (warnings allowed), 1 contract violation, 2 usage error.
# =============================================================================
set -euo pipefail

usage() {
  printf '%s\n' \
    'usage: vcpkg_cache_gate.sh --key K --hit true|false --record-file F [--tool-hit true|false]' \
    '                          [--mode block|warn] [--max-age-hours N] [--label text] [--selftest]' \
    '       see the header comment of this file for the decision rules'
}

die() {
  printf 'vcpkg_cache_gate: %s\n' "$*" >&2
  exit 2
}

UPSTREAM_REPOSITORY="Jackie-SDX/cpp-project-template"

key=""
hit=""
tool_hit=""
record_file=""
mode=""
max_age_hours=24
label="vcpkg package cache"
selftest=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --key) key="$2"; shift 2 ;;
    --hit) hit="$2"; shift 2 ;;
    --tool-hit) tool_hit="$2"; shift 2 ;;
    --record-file) record_file="$2"; shift 2 ;;
    --mode) mode="$2"; shift 2 ;;
    --max-age-hours) max_age_hours="$2"; shift 2 ;;
    --label) label="$2"; shift 2 ;;
    --selftest) selftest=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

normalize_bool() {
  case "$1" in
    true|True|TRUE) printf 'true' ;;
    false|False|FALSE) printf 'false' ;;
    "") printf 'false' ;;
    *) die "expected a boolean, got: $1" ;;
  esac
}

if [ "$selftest" -eq 0 ]; then
  [ -n "$key" ] || { usage; exit 2; }
  [ -n "$hit" ] || { usage; exit 2; }
  [ -n "$record_file" ] || { usage; exit 2; }
  hit="$(normalize_bool "$hit")"
  [ -n "$tool_hit" ] && tool_hit="$(normalize_bool "$tool_hit")"
  [ -n "$tool_hit" ] || tool_hit=""
  case "$max_age_hours" in
    ''|*[!0-9]*) die "--max-age-hours must be a non-negative integer" ;;
  esac
fi

if [ -z "$mode" ]; then
  if [ "${GITHUB_REPOSITORY:-}" = "$UPSTREAM_REPOSITORY" ] && [ "${GITHUB_EVENT_NAME:-}" != "pull_request" ]; then
    mode="block"
  else
    mode="warn"
  fi
fi
case "$mode" in block|warn) ;; *) die "--mode must be block or warn" ;; esac

say() {
  # $1 = notice|warning|error|plain, $2 = message
  local level="$1" message="$2"
  case "$level" in
    plain) printf '%s\n' "$message" ;;
    *)
      printf '::%s::%s\n' "$level" "$(printf '%s' "$message" | tr '\n' '%0A')"
      printf '%s: %s\n' "$level" "$message"
      ;;
  esac
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    printf '**%s**: %s\n\n' "$level" "$message" >> "$GITHUB_STEP_SUMMARY"
  fi
}

parse_record() {
  # sets record_key / seeded_at / seeded_at_epoch from $record_file
  record_key=""
  seeded_at=""
  seeded_at_epoch=""
  [ -f "$record_file" ] || return 1
  [ -s "$record_file" ] || return 1
  while IFS='=' read -r field value; do
    case "$field" in
      key) record_key="$value" ;;
      seeded_at) seeded_at="$value" ;;
      seeded_at_epoch) seeded_at_epoch="$value" ;;
    esac
  done < "$record_file"
  [ -n "$record_key" ] || return 1
  return 0
}

now_epoch() {
  date -u +%s
}

tool_report() {
  if [ -n "$tool_hit" ] && [ "$tool_hit" = "false" ]; then
    say warning "vcpkg tool cache miss for ${label}: the job will bootstrap vcpkg (seconds, not minutes). Tool cache hits are informational only and never block."
  fi
}

gate_main() {
  local record_present=0 age_hours="" now recorded_desc
  if parse_record; then
    record_present=1
  fi

  if [ "$hit" = "true" ]; then
    say notice "Exact ${label} hit for ${key}; restoring the saved cache."
    tool_report
    exit 0
  fi

  if [ "$record_present" -eq 0 ]; then
    say notice "No seed record for ${key} (cold start, fork, key change or expired record). Proceeding: this job will build dependencies and save the cache for the next run."
    tool_report
    exit 0
  fi

  if [ "$record_key" != "$key" ]; then
    say notice "Seed record key mismatch (record: ${record_key}, expected: ${key}); treating as no record and proceeding."
    tool_report
    exit 0
  fi

  if [ -z "$seeded_at_epoch" ] || ! [ "$seeded_at_epoch" -eq "$seeded_at_epoch" ] 2>/dev/null; then
    say warning "Seed record for ${key} has no usable timestamp; proceeding without enforcing the cache contract."
    tool_report
    exit 0
  fi

  now="$(now_epoch)"
  age_hours=$(( (now - seeded_at_epoch) / 3600 ))
  if [ "$age_hours" -lt 0 ]; then
    age_hours=0
  fi
  recorded_desc=""
  if [ -n "$seeded_at" ]; then
    recorded_desc=" (recorded at ${seeded_at})"
  fi

  if [ "$age_hours" -gt "$max_age_hours" ]; then
    say notice "Seed record for ${key} is ${age_hours}h old (> ${max_age_hours}h)${recorded_desc}, so it no longer proves the cache exists. Proceeding: build and re-save."
    tool_report
    exit 0
  fi

  # Fresh record + exact miss: a seed we know should exist is missing.
  if [ "$mode" = "block" ]; then
    say error "${label} seed is missing: vcpkg-cache-warmup recorded key ${key} ${age_hours}h ago${recorded_desc} but the exact cache was not found. Re-run 'Release vcpkg cache warmup' and release again; do not ship a cold release build."
    exit 1
  fi
  say warning "${label} seed is missing: a ${age_hours}h-old record exists for ${key} but the exact cache was not found. Continuing in warn mode (pull request/fork)."
  tool_report
  exit 0
}

if [ "$selftest" -eq 1 ]; then
  run_gate_selftest() {
    local failures=0 tmpdir now rc
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' RETURN
    now="$(date -u +%s)"

    check() {
      if [ "$1" = "$2" ]; then
        printf 'ok   - %s\n' "$3"
      else
        printf 'FAIL - %s\n     want: %s\n     got : %s\n' "$3" "$2" "$1"
        failures=$((failures + 1))
      fi
    }

    # 1. exact hit passes everywhere.
    rc=0; GITHUB_REPOSITORY="$UPSTREAM_REPOSITORY" GITHUB_EVENT_NAME=push \
      "$0" --key K1 --hit true --record-file "$tmpdir/missing" >/dev/null 2>&1 || rc=$?
    check "$rc" "0" "exact hit passes in block mode"

    # 2. cold start (no record) passes in block mode.
    rc=0; GITHUB_REPOSITORY="$UPSTREAM_REPOSITORY" GITHUB_EVENT_NAME=push \
      "$0" --key K1 --hit false --record-file "$tmpdir/missing" >/dev/null 2>&1 || rc=$?
    check "$rc" "0" "cold start (no record) never fails fast"

    # 3. fresh record + miss blocks upstream, warns on a PR.
    printf 'key=K1\nseeded_at_epoch=%s\nseeded_at=now\n' "$((now - 3600))" > "$tmpdir/fresh"
    rc=0; GITHUB_REPOSITORY="$UPSTREAM_REPOSITORY" GITHUB_EVENT_NAME=push \
      "$0" --key K1 --hit false --record-file "$tmpdir/fresh" >/dev/null 2>&1 || rc=$?
    check "$rc" "1" "fresh record + exact miss fails the upstream gate"
    rc=0; GITHUB_REPOSITORY="$UPSTREAM_REPOSITORY" GITHUB_EVENT_NAME=push \
      "$0" --key K1 --hit false --record-file "$tmpdir/fresh" --mode warn >/dev/null 2>&1 || rc=$?
    check "$rc" "0" "fresh record + miss only warns in warn mode"
    rc=0; GITHUB_REPOSITORY="someone/fork" GITHUB_EVENT_NAME=push \
      "$0" --key K1 --hit false --record-file "$tmpdir/fresh" >/dev/null 2>&1 || rc=$?
    check "$rc" "0" "forks default to warn mode"
    rc=0; GITHUB_REPOSITORY="$UPSTREAM_REPOSITORY" GITHUB_EVENT_NAME=pull_request \
      "$0" --key K1 --hit false --record-file "$tmpdir/fresh" >/dev/null 2>&1 || rc=$?
    check "$rc" "0" "pull requests default to warn mode"

    # 4. stale record (older than the window) passes.
    printf 'key=K1\nseeded_at_epoch=%s\n' "$((now - 96 * 3600))" > "$tmpdir/stale"
    rc=0; GITHUB_REPOSITORY="$UPSTREAM_REPOSITORY" GITHUB_EVENT_NAME=push \
      "$0" --key K1 --hit false --record-file "$tmpdir/stale" >/dev/null 2>&1 || rc=$?
    check "$rc" "0" "stale record (>24h) is treated as unknown, not as a violation"

    # 5. record for another key is ignored.
    printf 'key=OTHER\nseeded_at_epoch=%s\n' "$((now - 3600))" > "$tmpdir/other"
    rc=0; GITHUB_REPOSITORY="$UPSTREAM_REPOSITORY" GITHUB_EVENT_NAME=push \
      "$0" --key K1 --hit false --record-file "$tmpdir/other" >/dev/null 2>&1 || rc=$?
    check "$rc" "0" "record for a different key does not gate this key"

    # 6. a corrupt record never blocks.
    printf 'garbage\n' > "$tmpdir/bad"
    rc=0; GITHUB_REPOSITORY="$UPSTREAM_REPOSITORY" GITHUB_EVENT_NAME=push \
      "$0" --key K1 --hit false --record-file "$tmpdir/bad" >/dev/null 2>&1 || rc=$?
    check "$rc" "0" "corrupt record never blocks"

    # 7. tool cache miss never blocks.
    printf 'key=K1\nseeded_at_epoch=%s\n' "$((now - 3600))" > "$tmpdir/fresh2"
    rc=0; GITHUB_REPOSITORY="$UPSTREAM_REPOSITORY" GITHUB_EVENT_NAME=push \
      "$0" --key K1 --hit true --tool-hit false --record-file "$tmpdir/fresh2" >/dev/null 2>&1 || rc=$?
    check "$rc" "0" "tool cache miss never blocks an exact package hit"
    rc=0; GITHUB_REPOSITORY="$UPSTREAM_REPOSITORY" GITHUB_EVENT_NAME=push \
      "$0" --key K1 --hit false --tool-hit false --record-file "$tmpdir/fresh2" >/dev/null 2>&1 || rc=$?
    check "$rc" "1" "tool cache miss does not weaken the package contract"

    # 8. usage errors.
    rc=0; "$0" --key K1 >/dev/null 2>&1 || rc=$?
    check "$rc" "2" "missing required arguments exit 2"
    rc=0; "$0" --key K1 --hit maybe --record-file "$tmpdir/missing" >/dev/null 2>&1 || rc=$?
    check "$rc" "2" "invalid --hit exits 2"
    rc=0; "$0" --key K1 --hit false --record-file "$tmpdir/missing" --mode nope >/dev/null 2>&1 || rc=$?
    check "$rc" "2" "invalid --mode exits 2"

    if [ "$failures" -ne 0 ]; then
      printf 'selftest: %s failure(s)\n' "$failures" >&2
      return 1
    fi
    printf 'selftest: all checks passed\n'
    return 0
  }
  run_gate_selftest
  exit $?
fi

gate_main
