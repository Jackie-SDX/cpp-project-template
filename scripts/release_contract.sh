#!/usr/bin/env bash
# release_contract.sh -- machine-readable release inventory helper.
#
# Reads packaging/release-contract.tsv (the single source of truth for the
# published inventory: USEFUL-3, CORE-5) and answers:
#
#   expected --version V --scope S     print the expected filenames for scope S
#   check --dir D --version V --scope S
#                                      assert directory D matches scope S
#   check-forbidden --dir D            assert no forbidden format is present
#   list [--scope S] [--format tsv|names]
#                                      dump contract rows
#   json --version V --scope S         contract as JSON (for release-evidence)
#
# Scopes:
#   github-packages   54 platform packages + 2 source archives
#   github-full       everything the GitHub release must contain (adds
#                     SHA256SUMS, the contract itself, evidence, SBOM, verifier)
#   gitlab-floor      CORE-7 floor: every gitlab=auto row must be present,
#                     every leg that produced at least one artifact must be
#                     complete, and no unexpected package may exist. Missing
#                     manual/blocked legs are warnings, not failures.
#
# Pure POSIX-ish bash + awk/sort/comm; no jq (GitLab's release image is
# alpine/ash and must be able to run this too). pipefail only where the
# shell actually has it -- `sh scripts/release_contract.sh` under dash or
# busybox ash (create_release does exactly that; Alpine has no bash) must
# not die on `set -o pipefail` itself.
set -eu
if (set -o pipefail 2>/dev/null); then set -o pipefail; fi

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT=${RELEASE_CONTRACT:-"$REPO_ROOT/packaging/release-contract.tsv"}

fail() { printf 'release-contract: ERROR: %s\n' "$*" >&2; exit 1; }
warn() { printf 'release-contract: WARN: %s\n' "$*" >&2; }
info() { printf 'release-contract: %s\n' "$*"; }

[ -f "$CONTRACT" ] || fail "contract not found: $CONTRACT"

# awk helpers -------------------------------------------------------------

# rows for a scope, filename already version-substituted
expected_names() { # $1=scope $2=version
  awk -F'\t' -v scope="$1" -v ver="$2" '
    /^#/ || /^os\t/ || NF < 6 { next }
    {
      fn = $6
      gsub(/\$\{V\}/, ver, fn)
      if (scope == "github-packages")
        { if ($1 == "windows" || $1 == "linux" || $1 == "macos" || $1 == "source") print fn }
      else if (scope == "github-full")
        { print fn }
      else if (scope == "gitlab-floor")
        { if ($8 == "auto") print fn }
      else { exit 2 }
    }' "$CONTRACT" | LC_ALL=C sort -u
}

# leg key + formats for a scope (one line per artifact: "leg<TAB>filename")
leg_map() { # $1=scope $2=version
  awk -F'\t' -v scope="$1" -v ver="$2" '
    /^#/ || /^os\t/ || NF < 6 { next }
    $1 != "windows" && $1 != "linux" && $1 != "macos" { next }
    {
      fn = $6
      gsub(/\$\{V\}/, ver, fn)
      leg = $1 "/" $2 "/" $3
      if (scope == "github-packages" || scope == "github-full" || scope == "gitlab-floor")
        print leg "\t" fn
    }' "$CONTRACT" | LC_ALL=C sort -u
}

# ---------------------------------------------------------------------------

PACKAGE_GLOBS='*.zip *.tar.gz *.deb *.rpm *.exe *.msi *.dmg'

list_package_files() { # $1=dir -- every file that looks like a distributable
  dir=$1
  (
    cd "$dir" || exit 1
    for g in $PACKAGE_GLOBS; do
      for f in $g; do
        [ -f "$f" ] && printf '%s\n' "$f"
      done
    done
    # the last glob test can fail when a format is absent; that is not an error
    exit 0
  ) | LC_ALL=C sort -u
}

is_source_name() {
  case "$1" in
    *_source.zip|*_source.tar.gz) return 0 ;;
    *) return 1 ;;
  esac
}

cmd_expected() {
  scope=github-packages ver=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --scope) scope=$2; shift 2 ;;
      --version) ver=$2; shift 2 ;;
      *) fail "expected: unknown argument $1" ;;
    esac
  done
  [ -n "$ver" ] || fail "expected: --version is required"
  expected_names "$scope" "$ver"
}

cmd_list() {
  scope=all format=tsv
  while [ $# -gt 0 ]; do
    case "$1" in
      --scope) scope=$2; shift 2 ;;
      --format) format=$2; shift 2 ;;
      *) fail "list: unknown argument $1" ;;
    esac
  done
  if [ "$format" = names ]; then
    awk -F'\t' '/^#/ || /^os\t/ || NF < 6 { next } { print $6 }' "$CONTRACT"
  else
    cat "$CONTRACT"
  fi
}

