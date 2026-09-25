#!/usr/bin/env bash
# validate_release_artifacts.sh -- structural / safety / integrity validation of
# a staged release directory (CORE-6, CORE-10, USEFUL-7).
#
#   validate_release_artifacts.sh --dir DIR --version V [--evidence FILE]
#                                  [--scope github-full|github-packages|gitlab-floor]
#
# --scope selects the inventory expectation (default github-full; CI's
# validate stage runs --scope github-packages before the meta files exist).
#
# Checks performed (each printed as PASS/FAIL/SKIP with a reason):
#   1. inventory        : release_contract.sh check (scope github-full)
#   2. forbidden-format : release_contract.sh check-forbidden (CORE-5)
#   3. non-empty        : every expected artifact has bytes
#   4. archive safety   : no absolute paths, no "..", no symlinks, no
#                         __MACOSX/.DS_Store junk in .zip/.tar.gz members
#   5. PE architecture  : windows .zip members + .exe/.msi installers match the
#                         contract arch (CORE-4-adjacent; catches the
#                         windows-mingw-i686-actually-x86_64 class of defect)
#   6. macOS structure  : gui legs ship projectwx.app/Contents/... (CORE-4)
#   7. package metadata : DEB/RPM Version, Maintainer/Homepage present (CORE-3)
#   8. checksums        : SHA256SUMS exists, covers every file, verifies (CORE-6)
#   9. debug/temp junk  : no *.pdb/*.ilk/*~/.DS_Store/__MACOSX/...
#  10. absolute paths   : no CI/build-home paths embedded in shipped text files
#  11. exec surface     : executables in raw archives live under bin/ (or the
#                         macOS bundle), nothing unexpected is executable
#
# Requires: bash, python3, unzip/zipinfo, tar, sha256sum, file; dpkg-deb and
# rpm are used when present (otherwise those sub-checks report SKIP).
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)

DIR="" VERSION="" EVIDENCE="" SCOPE="github-full"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR=$2; shift 2 ;;
    --version) VERSION=$2; shift 2 ;;
    --evidence) EVIDENCE=$2; shift 2 ;;
    --scope) SCOPE=$2; shift 2 ;;
    *) echo "validate_release_artifacts: unknown argument $1" >&2; exit 2 ;;
  esac
done
[ -n "$DIR" ] && [ -n "$VERSION" ] || {
  echo "usage: validate_release_artifacts.sh --dir DIR --version V [--evidence FILE] [--scope S]"
  exit 2
}
case "$SCOPE" in
  github-full|github-packages|gitlab-floor) ;;
  *) echo "validate_release_artifacts: unknown --scope $SCOPE" >&2; exit 2 ;;
esac
[ -d "$DIR" ] || { echo "not a directory: $DIR" >&2; exit 2; }
DIR=$(CDPATH='' cd -- "$DIR" && pwd)

failures=0
results=()   # lines: "STATUS|check|subject|detail"

# Identity of record, read from the project itself (CORE-10). Nothing here is
# invented: these are the exact values CMakeLists.txt bakes into CPack.
EXPECTED_HOMEPAGE=$(sed -n 's/.*HOMEPAGE_URL "\([^"]*\)".*/\1/p' "$REPO_ROOT/CMakeLists.txt" | head -1)
EXPECT_AUTHOR_NAME=$(sed -n 's/^[[:space:]]*set(AUTHOR_NAME "\([^"]*\)").*/\1/p' "$REPO_ROOT/CMakeLists.txt" | head -1)
EXPECT_AUTHOR_EMAIL=$(sed -n 's/^[[:space:]]*set(AUTHOR_EMAIL "\([^"]*\)").*/\1/p' "$REPO_ROOT/CMakeLists.txt" | head -1)
EXPECT_MAINTAINER="$EXPECT_AUTHOR_NAME <$EXPECT_AUTHOR_EMAIL>"
[ -n "$EXPECTED_HOMEPAGE" ] || { echo "cannot read HOMEPAGE_URL from CMakeLists.txt" >&2; exit 2; }
[ -n "$EXPECT_MAINTAINER" ] || { echo "cannot read AUTHOR_* from CMakeLists.txt" >&2; exit 2; }

