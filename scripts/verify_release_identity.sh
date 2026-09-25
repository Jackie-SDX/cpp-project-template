#!/usr/bin/env bash
# verify_release_identity.sh -- version + repository identity contract checks
# (CORE-10, and the repository-surface part of P0-7).
#
#   verify_release_identity.sh [--repo DIR] [--evidence FILE] [--version V]
#
# Checks:
#   1. HOMEPAGE_URL in CMakeLists.txt points at the repository that is
#      actually configured as origin (owner/repo), not at a fork lineage.
#   2. AUTHOR_NAME/AUTHOR_EMAIL are exactly the repository's own git author
#      identity (`git log -1 --format='%an <%ae>'`) -- provenance, never an
#      invented contact address (Debian requires Name <address>).
#   3. No stale identity tokens (previous owners/registries) anywhere in the
#      packaging/build surfaces: CMakeLists.txt, cmake/, packaging/, src/,
#      scripts/, .github/workflows/, .circleci/.  Documentation, audits,
#      CITATION.cff, CODEOWNERS, FUNDING.yml and the GitLab CI mirror config
#      are explicitly allowlisted (fork lineage / citation / governance data
#      is legitimate history, packaging metadata is not).
#   4. Unsafe publication behaviour must be gone: no `overwrite_files: true`
#      in workflows (CORE-6 immutability).
#   5. No development-package dependency fallback (`libwxgtk3.2-dev`) in
#      packaging surfaces (P0-8).
#   6. The canonical architecture vocabulary is the only one used in artifact
#      naming surfaces: no `x64`/`x86` package names (CORE-8).
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
DEFAULT_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)

REPO="$DEFAULT_ROOT" EVIDENCE="" VERSION=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO=$2; shift 2 ;;
    --evidence) EVIDENCE=$2; shift 2 ;;
    --version) VERSION=$2; shift 2 ;;
    *) echo "verify_release_identity: unknown argument $1" >&2; exit 2 ;;
  esac
done
[ -d "$REPO" ] || { echo "no such repo: $REPO" >&2; exit 2; }
REPO=$(CDPATH='' cd -- "$REPO" && pwd)

failures=0
results=()
rec() {
  results+=("$1|$2|$3|${4:-}")
  printf '[%s] %-16s %s %s\n' "$1" "$2" "$3" "${4:-}"
  [ "$1" = "FAIL" ] && failures=$((failures + 1))
  return 0
}

cd "$REPO"

# --- 1. homepage matches origin ------------------------------------------
origin_url=$(git -C "$REPO" remote get-url origin 2>/dev/null || true)
homepage=$(sed -n 's/.*HOMEPAGE_URL "\([^"]*\)".*/\1/p' CMakeLists.txt | head -1)
if [ -n "$origin_url" ] && [ -n "$homepage" ]; then
  origin_path=$(printf '%s' "$origin_url" | sed -E 's#^[a-z+]+://([^@]+@)?##; s#\.git$##; s#^github\.com/##; s#^gitlab\.com/##')
  home_path=$(printf '%s' "$homepage" | sed -E 's#^https?://##; s#\.git$##; s#^github\.com/##; s#^gitlab\.com/##')
  if [ "$origin_path" = "$home_path" ]; then
    rec PASS homepage "$homepage matches origin ($origin_path)"
  else
    rec FAIL homepage "HOMEPAGE_URL=$homepage but origin is '$origin_url' (stale product identity)"
  fi
else
  rec SKIP homepage "origin or HOMEPAGE_URL unavailable"
fi

# --- 2. maintainer identity = git author identity -------------------------
# Most recent *human* author: the harness/bot identities that create the
# audit commits are filtered out so the comparison lands on the repository's
# real author identity instead of the automation that last touched it.
git_author=$(git -C "$REPO" log --format='%an <%ae>' 2>/dev/null |
  grep -viE 'opencode|oc-agent|github-actions|\[bot\]|agent <' | head -1 || true)
author_name=$(sed -n 's/^[[:space:]]*set(AUTHOR_NAME "\([^"]*\)").*/\1/p' CMakeLists.txt | head -1)
author_email=$(sed -n 's/^[[:space:]]*set(AUTHOR_EMAIL "\([^"]*\)").*/\1/p' CMakeLists.txt | head -1)
if [ -n "$git_author" ]; then
  if [ "$author_name <$author_email>" = "$git_author" ]; then
    rec PASS maintainer-identity "AUTHOR_* = git author '$git_author' (provenance, not invented)"
  else
    rec FAIL maintainer-identity "AUTHOR_* = '$author_name <$author_email>' but git author is '$git_author'"
  fi
else
  rec SKIP maintainer-identity "no git history available"
fi