cmd_json() {
  scope=github-full ver=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --scope) scope=$2; shift 2 ;;
      --version) ver=$2; shift 2 ;;
      *) fail "json: unknown argument $1" ;;
    esac
  done
  [ -n "$ver" ] || fail "json: --version is required"
  awk -F'\t' -v scope="$scope" -v ver="$ver" '
    function esc(s) { gsub(/"/, "\\\"", s); return "\"" s "\"" }
    /^#/ || /^os\t/ || NF < 6 { next }
    {
      fn = $6; gsub(/\$\{V\}/, ver, fn)
      if (scope == "github-packages" &&
            !($1=="windows"||$1=="linux"||$1=="macos"||$1=="source")) next
      if (scope == "gitlab-floor" && $8 != "auto") next
      printf "%s{\"os\":%s,\"arch\":%s,\"toolchain\":%s,\"profile\":%s,\"format\":%s,\"filename\":%s,\"validations\":%s,\"gitlab\":%s,\"supportBaseline\":%s}", \
        (n++ ? ",\n" : ""), esc($1), esc($2), esc($3), esc($4), esc($5), esc(fn), esc($7), esc($8), esc($9)
    }
    END { if (n) printf "\n" }' "$CONTRACT" | \
  { printf '[\n'; cat; printf ']\n'; }
}

cmd_check_forbidden() {
  dir=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --dir) dir=$2; shift 2 ;;
      *) fail "check-forbidden: unknown argument $1" ;;
    esac
  done
  [ -n "$dir" ] || fail "check-forbidden: --dir is required"
  rc=0
  (
    cd "$dir"
    # Iterate every regular file (including dotfiles), lowercased via tr,
    # so `prog.AppImage` or `PKG.7Z` is caught exactly like `prog.appimage`
    # -- shell globs alone are case-sensitive and used to miss these.
    for f in * .*; do
      [ -f "$f" ] || continue
      lf=$(printf '%s' "$f" | tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')
      case "$lf" in
        *_source.zip|*_source.tar.gz) continue ;;
        *.7z|*.msix|*.appimage|*.flatpak|*.snap)
          echo "forbidden format published: $f" >&2; exit 3 ;;
        *.zip)
          case "$lf" in *_linux-*) echo "forbidden: Linux .zip duplicate: $f" >&2; exit 3 ;; esac ;;
        *.tar.gz)
          case "$lf" in *_macos-*) echo "forbidden: macOS .tar.gz duplicate: $f" >&2; exit 3 ;; esac ;;
      esac
    done
    exit 0
  ) || rc=$?
  if [ "$rc" -ne 0 ]; then
    fail "CORE-5 forbidden format check failed"
  fi
  info "forbidden format check: clean"
}

