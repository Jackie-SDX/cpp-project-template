#!/usr/bin/env bash
# =============================================================================
# conan_cache_artifact.sh - ref-independent second tier for the Conan cache
# =============================================================================
# Why this exists
# ---------------
# GitHub's Actions cache is *ref scoped*: a run only restores entries saved
# for its own ref (branch/tag) plus the default branch. A cache produced by a
# successful job on one branch is therefore invisible to every sibling branch
# and to every tag, which is exactly the failure reported in issue #152
# (Windows package job failed -> re-run -> one hour of Conan rebuilds because
# the tag run could not see the branch's cache at all).
#
# Actions *artifacts* are repository scoped instead: any run may list and
# download them. This script stores the trimmed Conan home as one artifact
# per cache key, so a key that has ever been produced by a successful job on
# ANY ref becomes restorable from any other ref.
#
# Tier contract (enforced by the workflows, see conan.yml / release.yml)
# ---------------------------------------------------------------------
#   1. actions/cache exact key     -> CONAN_CACHE_RESTORE_SOURCE=exact
#   2. this script (exact key, repo wide) -> source=artifact:<id>
#   3. actions/cache restore-keys (prefix of the same profile) -> prefix:<key>
#   4. nothing matched             -> cold
# The tiers are mutually exclusive: two different homes must never be merged,
# because a Conan home carries a sqlite metadata index at its root.
#
# Safety rules
# ------------
#   * Every subcommand is fail-soft: it reports a miss instead of failing the
#     job, so the cache tier can never break a build or a release.
#   * Only artifacts produced by runs of THIS repository from non-fork refs
#     are trusted (head_repository_id must equal repository_id), and expired
#     artifacts are ignored.
#   * An artifact is uploaded at most once per key: the upload is skipped as
#     soon as a trusted artifact with that key's name exists, so a warm run
#     costs one API call.
#
# Environment
# -----------
#   CONAN_CACHE_KEY       required key (scripts/conan_cache_key.sh)
#   CONAN_HOME            Conan home to pack/restore (default: <pwd>/.conan2)
#   GITHUB_REPOSITORY     owner/name (required for API subcommands)
#   GH_TOKEN|GITHUB_TOKEN token for the REST API (required for API subcommands)
#   RUNNER_TEMP           scratch space (default: TMPDIR|/tmp)
#   GITHUB_OUTPUT/GITHUB_ENV/GITHUB_STEP_SUMMARY  optional, written when set
#
# Usage
# -----
#   conan_cache_artifact.sh name                 print the artifact name
#   conan_cache_artifact.sh exists                probe for a trusted artifact
#   conan_cache_artifact.sh restore               restore home from the artifact
#   conan_cache_artifact.sh prepare               pack home + decide upload
#   conan_cache_artifact.sh source                classify the restore result
#   conan_cache_artifact.sh selftest              offline test suite
#
# `source` reads the tier evidence from the environment (CONAN_EXACT_HIT,
# CONAN_ARTIFACT_HIT, CONAN_ARTIFACT_ID, CONAN_PREFIX_KEY) because step
# outputs are only reachable through env, not through argv, in the workflows.
#
# Exits 0 on every miss/error by design (fail-soft), 1 only when the offline
# selftest fails.
# =============================================================================
set -euo pipefail

usage() {
  printf '%s\n' \
    'usage: conan_cache_artifact.sh <name|exists|restore|prepare|source|selftest>' \
    '       see the header comment of this file for the inputs of each command'
}

die() {
  printf 'conan_cache_artifact: %s\n' "$*" >&2
  exit 1
}

info() {
  printf 'conan_cache_artifact: %s\n' "$*"
}

warn() {
  printf 'conan_cache_artifact: WARNING: %s\n' "$*" >&2
}

# Append one machine readable line to $GITHUB_OUTPUT (and echo it to the log).
out() {
  [ -n "${GITHUB_OUTPUT:-}" ] && printf '%s\n' "$1" >> "$GITHUB_OUTPUT"
  printf '%s\n' "$1"
  return 0
}

artifact_name() {
  printf 'conan-bin-%s\n' "$1"
}

conan_home() {
  printf '%s\n' "${CONAN_HOME:-${PWD}/.conan2}"
}

scratch_dir() {
  printf '%s\n' "${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
}

python_bin() {
  command -v python3 || command -v python || true
}