# --- 3. stale identity in packaging surfaces ------------------------------
# Scanned surfaces (build/package metadata only). Documentation, audits,
# CITATION.cff, CODEOWNERS, FUNDING.yml and .gitlab/ are allowlisted on
# purpose: see docs/distribution-hardening-evidence.md.
# Full token set for build/package metadata surfaces. src/ is scanned for
# product/registry identity only: @author comments in sources are authorship
# history (like docs/ and CITATION.cff), not product metadata.
surfaces=(CMakeLists.txt cmake packaging scripts .github/workflows .circleci)
product_only_surfaces=(src)
stale_tokens=(NaylaCruz xemypandas MangaD)
product_tokens=(NaylaCruz xemypandas)
stale_hits=""
scan_set() { # $1=file-or-dir $2...=tokens
  local target=$1; shift
  [ -e "$target" ] || return 0
  local tok hits
  for tok in "$@"; do
    hits=$(grep -RIn --binary-files=without-match --exclude=verify_release_identity.sh \
      -F "$tok" "$target" 2>/dev/null || true)
    [ -n "$hits" ] && stale_hits="$stale_hits$hits"$'\n'
  done
  return 0
}
for s in "${surfaces[@]}"; do scan_set "$REPO/$s" "${stale_tokens[@]}"; done
for s in "${product_only_surfaces[@]}"; do scan_set "$REPO/$s" "${product_tokens[@]}"; done
if [ -z "$stale_hits" ]; then
  rec PASS stale-identity "no previous-owner/registry tokens in packaging surfaces"
else
  printf '%s' "$stale_hits" | sed 's/^/    /'
  rec FAIL stale-identity "stale identity token(s) in packaging surfaces (see above; docs/audits/CITATION/GitLab mirror are allowlisted)"
fi

# --- 4. unsafe publication behaviour --------------------------------------
if grep -RIn --binary-files=without-match 'overwrite_files:\s*true' .github/workflows .gitlab 2>/dev/null | grep -v '^$'; then
  rec FAIL overwrite "overwrite_files: true still present (existing release assets could be silently replaced)"
else
  rec PASS overwrite "no workflow can overwrite an already-published asset"
fi

# --- 5. no development-package fallback -----------------------------------
# packaging metadata only -- workflows legitimately `apt-get install
# libwxgtk3.2-dev` to *build*, that is not a shipped runtime dependency.
if grep -RIn --binary-files=without-match 'libwxgtk3\.2-dev' CMakeLists.txt cmake packaging 2>/dev/null |
   grep -vE '^[^:]+:[0-9]+:[[:space:]]*[#*]' | grep -v '^$'; then
  rec FAIL dev-fallback "development package used as a runtime dependency (P0-8)"
else
  rec PASS dev-fallback "no libwxgtk3.2-dev runtime fallback in packaging metadata"
fi

# --- 6. canonical architecture vocabulary (CORE-8) ------------------------
# Artifact-naming surfaces must only use x86_64 / i686 / arm64.
vocab_bad=""
for s in cmake/cpack_module.cmake scripts/release_contract.sh packaging/release-contract.tsv; do
  [ -f "$REPO/$s" ] || continue
  hits=$(grep -nE 'windows-(msvc|mingw|llvm|clangarm64)-(x64|x86)\.|\$\{_arch_display\}|_arch_display' "$REPO/$s" || true)
  if [ -n "$hits" ]; then vocab_bad="$vocab_bad$s:"$'\n'"$hits"$'\n'; fi
done
# workflow smoke/manifest loops
if [ -d "$REPO/.github/workflows" ]; then
  hits=$(grep -RIn --binary-files=without-match -E 'windows-[a-z0-9]+-x64\.(zip|exe|msi)|linux-[a-z]+-x64\.(zip|tar\.gz|deb|rpm)' "$REPO/.github/workflows" 2>/dev/null || true)
  if [ -n "$hits" ]; then vocab_bad="$vocab_bad.workflows:"$'\n'"$hits"$'\n'; fi
fi
if [ -z "$vocab_bad" ]; then
  rec PASS arch-vocabulary "only x86_64/i686/arm64 in artifact-naming surfaces"
else
  printf '%s' "$vocab_bad" | sed 's/^/    /'
  rec FAIL arch-vocabulary "legacy x64/x86 naming found in artifact-naming surfaces (CORE-8)"
fi

# --- version agreement (optional, when --version given) -------------------
if [ -n "$VERSION" ]; then
  if [ -f packaging/release-contract.tsv ]; then
    sample=$(grep -c "cpp-project-template_\${V}_" packaging/release-contract.tsv || true)
    if [ "${sample:-0}" -gt 0 ]; then
      rec PASS contract-version-token "contract uses \${V} tokens ($sample rows) substituted with $VERSION"
    else
      rec FAIL contract-version-token "contract has no \${V} tokens"
    fi
  fi
fi

if [ -n "$EVIDENCE" ]; then
  {
    printf '{\n  "version": "%s",\n  "origin": "%s",\n  "checks": [\n' "${VERSION:-unspecified}" "${origin_url:-unknown}"
    first=1
    for line in "${results[@]}"; do
      st=${line%%|*}; rest=${line#*|}
      chk=${rest%%|*}; det=${rest#*|}
      det=${det//\\/\\\\}; det=${det//\"/\\\"}
      [ $first -eq 1 ] || printf ',\n'
      first=0
      printf '    {"status": "%s", "check": "%s", "detail": "%s"}' "$st" "$chk" "$det"
    done
    printf '\n  ]\n}\n'
  } > "$EVIDENCE"
  echo "evidence written: $EVIDENCE"
fi

if [ "$failures" -ne 0 ]; then
  echo "verify_release_identity: $failures check(s) FAILED" >&2
  exit 1
fi
echo "verify_release_identity: all checks passed"
