#!/usr/bin/env bash
# runtime_deps_elf.sh -- runtime dependency report for FINAL Linux artifacts
# (USEFUL-4). Reads the staged release directory, unpacks each Linux archive
# and reports, for every shipped ELF executable/shared object:
#   * bundled    : the DT_NEEDED soname ships inside the same package
#   * system     : the soname resolves on a supported host (ldconfig -p / dpkg)
#   * missing    : neither
#   * host-only  : interpreter (PT_INTERP, e.g. /lib64/ld-linux-x86-64.so.2)
# Output: JSON report (path --out) plus a human summary on stdout.
#
#   runtime_deps_elf.sh --dir RELEASE_DIR --out REPORT.json
set -euo pipefail

DIR="" OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR=$2; shift 2 ;;
    --out) OUT=$2; shift 2 ;;
    *) echo "runtime_deps_elf: unknown argument $1" >&2; exit 2 ;;
  esac
done
[ -n "$DIR" ] && [ -n "$OUT" ] || { echo "usage: runtime_deps_elf.sh --dir DIR --out FILE" >&2; exit 2; }
[ -d "$DIR" ] || { echo "not a directory: $DIR" >&2; exit 2; }
command -v readelf >/dev/null || { echo "readelf (binutils) is required" >&2; exit 2; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
json="$work/entries.jsonl"
: > "$json"

classify_one_soname() { # $1=soname $2=pkgroot
  soname=$1 root=$2
  if find "$root" -name "$soname" -type f 2>/dev/null | grep -q .; then
    echo bundled; return
  fi
  if ldconfig -p 2>/dev/null | grep -qF "$soname"; then
    echo system; return
  fi
  if command -v dpkg-query >/dev/null 2>&1 && dpkg-query -S "/$soname" >/dev/null 2>&1; then
    echo system; return
  fi
  echo missing
}

scan_tree() { # $1=artifact-name $2=extracted-root
  art=$1 root=$2
  while IFS= read -r elf; do
    rel=${elf#"$root"/}
    # ELF class/machine
    interp=$(readelf -l "$elf" 2>/dev/null | sed -n 's/.*interpreter: \([^]]*\).*/\1/p' | head -1 || true)
    if [ -n "$interp" ]; then
      esc=${interp//\\/\\\\}; esc=${esc//\"/\\\"}
      printf '{"artifact":"%s","file":"%s","kind":"host-only","name":"%s","detail":"PT_INTERP"}\n' \
        "$art" "$rel" "$esc" >> "$json"
    fi
    readelf -d "$elf" 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\].*/\1/p' |
    while IFS= read -r soname; do
      [ -n "$soname" ] || continue
      cls=$(classify_one_soname "$soname" "$root")
      printf '{"artifact":"%s","file":"%s","kind":"%s","name":"%s"}\n' \
        "$art" "$rel" "$cls" "$soname" >> "$json"
    done
  done < <(find "$root" -type f -exec sh -c 'head -c4 "$1" 2>/dev/null | grep -q "ELF" && printf "%s\n" "$1"' _ {} \; 2>/dev/null)
}

# --- tar.gz install trees --------------------------------------------------
for f in "$DIR"/*.tar.gz; do
  [ -f "$f" ] || continue
  case "$f" in *_source.tar.gz) continue ;; esac
  name=$(basename "$f")
  case "$name" in *_linux-*) ;; *) continue ;; esac
  x="$work/tar"; rm -rf "$x"; mkdir -p "$x"
  tar -xzf "$f" -C "$x"
  scan_tree "$name" "$x"
done

# --- deb packages ----------------------------------------------------------
for f in "$DIR"/*.deb; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  x="$work/deb"; rm -rf "$x"; mkdir -p "$x"
  if command -v dpkg-deb >/dev/null 2>&1; then
    dpkg-deb -x "$f" "$x"
    scan_tree "$name" "$x"
  fi
done

# --- rpm packages (best effort: needs rpm2cpio+cpio) -----------------------
for f in "$DIR"/*.rpm; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  x="$work/rpm"; rm -rf "$x"; mkdir -p "$x"
  if command -v rpm2cpio >/dev/null 2>&1 && command -v cpio >/dev/null 2>&1; then
    if (cd "$x" && rpm2cpio "$f" | cpio -idm --quiet 2>/dev/null); then
      scan_tree "$name" "$x"
    fi
  fi
done

total=$(wc -l < "$json" | tr -d ' ')
bundled=$(grep -c '"kind":"bundled"' "$json" || true)
system=$(grep -c '"kind":"system"' "$json" || true)
missing=$(grep -c '"kind":"missing"' "$json" || true)
hostonly=$(grep -c '"kind":"host-only"' "$json" || true)

{
  printf '{\n'
  printf '  "schema": "cpp-project-template.runtime-dependencies.elf.v1",\n'
  printf '  "host": "%s",\n' "$(uname -srm)"
  printf '  "summary": {"total": %s, "bundled": %s, "system": %s, "missing": %s, "hostOnly": %s},\n' \
    "$total" "$bundled" "$system" "$missing" "$hostonly"
  printf '  "entries": [\n'
  if [ "$total" -gt 0 ]; then
    # JSON array join: `paste -sd ",\n"` treats "," and newline as TWO
    # alternating delimiters (one separator per list entry), which produced
    # some ",\" and some newline-only separators -- invalid JSON. Join with
    # awk so every separator is exactly ",\n".
    awk '{ printf "%s%s", (NR>1 ? ",\n" : ""), "    " $0 } END { printf "\n" }' "$json"
  fi
  printf '  ]\n}\n'
} > "$OUT"

echo "runtime_deps_elf: total=$total bundled=$bundled system=$system missing=$missing host-only=$hostonly -> $OUT"
if [ "$missing" -ne 0 ]; then
  echo "runtime_deps_elf: MISSING dependencies:" >&2
  grep '"kind":"missing"' "$json" >&2 || true
  exit 1
fi