require_key() {
  [ -n "${CONAN_CACHE_KEY:-}" ] || die "CONAN_CACHE_KEY is not set"
}

# GET $API_BASE/$1 with the Accept header of $2 (default: JSON).
api_get() {
  local token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  [ -n "$token" ] || { warn "no GH_TOKEN/GITHUB_TOKEN in the environment"; return 1; }
  [ -n "${GITHUB_REPOSITORY:-}" ] || { warn "GITHUB_REPOSITORY is not set"; return 1; }
  curl -fsS -L \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: ${2:-application/vnd.github+json}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/${1}"
}

# The selector runs on stdin (a raw artifacts-list JSON body), so the program
# itself is passed through -c: `python -` would swallow stdin as the program.
SELECTOR_PROGRAM="$(cat <<'PY'
import json, os, sys

name = os.environ["ARTIFACT_NAME"]
out_path = os.environ.get("GITHUB_OUTPUT") or ""
raw = sys.stdin.read()
try:
    artifacts = json.loads(raw).get("artifacts") or []
except Exception as exc:                      # fail-soft: treat as a miss
    print("exists=false")
    print("artifact_id=")
    print("artifact_error=%s" % exc)
    if out_path:
        with open(out_path, "a", encoding="utf-8") as fh:
            fh.write("exists=false\nartifact_id=\n")
    raise SystemExit(0)

candidates = []
for art in artifacts:
    if art.get("name") != name or art.get("expired"):
        continue
    run = art.get("workflow_run") or {}
    repo_id, head_id = run.get("repository_id"), run.get("head_repository_id")
    if repo_id is not None and head_id is not None and repo_id != head_id:
        continue                               # pull request from a fork
    if str(run.get("head_branch") or "").startswith("refs/pull/"):
        continue
    candidates.append(art)

candidates.sort(key=lambda a: a.get("created_at") or "", reverse=True)
lines = ["exists=%s" % ("true" if candidates else "false")]
if candidates:
    best = candidates[0]
    lines.append("artifact_id=%s" % best.get("id"))
    lines.append("artifact_size=%s" % best.get("size_in_bytes", 0))
    lines.append("artifact_created_at=%s" % best.get("created_at", ""))
else:
    lines.append("artifact_id=")
lines.append("artifact_candidates=%d" % len(candidates))
sys.stdout.write("\n".join(lines) + "\n")
if out_path:
    with open(out_path, "a", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
PY
)"

# select_artifact <name>  (artifacts-list JSON on stdin) -> prints and appends
# to $GITHUB_OUTPUT the exists=/artifact_* lines. Keeps the newest non-expired
# artifact of this repository's own non-fork runs whose name matches <name>.
select_artifact() {
  local name="${1:?artifact name}" py
  py="$(python_bin)"
  if [ -z "$py" ]; then
    warn "python interpreter not found; artifact tier disabled"
    printf 'exists=false\nartifact_id=\n'
    return 0
  fi
  ARTIFACT_NAME="$name" "$py" -c "$SELECTOR_PROGRAM"
}

# Query the artifacts API for the current key and export ART_EXISTS/ART_ID.
probe_artifact() {
  local name resp
  name="$(artifact_name "$CONAN_CACHE_KEY")"
  ART_EXISTS="false"
  ART_ID=""
  if ! resp="$(api_get "actions/artifacts?name=${name}&per_page=100")"; then
    warn "artifacts list query failed; treating it as a miss"
    return 0
  fi
  local selected
  selected="$(printf '%s' "$resp" | select_artifact "$name" || true)"
  ART_EXISTS="$(printf '%s\n' "$selected" | sed -n 's/^exists=//p' | head -1)"
  ART_ID="$(printf '%s\n' "$selected" | sed -n 's/^artifact_id=//p' | head -1)"
  [ -n "$ART_EXISTS" ] || ART_EXISTS="false"
  printf '%s\n' "$selected" | sed 's/^/conan_cache_artifact: /' >&2
  return 0
}

cmd_name() {
  require_key
  artifact_name "$CONAN_CACHE_KEY"
}

cmd_exists() {
  require_key
  probe_artifact
  out "exists=${ART_EXISTS}"
  out "artifact_id=${ART_ID}"
  info "key=${CONAN_CACHE_KEY} trusted_artifact=${ART_EXISTS} id=${ART_ID:-<none>}"
}