rec() { # $1=PASS|FAIL|SKIP $2=check $3=subject $4=detail
  results+=("$1|$2|$3|$4")
  printf '[%s] %-14s %s %s\n' "$1" "$2" "$3" "$4"
  if [ "$1" = "FAIL" ]; then failures=$((failures + 1)); fi
}

# --- contract helpers ------------------------------------------------------
contract_row_for() { # $1=filename -> fields (os arch toolchain profile format ...)
  awk -F'\t' -v fn="$1" '
    /^#/ || /^os\t/ || NF < 6 { next }
    { v = $6; gsub(/\$\{V\}/, ver, v); if (v == fn) { print; exit } }' \
    ver="$VERSION" "$REPO_ROOT/packaging/release-contract.tsv"
}

arch_of_zip_member() { # $1=zip $2=member -> x86_64|i686|arm64|unknown
  python3 - "$1" "$2" <<'PY'
import struct, sys, zipfile, io
z = zipfile.ZipFile(sys.argv[1])
data = z.read(sys.argv[2])
if data[:2] != b'MZ':
    print('unknown'); sys.exit()
pe = struct.unpack_from('<I', data, 0x3C)[0]
if data[pe:pe+4] != b'PE\0\0':
    print('unknown'); sys.exit()
machine = struct.unpack_from('<H', data, pe+4)[0]
print({0x8664: 'x86_64', 0x014C: 'i686', 0xAA64: 'arm64'}.get(machine, 'unknown'))
PY
}

arch_of_pe_file() { # $1=path to PE -> x86_64|i686|arm64|unknown
  python3 - "$1" <<'PY'
import struct, sys
data = open(sys.argv[1], 'rb').read()
if data[:2] != b'MZ':
    print('unknown'); sys.exit()
pe = struct.unpack_from('<I', data, 0x3C)[0]
if data[pe:pe+4] != b'PE\0\0':
    print('unknown'); sys.exit()
machine = struct.unpack_from('<H', data, pe+4)[0]
print({0x8664: 'x86_64', 0x014C: 'i686', 0xAA64: 'arm64'}.get(machine, 'unknown'))
PY
}

expected_arch() { # from contract filename column of $1
  contract_row_for "$1" | awk -F'\t' '{ print $2 }'
}
expected_profile() {
  contract_row_for "$1" | awk -F'\t' '{ print $4 }'
}

# ---------------------------------------------------------------------------
echo "== 1. inventory ($SCOPE) =="
if "$REPO_ROOT/scripts/release_contract.sh" check --dir "$DIR" --version "$VERSION" --scope "$SCOPE"; then
  rec PASS inventory "$DIR" "all contract artifacts present"
else
  rec FAIL inventory "$DIR" "inventory mismatch (see above)"
fi

echo "== 2. forbidden formats (CORE-5) =="
if "$REPO_ROOT/scripts/release_contract.sh" check-forbidden --dir "$DIR"; then
  rec PASS forbidden-format "$DIR" "no .7z/.msix/AppImage/Flatpak/Snap, no Linux .zip, no macOS .tar.gz"
else
  rec FAIL forbidden-format "$DIR" "forbidden artifact present"
fi

# --- per-artifact ----------------------------------------------------------
while IFS= read -r f; do
  path="$DIR/$f"
  [ -f "$path" ] || continue
  size=$(wc -c < "$path" | tr -d ' ')
  if [ "$size" -eq 0 ]; then
    rec FAIL non-empty "$f" "zero bytes"
    continue
  fi
  rec PASS non-empty "$f" "$size bytes"

  case "$f" in
    *.zip)
      # member safety
      if python3 - "$path" <<'PY'
import sys, zipfile
bad = []
z = zipfile.ZipFile(sys.argv[1])
for i in z.infolist():
    n = i.filename
    if n.startswith('/') or n.startswith('\\') or (len(n) > 1 and n[1] == ':'):
        bad.append(('absolute', n))
    if '..' in n.split('/'):
        bad.append(('traversal', n))
    # 0xA1FF (0xA000 = symlink) in unix mode of external_attr
    mode = (i.external_attr >> 16) & 0xF000
    if mode == 0xA000:
        bad.append(('symlink', n))
    if '__MACOSX/' in n or n.endswith('.DS_Store'):
        bad.append(('junk', n))
