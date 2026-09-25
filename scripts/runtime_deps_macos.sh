#!/usr/bin/env bash
# runtime_deps_macos.sh -- runtime dependency report for FINAL macOS payloads
# (USEFUL-4). Walks an extracted install tree / .app and records every
# LC_LOAD_DYLIB reference with `otool -L`, classifying each as:
#   * bundled    : the dylib ships inside the payload (Frameworks/ or lib/)
#   * system     : under /usr/lib or /System/Library
#   * external   : Homebrew/other absolute path (documented, not bundled --
#                  macOS dylib bundling beyond the .app is out of scope here)
#   * rpath      : @rpath/... reference resolved inside the payload
# Must run on macOS (otool). Exit 1 when a dependency resolves nowhere.
#
#   runtime_deps_macos.sh --root DIR --out REPORT.json
set -euo pipefail

ROOT="" OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT=$2; shift 2 ;;
    --out) OUT=$2; shift 2 ;;
    *) echo "runtime_deps_macos: unknown argument $1" >&2; exit 2 ;;
  esac
done
[ -n "$ROOT" ] && [ -n "$OUT" ] || { echo "usage: runtime_deps_macos.sh --root DIR --out FILE" >&2; exit 2; }
[ -d "$ROOT" ] || { echo "no such directory: $ROOT" >&2; exit 2; }
command -v otool >/dev/null 2>&1 || { echo "otool not available (run on macOS)" >&2; exit 2; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
json="$work/entries.jsonl"
: > "$json"

while IFS= read -r bin; do
  rel=${bin#"$ROOT"/}
  file "$bin" 2>/dev/null | grep -q 'Mach-O' || continue
  otool -L "$bin" | tail -n +2 | while IFS= read -r line; do
    dep=$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/ (compatibility.*$//')
    [ -n "$dep" ] || continue
    case "$dep" in
      /usr/lib/*|/System/Library/*) cls=system ;;
      @rpath/*|@executable_path/*|@loader_path/*)
        base=$(basename "$dep")
        if find "$ROOT" -name "$base" | grep -q .; then cls=bundled; else cls=missing; fi
        ;;
      /*)
        base=$(basename "$dep")
        if find "$ROOT" -name "$base" | grep -q .; then cls=bundled; else cls=external; fi
        ;;
      *) cls=missing ;;
    esac
    printf '{"file":"%s","kind":"%s","name":"%s"}\n' "$rel" "$cls" "$dep" >> "$json"
  done
done < <(find "$ROOT" -type f \( -perm -u+x -o -name '*.dylib' \) 2>/dev/null)

total=$(wc -l < "$json" | tr -d ' ')
bundled=$(grep -c '"kind":"bundled"' "$json" || true)
system=$(grep -c '"kind":"system"' "$json" || true)
external=$(grep -c '"kind":"external"' "$json" || true)
missing=$(grep -c '"kind":"missing"' "$json" || true)

{
  printf '{\n'
  printf '  "schema": "cpp-project-template.runtime-dependencies.macos.v1",\n'
  printf '  "summary": {"total": %s, "bundled": %s, "system": %s, "external": %s, "missing": %s},\n' \
    "$total" "$bundled" "$system" "$external" "$missing"
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

echo "runtime_deps_macos: total=$total bundled=$bundled system=$system external=$external missing=$missing -> $OUT"
if [ "$missing" -ne 0 ]; then
  echo "runtime_deps_macos: MISSING references:" >&2
  grep '"kind":"missing"' "$json" >&2 || true
  exit 1
fi