cmd_restore() {
  require_key
  probe_artifact
  if [ "$ART_EXISTS" != "true" ] || [ -z "$ART_ID" ]; then
    info "cross-ref artifact miss for $(artifact_name "$CONAN_CACHE_KEY")"
    out "hit=false"
    out "artifact_id="
    return 0
  fi

  local work zipball tarball home created_home=""
  work="$(mktemp -d "$(scratch_dir)/conan-artifact-XXXXXX")"
  home="$(conan_home)"
  zipball="${work}/entry.zip"
  # shellcheck disable=SC2064
  trap "rm -rf '${work}'" RETURN

  if ! api_get "actions/artifacts/${ART_ID}/zip" "application/vnd.github+json" > "$zipball"; then
    warn "artifact ${ART_ID} download failed"
    out "hit=false"
    out "artifact_id="
    return 0
  fi
  if ! unzip -q -o "$zipball" -d "$work/extracted"; then
    warn "artifact ${ART_ID} could not be unpacked"
    out "hit=false"
    out "artifact_id="
    return 0
  fi
  tarball="$(find "$work/extracted" -name '*.tar.gz' -type f -print -quit)"
  if [ -z "$tarball" ]; then
    warn "artifact ${ART_ID} contains no conan home tarball"
    out "hit=false"
    out "artifact_id="
    return 0
  fi

  if [ ! -d "$home" ]; then
    mkdir -p "$home"
    created_home="$home"
  fi
  if ! tar -xzf "$tarball" -C "$home"; then
    warn "conan home restore failed; discarding the partial home"
    [ -n "$created_home" ] && rm -rf "$created_home"
    out "hit=false"
    out "artifact_id="
    return 0
  fi
  if [ ! -d "$home/p" ]; then
    warn "restored home has no p/ directory; discarding it"
    rm -rf "$home"
    out "hit=false"
    out "artifact_id="
    return 0
  fi
  info "restored conan home from artifact ${ART_ID} ($(stat -c %s "$tarball" 2>/dev/null || wc -c < "$tarball") bytes packed)"
  out "hit=true"
  out "artifact_id=${ART_ID}"
}

cmd_prepare() {
  require_key
  local home name tarball_dir tarball upload="false"
  home="$(conan_home)"
  name="$(artifact_name "$CONAN_CACHE_KEY")"

  probe_artifact
  if [ "$ART_EXISTS" = "true" ]; then
    info "trusted artifact already exists for ${name} (id ${ART_ID}); nothing to upload"
    out "name=${name}"
    out "path="
    out "upload_needed=false"
    out "artifact_id=${ART_ID}"
    return 0
  fi
  if [ ! -d "$home/p" ]; then
    warn "no conan home to pack at ${home}; skipping the upload decision"
    out "name=${name}"
    out "path="
    out "upload_needed=false"
    out "artifact_id="
    return 0
  fi

  tarball_dir="$(scratch_dir)/conan-cache-artifact"
  tarball="${tarball_dir}/conan-home.tar.gz"
  mkdir -p "$tarball_dir"
  if ! tar -czf "$tarball" -C "$home" .; then
    warn "packing the conan home failed; skipping the upload"
    out "name=${name}"
    out "path="
    out "upload_needed=false"
    out "artifact_id="
    return 0
  fi
  upload="true"
  info "packed conan home for ${name} ($(stat -c %s "$tarball" 2>/dev/null || wc -c < "$tarball") bytes)"
  out "name=${name}"
  out "path=${tarball}"
  out "upload_needed=${upload}"
  out "artifact_id="
}

cmd_source() {
  local exact="${CONAN_EXACT_HIT:-}" artifact_hit="${CONAN_ARTIFACT_HIT:-}"
  local artifact_id="${CONAN_ARTIFACT_ID:-}" prefix="${CONAN_PREFIX_KEY:-}"
  local source="cold"
  if [ "$exact" = "true" ]; then
    source="exact"
  elif [ "$artifact_hit" = "true" ] && [ -n "$artifact_id" ]; then
    source="artifact:${artifact_id}"
  elif [ -n "$prefix" ]; then
    source="prefix:${prefix}"
  fi
  if [ -n "${GITHUB_ENV:-}" ]; then
    printf 'CONAN_CACHE_RESTORE_SOURCE=%s\n' "$source" >> "$GITHUB_ENV"
  fi
  printf 'CONAN_CACHE_RESTORE_SOURCE=%s\n' "$source"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    printf -- '- conan cache restore source: `%s`\n' "$source" >> "$GITHUB_STEP_SUMMARY"
  fi
}