for kind, n in bad:
    print(f'{kind}: {n}')
sys.exit(1 if bad else 0)
PY
      then rec PASS archive-safety "$f" "no absolute/traversal/symlink/junk members"
      else rec FAIL archive-safety "$f" "unsafe or junk member found (see above)"; fi

      # macOS .app structure (CORE-4)
      case "$f" in
        *_macos-*)
          prof=$(expected_profile "$f")
          if [ "$prof" = "cli" ]; then
            rec SKIP app-structure "$f" "leg is cli-only (projectwx disabled)"
          elif zipinfo -1 "$path" | grep -q '^projectwx\.app/Contents/MacOS/projectwx$'; then
            if zipinfo -1 "$path" | grep -q '^projectwx\.app/Contents/Info\.plist$'; then
              rec PASS app-structure "$f" "projectwx.app/Contents/{MacOS,Info.plist} present"
            else
              rec FAIL app-structure "$f" "Info.plist missing"
            fi
          else
            rec FAIL app-structure "$f" "projectwx.app/Contents/MacOS/projectwx missing"
          fi
          ;;
      esac

      # PE architecture of shipped binaries (and of the raw zip payload)
      case "$f" in
        *_windows-*)
          want=$(expected_arch "$f")
          bad=""
          while IFS= read -r m; do
            case "$m" in
              *.exe|*.dll)
                got=$(arch_of_zip_member "$path" "$m")
                if [ "$got" != "unknown" ] && [ "$got" != "$want" ]; then
                  bad="$bad $m=$got"
                fi
                ;;
            esac
          done < <(zipinfo -1 "$path")
          if [ -z "$bad" ]; then
            rec PASS pe-arch "$f" "all PE members are $want"
          else
            rec FAIL pe-arch "$f" "expected $want; mismatched:$bad"
          fi
          ;;
      esac

      # absolute build paths in shipped text files + exec surface
      tmp=$(mktemp -d)
      unzip -qq -o "$path" -d "$tmp" 2>/dev/null || { rec FAIL extract "$f" "unzip failed"; rm -rf "$tmp"; continue; }
      if hits=$(grep -rIlE '(/home/[a-z]+/|/Users/[A-Za-z0-9_.-]+/|/workspace/|[A-Za-z]:\\\\(a|Users|build)\\\\)' "$tmp" 2>/dev/null | head -5); then
        if [ -n "$hits" ]; then
          rec FAIL abs-paths "$f" "build/home paths in: $(echo "$hits" | sed "s|$tmp/||" | tr '\n' ' ')"
        else
          rec PASS abs-paths "$f" "no embedded build/home paths in text members"
        fi
      else
        rec PASS abs-paths "$f" "no embedded build/home paths in text members"
      fi
      case "$f" in
        *_linux-*|*_macos-*)
          stray=$(find "$tmp" -type f -perm -u+x \
                  ! -path '*/bin/*' ! -path '*/projectwx.app/*' \
                  ! -name '*.sh' -print | head -5)
          if [ -z "$stray" ]; then
            rec PASS exec-surface "$f" "only bin/ (and bundle) entries are executable"
          else
            rec FAIL exec-surface "$f" "unexpected executables: $(echo "$stray" | sed "s|$tmp/||" | tr '\n' ' ')"
          fi
          ;;
      esac
      rm -rf "$tmp"
      ;;

    *.tar.gz)
      if listing=$(tar -tzf "$path"); then
        if printf '%s\n' "$listing" | grep -qE '(^/|(^|/)\.\.(/|$))'; then
          rec FAIL archive-safety "$f" "absolute or '..' member in tar"
        else
          rec PASS archive-safety "$f" "no absolute/traversal members"
        fi
      else
        rec FAIL archive-safety "$f" "tar listing failed"
      fi
      # exec surface for the raw Linux install tree
      if tar -tvzf "$path" | awk '$1 ~ /^-/ && $1 ~ /x/ { print $NF }' \
          | grep -vE '^\./bin/|/bin/[^/]+$' | grep -q .; then
        rec FAIL exec-surface "$f" "executable outside bin/: $(tar -tvzf "$path" | awk '$1 ~ /^-/ && $1 ~ /x/ {print $NF}' | grep -vE '^\./bin/|/bin/[^/]+$' | head -3 | tr '\n' ' ')"
      else
        rec PASS exec-surface "$f" "only bin/ entries are executable"
      fi
      ;;

    *.deb)
      if command -v dpkg-deb >/dev/null 2>&1; then
        ver=$(dpkg-deb -f "$path" Version 2>/dev/null || true)
        maint=$(dpkg-deb -f "$path" Maintainer 2>/dev/null || true)
        home=$(dpkg-deb -f "$path" Homepage 2>/dev/null || true)
        arch=$(dpkg-deb -f "$path" Architecture 2>/dev/null || true)
        if [ "$ver" = "$VERSION" ]; then rec PASS pkg-version "$f" "Version=$ver"
        else rec FAIL pkg-version "$f" "Version=$ver, expected $VERSION (P0-6)"; fi
        if [ "$maint" = "$EXPECT_MAINTAINER" ]; then
          rec PASS pkg-maintainer "$f" "Maintainer=$maint"
        else
          rec FAIL pkg-maintainer "$f" "Maintainer='$maint', expected '$EXPECT_MAINTAINER' (P0-7)"
        fi
        if [ "$home" = "$EXPECTED_HOMEPAGE" ]; then
          rec PASS pkg-homepage "$f" "Homepage=$home"
        else
          rec FAIL pkg-homepage "$f" "Homepage='$home', expected '$EXPECTED_HOMEPAGE' (P0-7)"
        fi
        case "$arch" in
          amd64|arm64|i386|arm64hf) rec PASS pkg-arch "$f" "Architecture=$arch" ;;
          *) rec FAIL pkg-arch "$f" "unexpected Architecture=$arch" ;;
        esac
        if dpkg-deb -c "$path" | grep -qE '\.\./|^/' ; then
          rec FAIL archive-safety "$f" "unsafe member in deb"
        else
          rec PASS archive-safety "$f" "deb members are relative"
        fi
        if dpkg-deb -f "$path" Depends | grep -q 'libwxgtk3.2-dev'; then
          rec FAIL pkg-depends "$f" "development package fallback still present (P0-8)"
        else
          rec PASS pkg-depends "$f" "no dev-package fallback: $(dpkg-deb -f "$path" Depends | tr '\n' ' ')"
        fi
      else
        rec SKIP pkg-version "$f" "dpkg-deb not available"
      fi
      ;;

    *.rpm)
      if command -v rpm >/dev/null 2>&1; then
        rver=$(rpm -qp --qf '%{VERSION}-%{RELEASE}' "$path" 2>/dev/null || true)
        rname=$(rpm -qp --qf '%{NAME}' "$path" 2>/dev/null || true)
        case "$rver" in
          "$VERSION"|"$VERSION"-*) rec PASS pkg-version "$f" "version=$rver" ;;
          *) rec FAIL pkg-version "$f" "version=$rver, expected $VERSION" ;;
        esac
        [ -n "$rname" ] && rec PASS pkg-name "$f" "name=$rname"
        if rpm -qp --qf '%{REQUIRES}' "$path" 2>/dev/null | grep -qi 'libwxgtk.*dev'; then
          rec FAIL pkg-depends "$f" "development package fallback in Requires"
        else
          rec PASS pkg-depends "$f" "no dev-package fallback"
        fi
      else
        rec SKIP pkg-version "$f" "rpm not available"
      fi
      ;;

    *.msi)
      got=$(arch_of_pe_file "$path")
      want=$(expected_arch "$f")
      if [ "$got" = "$want" ]; then rec PASS pe-arch "$f" "MSI machine=$got"
      else rec FAIL pe-arch "$f" "MSI machine=$got, expected $want"; fi
      ;;

    *.exe)
      got=$(arch_of_pe_file "$path")
      want=$(expected_arch "$f")
      if [ "$got" = "$want" ]; then rec PASS pe-arch "$f" "installer machine=$got"
      else rec FAIL pe-arch "$f" "installer machine=$got, expected $want"; fi
      ;;

    *.dmg)
      # DMG ends with a 512-byte "koly" trailer
      if tail -c 512 "$path" | grep -q 'koly'; then
        rec PASS dmg-structure "$f" "koly trailer present"
      else
        rec FAIL dmg-structure "$f" "no koly trailer (not a UDIF dmg?)"
      fi
      ;;

    *_source.zip|*_source.tar.gz)
      case "$f" in
        *.zip)
          if python3 - "$path" <<'PY'
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
bad = [i.filename for i in z.infolist()
       if i.filename.startswith('/') or '..' in i.filename.split('/')]
