#!/usr/bin/env bash
# =============================================================================
# verify_action_pins.sh -- every `uses: owner/repo@<sha>` pin must exist
# =============================================================================
# Why this exists
# ---------------
# A full-SHA action pin is only a supply-chain guarantee if the SHA really is
# a commit of the repository it claims to be. GitHub cannot validate that when
# a workflow is parsed: a fabricated SHA surfaces later, as
#   "Unable to resolve action `owner/repo@<sha>`, unable to find version"
# in the *first* run that happens to reference it -- which is exactly how
# clear_cache.yml shipped with a non-existent easimon/wipe-cache commit and
# then could never run (issue #152). actionlint does not check this either.
#
# What it does
# ------------
#   * collects every `uses:` reference under a set of directories (default
#     .github/workflows),
#   * skips local (`./...`) and container (`docker://...`) references,
#   * reports tag/branch references as `unpinned` (informational: the caller
#     decides whether floating refs are acceptable for that workflow),
#   * resolves each full-SHA pin against `repos/<owner>/<repo>/commits/<sha>`.
#     For subdirectory actions (`actions/cache/restore@<sha>`) the owning
#     repository is the first two path components.
#
# Exit codes
#   0  every full-SHA pin resolves (unpinned refs only warn)
#   1  at least one pin is missing / resolves to something else, or the API
#      stayed unreachable after the retry budget
#   2  usage error
# =============================================================================
set -euo pipefail

usage() {
  printf '%s\n' \
    'usage: verify_action_pins.sh [--dir DIR]... [--quiet]' \
    '  --dir DIR   directory to scan for `uses:` references (repeatable,' \
    '              default: .github/workflows relative to the repo root)' \
    '  --quiet     only print failures and the final summary' \
    '  requires GH_TOKEN (or GITHUB_TOKEN) in the environment for the API'
}

QUIET=0
DIRS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIRS+=("$2"); shift 2 ;;
    --quiet) QUIET=1; shift 1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'verify_action_pins: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
if [ "${#DIRS[@]}" -eq 0 ]; then
  DIRS=("$(CDPATH='' cd -- "$SCRIPT_DIR/../workflows" && pwd)")
fi

TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
[ -n "$TOKEN" ] || { echo "verify_action_pins: GH_TOKEN/GITHUB_TOKEN is required" >&2; exit 2; }
export GH_TOKEN="$TOKEN"

log() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

# resolve <owner/repo> <sha> -> 0 ok, 1 definitively missing, 2 inconclusive
resolve() {
  local repo="$1" sha="$2" attempt out
  attempt=1
  while [ "$attempt" -le 3 ]; do
    if out=$(gh api "repos/${repo}/commits/${sha}" --jq .sha 2>&1); then
      if [ "$out" = "$sha" ]; then return 0; fi
      printf '    %s@%s resolved to a different object: %s\n' "$repo" "$sha" "$out"
      return 1
    fi
    case "$out" in
      *"No commit found for SHA"*|*"Not Found"*|*'\"status\": 404'*|*'\"status\": 422'*)
        return 1 ;;
    esac
    printf '    transient API error for %s@%s (attempt %d): %s\n' \
      "$repo" "$sha" "$attempt" "$(printf '%s' "$out" | head -1)"
    attempt=$((attempt + 1))
    sleep $((attempt * 2))
  done
  return 2
}

# Only real YAML keys are considered: lines whose first non-space character is
# '#' are documentation, not a workflow reference, so prose mentioning
# `uses: owner/repo@<sha>` inside a comment must not be treated as a pin.
pins=$(grep -rhE 'uses:[[:space:]]+[^[:space:]#]+' "${DIRS[@]}" 2>/dev/null \
  | grep -vE '^[[:space:]]*#' \
  | sed -E 's#.*uses:[[:space:]]+([^[:space:]#]+).*#\1#' | sort -u || true)
if [ -z "$pins" ]; then
  echo "verify_action_pins: no 'uses:' references found under: ${DIRS[*]}" >&2
  exit 2
fi

pinned=0 unpinned=0 missing=0 inconclusive=0

while IFS= read -r pin; do
  [ -n "$pin" ] || continue
  case "$pin" in
    ./*|docker://*) log "skip   $pin (local/container reference)"; continue ;;
  esac
  if [[ ! "$pin" =~ @[0-9a-f]{40}$ ]]; then
    unpinned=$((unpinned + 1))
    printf '[unpinned] %s\n' "$pin"
    continue
  fi
  ref="${pin%@*}"
  sha="${pin##*@}"
  repo=$(printf '%s' "$ref" | cut -d/ -f1,2)
  pinned=$((pinned + 1))
  if resolve "$repo" "$sha"; then
    log "[ok]      $pin"
  else
    rc=$?
    if [ "$rc" -eq 1 ]; then
      missing=$((missing + 1))
      printf '[MISSING] %s  -> commit does not exist in %s\n' "$pin" "$repo"
    else
      inconclusive=$((inconclusive + 1))
      printf '[UNKNOWN] %s  -> could not verify against %s after retries\n' "$pin" "$repo"
    fi
  fi
done <<EOF
$pins
EOF

printf 'verify_action_pins: %d sha pin(s) checked, %d unpinned ref(s), %d missing, %d unverifiable\n' \
  "$pinned" "$unpinned" "$missing" "$inconclusive"

[ "$missing" -eq 0 ] && [ "$inconclusive" -eq 0 ] || exit 1
exit 0