run_selftest() {
  local failures=0
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  ok() {
    printf 'ok   - %s\n' "$1"
  }
  ko() {
    printf 'FAIL - %s\n' "$1"
    failures=$((failures + 1))
  }

  # 1. artifact name embeds the whole cache key.
  local name
  name="$(CONAN_CACHE_KEY="conan-release-master-linux-gcc-x86_64-Release-aabbccdd-0123456789abcdef-0123456789abcdef-0123456789abcdef" "$0" name)"
  case "$name" in
    conan-bin-conan-release-master-linux-gcc-x86_64-Release-*) ok "name = conan-bin-<key>" ;;
    *) ko "unexpected artifact name: $name" ;;
  esac

  # 2. pack/restore roundtrip keeps the home intact (the shape that a real
  #    restore depends on: p/ must exist afterwards).
  local home="$tmpdir/home" home2="$tmpdir/home2" key="conan-ci-selftest-profile-Release-00-00-00-00"
  mkdir -p "$home/p/pkgid/rev" "$home/d"
  printf 'payload\n' > "$home/p/pkgid/rev/conaninfo.txt"
  printf 'conf\n' > "$home/global.conf"
  CONAN_CACHE_KEY="$key" CONAN_HOME="$home" GITHUB_OUTPUT="$tmpdir/out1" "$0" prepare > "$tmpdir/prep.log"
  local packed
  packed="$(sed -n 's/^path=//p' "$tmpdir/out1" | head -1)"
  [ -n "$packed" ] && [ -f "$packed" ] && ok "prepare packed the home" || ko "prepare produced no tarball"
  [ "$(sed -n 's/^upload_needed=//p' "$tmpdir/out1" | head -1)" = "true" ] &&
    ok "prepare wants an upload for a missing artifact" || ko "prepare should request an upload"

  mkdir -p "$home2"
  tar -xzf "$packed" -C "$home2"
  [ -f "$home2/p/pkgid/rev/conaninfo.txt" ] && cmp -s "$home/p/pkgid/rev/conaninfo.txt" "$home2/p/pkgid/rev/conaninfo.txt" &&
    ok "tarball roundtrip preserves package content" || ko "tarball roundtrip lost content"
  [ -d "$home2/p" ] && ok "restored home has p/" || ko "restored home lost p/"

  # 3. prepare must not upload when there is no home at all.
  CONAN_CACHE_KEY="$key" CONAN_HOME="$tmpdir/missing" GITHUB_OUTPUT="$tmpdir/out2" "$0" prepare > /dev/null
  [ "$(sed -n 's/^upload_needed=//p' "$tmpdir/out2" | head -1)" = "false" ] &&
    ok "prepare skips a missing home" || ko "prepare must skip a missing home"

  # 4. tier classification.
  local src
  CONAN_EXACT_HIT=true GITHUB_ENV="$tmpdir/env1" "$0" source > /dev/null
  src="$(sed -n 's/^CONAN_CACHE_RESTORE_SOURCE=//p' "$tmpdir/env1")"
  [ "$src" = "exact" ] && ok "source: exact cache hit" || ko "source exact, got $src"
  CONAN_EXACT_HIT=false CONAN_ARTIFACT_HIT=true CONAN_ARTIFACT_ID=4242 GITHUB_ENV="$tmpdir/env2" "$0" source > /dev/null
  src="$(sed -n 's/^CONAN_CACHE_RESTORE_SOURCE=//p' "$tmpdir/env2")"
  [ "$src" = "artifact:4242" ] && ok "source: artifact hit carries its id" || ko "source artifact, got $src"
  CONAN_EXACT_HIT=false CONAN_ARTIFACT_HIT=false CONAN_PREFIX_KEY="conan-ci-x-Release-p" GITHUB_ENV="$tmpdir/env3" "$0" source > /dev/null
  src="$(sed -n 's/^CONAN_CACHE_RESTORE_SOURCE=//p' "$tmpdir/env3")"
  [ "$src" = "prefix:conan-ci-x-Release-p" ] && ok "source: prefix fallback" || ko "source prefix, got $src"
  CONAN_EXACT_HIT= CONAN_ARTIFACT_HIT= CONAN_ARTIFACT_ID= CONAN_PREFIX_KEY= GITHUB_ENV="$tmpdir/env4" "$0" source > /dev/null
  src="$(sed -n 's/^CONAN_CACHE_RESTORE_SOURCE=//p' "$tmpdir/env4")"
  [ "$src" = "cold" ] && ok "source: cold" || ko "source cold, got $src"

  # 5. trust filter: newest trusted candidate wins, forks/expired are dropped.
  cat > "$tmpdir/list.json" <<'JSON'
{"artifacts":[
 {"id":1,"name":"conan-bin-k","expired":false,"created_at":"2026-09-01T00:00:00Z",
  "workflow_run":{"repository_id":1,"head_repository_id":1,"head_branch":"main"}},
 {"id":2,"name":"conan-bin-k","expired":false,"created_at":"2026-09-03T00:00:00Z",
  "workflow_run":{"repository_id":1,"head_repository_id":9,"head_branch":"refs/pull/7/head"}},
 {"id":3,"name":"conan-bin-k","expired":true,"created_at":"2026-09-04T00:00:00Z",
  "workflow_run":{"repository_id":1,"head_repository_id":1,"head_branch":"main"}},
 {"id":4,"name":"conan-bin-k","expired":false,"created_at":"2026-09-02T00:00:00Z",
  "workflow_run":{"repository_id":1,"head_repository_id":1,"head_branch":"oc/issue-152"}}
]}
JSON
  local selected id
  selected="$(GITHUB_OUTPUT="$tmpdir/out3" select_artifact conan-bin-k < "$tmpdir/list.json")"
  id="$(sed -n 's/^artifact_id=//p' "$tmpdir/out3" | head -1)"
  [ "$id" = "4" ] && ok "trust filter keeps the newest trusted candidate (4)" || ko "expected artifact 4, got '$id' ($(printf '%s' "$selected" | tr '\n' ' '))"
  [ "$(sed -n 's/^exists=//p' "$tmpdir/out3" | head -1)" = "true" ] && ok "exists=true for a trusted candidate" || ko "exists should be true"
  cat > "$tmpdir/list2.json" <<'JSON'
{"artifacts":[{"id":9,"name":"conan-bin-k","expired":false,
 "workflow_run":{"repository_id":1,"head_repository_id":9,"head_branch":"refs/pull/7/head"}}]}