sys.exit(1 if bad else 0)
PY
          then rec PASS archive-safety "$f" "source archive members are relative"
          else rec FAIL archive-safety "$f" "unsafe source archive member"; fi
          ;;
        *.tar.gz)
          if tar -tzf "$path" | grep -qE '(^/|(^|/)\.\.(/|$))'; then
            rec FAIL archive-safety "$f" "unsafe source archive member"
          else rec PASS archive-safety "$f" "source archive members are relative"; fi
          ;;
      esac
      ;;
  esac
done < <("$REPO_ROOT/scripts/release_contract.sh" expected --version "$VERSION" --scope github-packages)

# --- debug / temp junk anywhere in the directory ---------------------------
junk=$(find "$DIR" -maxdepth 1 -type f \( -name '*.pdb' -o -name '*.ilk' -o -name '*.tmp' \
       -o -name '*~' -o -name '*.swp' -o -name '.DS_Store' -o -name '*.exp' -o -name '*.idb' \) -print)
if [ -z "$junk" ]; then
  rec PASS no-junk "$DIR" "no debug/temp files staged"
else
  rec FAIL no-junk "$DIR" "junk staged: $junk"
fi

# --- checksum coverage (CORE-6) -------------------------------------------
if [ -f "$DIR/SHA256SUMS" ]; then
  (cd "$DIR" && sha256sum -c SHA256SUMS >/dev/null 2>&1) \
    && rec PASS checksum-verify "SHA256SUMS" "all digests verify" \
    || rec FAIL checksum-verify "SHA256SUMS" "sha256sum -c failed"
  missing_sum=0
  while IFS= read -r f; do
    grep -qE "[[:space:]]\./?$(printf '%s' "$f" | sed 's/[.[\*^$]/\\&/g')\$" "$DIR/SHA256SUMS" \
      || grep -qF " $f" "$DIR/SHA256SUMS" || { echo "NOT COVERED: $f"; missing_sum=1; }
  done < <( (cd "$DIR" && for g in *.zip *.tar.gz *.deb *.rpm *.exe *.msi *.dmg; do for x in $g; do [ -f "$x" ] && printf '%s\n' "$x"; done; done) )
  if [ "$missing_sum" -eq 0 ]; then
    rec PASS checksum-coverage "SHA256SUMS" "every staged package is covered"
  else
    rec FAIL checksum-coverage "SHA256SUMS" "artifact(s) not listed (see above)"
  fi
else
  rec FAIL checksum-coverage "SHA256SUMS" "missing"
fi

# --- evidence --------------------------------------------------------------
if [ -n "$EVIDENCE" ]; then
  {
    printf '{\n  "version": "%s",\n  "checks": [\n' "$VERSION"
    first=1
    for line in "${results[@]}"; do
      st=${line%%|*}; rest=${line#*|}
      chk=${rest%%|*}; rest=${rest#*|}
      subj=${rest%%|*}; det=${rest#*|}
      det=${det//\\/\\\\}; det=${det//\"/\\\"}
      [ $first -eq 1 ] || printf ',\n'
      first=0
      printf '    {"status": "%s", "check": "%s", "subject": "%s", "detail": "%s"}' \
        "$st" "$chk" "$subj" "$det"
    done
    printf '\n  ]\n}\n'
  } > "$EVIDENCE"
  echo "evidence written: $EVIDENCE"
fi

if [ "$failures" -ne 0 ]; then
  echo "validate_release_artifacts: $failures check(s) FAILED" >&2
  exit 1
fi
echo "validate_release_artifacts: all checks passed"