cmd_check() {
  dir="" scope=github-packages ver=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --dir) dir=$2; shift 2 ;;
      --scope) scope=$2; shift 2 ;;
      --version) ver=$2; shift 2 ;;
      *) fail "check: unknown argument $1" ;;
    esac
  done
  [ -n "$dir" ] || fail "check: --dir is required"
  [ -n "$ver" ] || fail "check: --version is required"
  [ -d "$dir" ] || fail "check: not a directory: $dir"

  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  expected_names "$scope" "$ver" > "$tmp/expected"

  # actual inventory:
  #   github-full      -> every top-level file (strays are unexpected too)
  #   github-packages  -> package-shaped files only (the publish job also
  #                       holds SHA256SUMS etc.; those are checked in the
  #                       github-full scope)
  #   gitlab-floor     -> package-shaped files only
  : > "$tmp/actual"
  if [ "$scope" = "github-full" ]; then
    (
      cd "$dir"
      for f in *; do
        [ -f "$f" ] && printf '%s\n' "$f"
      done
      exit 0
    ) | LC_ALL=C sort -u > "$tmp/actual"
  else
    list_package_files "$dir" > "$tmp/actual"
  fi

  if [ "$scope" = "github-packages" ] || [ "$scope" = "github-full" ]; then
    missing=0 unexpected=0
    while IFS= read -r f; do
      grep -qxF "$f" "$tmp/actual" || { echo "MISSING: $f"; missing=1; }
    done < "$tmp/expected"
    while IFS= read -r f; do
      grep -qxF "$f" "$tmp/expected" || { echo "UNEXPECTED: $f"; unexpected=1; }
    done < "$tmp/actual"
    if [ "$missing" -ne 0 ] || [ "$unexpected" -ne 0 ]; then
      echo "inventory mismatch (scope=$scope version=$ver):" >&2
      comm -3 "$tmp/expected" "$tmp/actual" >&2 || true
      fail "release inventory check failed"
    fi
    count=$(wc -l < "$tmp/expected" | tr -d ' ')
    info "inventory OK: $count expected artifact(s) present, none unexpected (scope=$scope)"
  else
    # gitlab-floor
    floor_missing=0
    while IFS= read -r f; do
      if [ ! -f "$dir/$f" ]; then
        echo "FLOOR MISSING: $f" >&2
        floor_missing=1
      fi
    done < "$tmp/expected"
    if [ "$floor_missing" -ne 0 ]; then
      fail "GitLab completeness floor failed: the required leg/format(s) above are missing"
    fi

    # any leg with at least one artifact must have every format of that leg
    leg_map github-packages "$ver" > "$tmp/legmap.all"
    # which legs are actually present in the directory?
    while IFS= read -r f; do
      if is_source_name "$f"; then continue; fi
      awk -F'\t' -v fn="$f" '$2 == fn { print $1 }' "$tmp/legmap.all"
    done < "$tmp/actual" | LC_ALL=C sort -u > "$tmp/legs_with_output"

    : > "$tmp/incomplete"
    if [ -s "$tmp/legs_with_output" ]; then
      while IFS= read -r leg; do
        total=$(awk -F'\t' -v l="$leg" '$1 == l' "$tmp/legmap.all" | wc -l | tr -d ' ')
        present=$(awk -F'\t' -v l="$leg" '$1 == l { print $2 }' "$tmp/legmap.all" | while IFS= read -r f; do
            if [ -f "$dir/$f" ]; then echo x; fi
          done | wc -l | tr -d ' ')
        if [ "$total" -gt 0 ] && [ "$present" -ne 0 ] && [ "$present" -ne "$total" ]; then
          echo "INCOMPLETE LEG: $leg ($present/$total formats present)" >&2
          echo "$leg" >> "$tmp/incomplete"
        fi
      done < "$tmp/legs_with_output"
    fi
    if [ -s "$tmp/incomplete" ]; then
      fail "GitLab floor: leg(s) above published only part of their format set"
    fi

    # unexpected package-shaped file = naming divergence (CORE-8)
    unexpected=0
    while IFS= read -r f; do
      if is_source_name "$f"; then continue; fi
      if ! awk -F'\t' -v fn="$f" '$2 == fn { found=1 } END { exit !found }' "$tmp/legmap.all"; then
        echo "UNEXPECTED (not in contract, naming divergence?): $f" >&2
        unexpected=1
      fi
    done < "$tmp/actual"
    if [ "$unexpected" -ne 0 ]; then
      fail "GitLab floor: unexpected artifact name(s) above are not in the release contract"
    fi

    # report best-effort legs that produced nothing (informational)
    awk -F'\t' '$8 == "manual" || $8 == "blocked" {
        leg = $1 "/" $2 "/" $3
        if (!seen[leg]++) order[++n] = leg
        gl[leg] = $8
      }
      END { for (i = 1; i <= n; i++) print gl[order[i]] "\t" order[i] }' "$CONTRACT" |
      while read -r gl leg; do
        if ! grep -qxF "$leg" "$tmp/legs_with_output" 2>/dev/null; then
          case "$gl" in
            manual) info "best-effort leg not produced this run: $leg (manual/dormant)" ;;
            blocked) info "blocked leg not produced this run: $leg (no runner entitlement)" ;;
          esac
        fi
      done
    count=$(wc -l < "$tmp/expected" | tr -d ' ')
    info "GitLab completeness floor OK: $count required artifact(s) present (scope=gitlab-floor)"
  fi
}

usage() {
  cat <<'EOF'
usage: release_contract.sh <command> [options]

commands:
  expected --version V --scope github-packages|github-full|gitlab-floor
  check --dir DIR --version V --scope github-packages|github-full|gitlab-floor
  check-forbidden --dir DIR
  list [--scope S] [--format tsv|names]
  json --version V --scope github-packages|github-full|gitlab-floor
EOF
}

cmd=${1:-}
[ -n "$cmd" ] || { usage; exit 2; }
shift
case "$cmd" in
  expected) cmd_expected "$@" ;;
  check) cmd_check "$@" ;;
  check-forbidden) cmd_check_forbidden "$@" ;;
  list) cmd_list "$@" ;;
  json) cmd_json "$@" ;;
  -h|--help|help) usage ;;
  *) usage; fail "unknown command: $cmd" ;;
esac