JSON
  GITHUB_OUTPUT="$tmpdir/out4" select_artifact conan-bin-k < "$tmpdir/list2.json" > /dev/null
  [ "$(sed -n 's/^exists=//p' "$tmpdir/out4" | head -1)" = "false" ] &&
    ok "fork/pull-request candidates are rejected" || ko "fork candidates must be rejected"
  cat > "$tmpdir/list3.json" <<'JSON'
{"artifacts":[]}
JSON
  GITHUB_OUTPUT="$tmpdir/out5" select_artifact conan-bin-k < "$tmpdir/list3.json" > /dev/null
  [ "$(sed -n 's/^exists=//p' "$tmpdir/out5" | head -1)" = "false" ] &&
    ok "empty listing is a miss" || ko "empty listing must be a miss"

  # 6. a non-JSON body (rate limit page, proxy error) must be a miss, not a
  #    crash: the whole point of the tier is that it can never fail a job.
  printf '<!DOCTYPE html><html>rate limited</html>' > "$tmpdir/bad.json"
  GITHUB_OUTPUT="$tmpdir/out6" select_artifact conan-bin-k < "$tmpdir/bad.json" > "$tmpdir/bad.log" || true
  [ "$(sed -n 's/^exists=//p' "$tmpdir/out6" | head -1)" = "false" ] &&
    ok "malformed API body degrades to a miss" || ko "malformed body must degrade to a miss"

  if [ "$failures" -ne 0 ]; then
    printf 'selftest: %s failure(s)\n' "$failures" >&2
    return 1
  fi
  printf 'selftest: all checks passed\n'
  return 0
}

[ "$#" -gt 0 ] || { usage; exit 2; }
cmd="$1"
shift || true

case "$cmd" in
  selftest) run_selftest ;;
  name) cmd_name ;;
  exists) cmd_exists ;;
  restore) cmd_restore ;;
  prepare) cmd_prepare ;;
  source) cmd_source ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
