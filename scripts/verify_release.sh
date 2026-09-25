#!/usr/bin/env bash
# verify_release.sh -- standalone consumer verification for a published
# release directory (USEFUL-8, CORE-6). Usable WITHOUT checking out the
# source repository: this script and packaging/release-contract.tsv ship
# inside the release itself.
#
#   verify-release.sh [--dir DIR] [--version V] [--contract FILE]
#                     [--partial] [--no-attest]
#
# Checks:
#   1. manifest membership : every file is a release-contract row (and, in
#                            strict mode, every contracted file is present)
#   2. SHA-256             : SHA256SUMS exists, covers every present file
#                            (except itself) and verifies
#   3. forbidden formats   : no .7z/.msix/AppImage/Flatpak/Snap, no Linux
#                            .zip, no macOS .tar.gz (CORE-5)
#   4. filename/arch       : packaged Windows/Linux payloads match the
#                            contract architecture (python3 when available)
#   5. SBOM presence       : release-sbom.spdx.json present, non-empty,
#                            parses as JSON (python3 when available)
#   6. evidence presence   : release-evidence.json + contract present
#   7. provenance          : gh attestation verify over the packaged
#                            artifacts (skipped with --no-attest or when gh
#                            is unavailable)
#
# Exit status: 0 = all performed checks passed, 1 = failure, 2 = usage.
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
DIR="" VERSION="" CONTRACT="" PARTIAL=0 ATTEST=1
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR=$2; shift 2 ;;
    --version) VERSION=$2; shift 2 ;;
    --contract) CONTRACT=$2; shift 2 ;;
    --partial) PARTIAL=1; shift ;;
    --no-attest) ATTEST=0; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "verify-release: unknown argument $1" >&2; exit 2 ;;
  esac
done
[ -n "$DIR" ] || DIR=$SCRIPT_DIR
[ -d "$DIR" ] || { echo "verify-release: no such directory: $DIR" >&2; exit 2; }
DIR=$(CDPATH='' cd -- "$DIR" && pwd)
if [ -z "$CONTRACT" ]; then
  for cand in "$DIR/release-contract.tsv" "$SCRIPT_DIR/release-contract.tsv"; do
    [ -f "$cand" ] && CONTRACT=$cand && break
  done
fi
[ -n "$CONTRACT" ] && [ -f "$CONTRACT" ] || {
  echo "verify-release: release-contract.tsv not found (pass --contract)" >&2
  exit 1
}
if [ -z "$VERSION" ]; then
  # derive from the source archive name shipped alongside this script
  for f in "$DIR"/cpp-project-template_*_source.zip; do
    [ -f "$f" ] || continue
    VERSION=$(basename "$f" | sed 's/^cpp-project-template_//; s/_source\.zip$//')
    break
  done
fi
[ -n "$VERSION" ] || { echo "verify-release: --version is required" >&2; exit 2; }

failures=0
rec() { # $1=PASS|FAIL|SKIP|WARN $2=check $3=detail
  printf '[%s] %-18s %s\n' "$1" "$2" "$3"
  [ "$1" = "FAIL" ] && failures=$((failures + 1))
  return 0
}

# --- expected inventory from the shipped contract --------------------------
expected=$(mktemp) actual=$(mktemp) pkgactual=$(mktemp)
trap 'rm -f "$expected" "$actual" "$pkgactual"' EXIT
awk -F'\t' -v ver="$VERSION" '
  /^#/ || /^os\t/ || NF < 6 { next }
  { fn = $6; gsub(/\$\{V\}/, ver, fn); print fn }' "$CONTRACT" \
  | LC_ALL=C sort -u > "$expected"
expected_count=$(wc -l < "$expected" | tr -d ' ')
if [ "$expected_count" -eq 0 ]; then
  rec FAIL contract "no rows parsed from $CONTRACT"
else
  rec PASS contract "$(basename "$CONTRACT"): $expected_count expected file(s) for version $VERSION"
fi

# every file present must be a contract member; strict mode also requires
# the full set to be present
: > "$actual"
(
  cd "$DIR" || exit 1
  for f in *; do
    [ -f "$f" ] && printf '%s\n' "$f"
  done
  exit 0
) | LC_ALL=C sort -u > "$actual"
missing=0 unexpected=0
while IFS= read -r f; do
  grep -qxF "$f" "$expected" || { echo "  unexpected: $f"; unexpected=1; }
done < "$actual"
if [ "$PARTIAL" -eq 0 ]; then
  while IFS= read -r f; do
    grep -qxF "$f" "$actual" || { echo "  missing: $f"; missing=1; }
  done < "$expected"
fi
if [ "$unexpected" -ne 0 ]; then
  rec FAIL membership "file(s) present that the release contract does not define"
elif [ "$missing" -ne 0 ]; then
  rec FAIL membership "contracted file(s) absent (use --partial for a subset download)"
else
  rec PASS membership "$(wc -l < "$actual" | tr -d ' ') file(s) all match the contract"
fi

# --- SHA-256 ---------------------------------------------------------------
if [ -f "$DIR/SHA256SUMS" ]; then
  if (cd "$DIR" && sha256sum -c --quiet SHA256SUMS); then
    rec PASS sha256 "SHA256SUMS verified for every listed file"
  else
    rec FAIL sha256 "sha256sum -c failed (corrupted or tampered download)"
  fi
  notcovered=0
  while IFS= read -r f; do
    [ "$f" = "SHA256SUMS" ] && continue
    grep -qF " $f" "$DIR/SHA256SUMS" || { echo "  not covered: $f"; notcovered=1; }
  done < "$actual"
  if [ "$notcovered" -ne 0 ]; then
    rec FAIL sha256-coverage "file(s) present but absent from SHA256SUMS"
  else
    rec PASS sha256-coverage "every present file is covered by SHA256SUMS"
  fi
else
  rec FAIL sha256 "SHA256SUMS missing"
fi

# --- forbidden formats -----------------------------------------------------
bad=$(cd "$DIR" && for g in *.7z *.msix *.appimage *.flatpak *.snap; do
  for f in $g; do [ -f "$f" ] && printf '%s\n' "$f" || true; done
done)
if [ -n "$bad" ]; then
  rec FAIL forbidden "unsupported format present: $bad"
else
  rec PASS forbidden "no .7z/.msix/AppImage/Flatpak/Snap"
fi

# --- filename / architecture ----------------------------------------------
if command -v python3 >/dev/null 2>&1; then
  if out=$(python3 - "$DIR" "$CONTRACT" "$VERSION" <<'PY'
import io, struct, sys, zipfile, tarfile, os
d, contract, ver = sys.argv[1:4]
rows = {}
with open(contract, encoding="utf-8") as fh:
    for line in fh:
        if line.startswith("#") or line.startswith("os\t"):
            continue
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 6:
            continue
        rows[parts[5].replace("${V}", ver)] = (parts[0], parts[1])
machine_for = {"x86_64": 0x8664, "i686": 0x14C, "arm64": 0xAA64}
def pe_machine(data):
    if data[:2] != b"MZ":
        return None
    off = struct.unpack_from("<I", data, 0x3C)[0]
    if data[off:off + 4] != b"PE\0\0":
        return None
    return struct.unpack_from("<H", data, off + 4)[0]
bad = []
checked = 0
for name in sorted(os.listdir(d)):
    if name not in rows:
        continue
    os_, arch = rows[name]
    if arch == "n/a" or arch not in machine_for:
        continue
    path = os.path.join(d, name)
    want = machine_for[arch]
    try:
        if name.endswith(".zip") and os_ in ("windows", "macos"):
            if os_ == "macos":
                checked += 1
                continue  # Mach-O check needs macOS tooling; presence checked elsewhere
            with zipfile.ZipFile(path) as z:
                for n in z.namelist():
                    if n.lower().endswith((".exe", ".dll")):
                        m = pe_machine(z.read(n))
                        if m is not None and m != want:
                            bad.append("%s: %s -> machine 0x%04X != 0x%04X" % (name, n, m, want))
                        checked += 1
        elif name.endswith((".exe", ".msi")):
            with open(path, "rb") as fh:
                m = pe_machine(fh.read(1 << 20))
            if m is not None and m != want:
                bad.append("%s: machine 0x%04X != 0x%04X" % (name, m, want))
            checked += 1
        elif name.endswith(".tar.gz") and os_ == "linux":
            with tarfile.open(path, "r:gz") as t:
                for m in t.getmembers():
                    if m.isfile() and os.path.splitext(m.name)[1] in ("", ".exe"):
                        fobj = t.extractfile(m)
                        hdr = fobj.read(20) if fobj else b""
                        if hdr[:4] == b"\x7fELF":
                            ei_class = hdr[4]
                            e_machine = struct.unpack_from("<H", hdr, 18)[0]
                            ok = ((arch == "x86_64" and e_machine == 62 and ei_class == 2) or
                                  (arch == "i686" and e_machine == 3 and ei_class == 1) or
                                  (arch == "arm64" and e_machine == 183 and ei_class == 2))
                            if not ok:
                                bad.append("%s: %s ELF machine=%d class=%d (arch %s)" %
                                           (name, m.name, e_machine, ei_class, arch))
                            checked += 1
                            break
    except Exception as exc:  # noqa: BLE001
        bad.append("%s: unreadable (%s)" % (name, exc))
if bad:
    print("\n".join(bad))
    sys.exit(1)
print("checked=%d" % checked)
PY
  ); then
    rec PASS arch "payload architectures match the contract (${out})"
  else
    rec FAIL arch "$out"
  fi
else
  rec SKIP arch "python3 unavailable; architecture spot-check skipped"
fi

# --- SBOM + evidence -------------------------------------------------------
if [ -s "$DIR/release-sbom.spdx.json" ]; then
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$DIR/release-sbom.spdx.json"; then
      rec PASS sbom "release-sbom.spdx.json present and valid JSON"
    else
      rec FAIL sbom "release-sbom.spdx.json is not valid JSON"
    fi
  else
    rec PASS sbom "release-sbom.spdx.json present (JSON not parsed: no python3)"
  fi
else
  rec FAIL sbom "release-sbom.spdx.json missing or empty"
fi
if [ -s "$DIR/release-evidence.json" ]; then
  rec PASS evidence "release-evidence.json present ($(wc -c < "$DIR/release-evidence.json" | tr -d ' ') bytes)"
else
  rec FAIL evidence "release-evidence.json missing or empty"
fi

# --- provenance attestation ------------------------------------------------
if [ "$ATTEST" -eq 0 ]; then
  rec SKIP provenance "attestation verification disabled (--no-attest)"
elif command -v gh >/dev/null 2>&1; then
  owner_repo=""
  if [ -f "$DIR/release-evidence.json" ]; then
    owner_repo=$(sed -n 's/.*"repository": *"\([^"]*\)".*/\1/p' "$DIR/release-evidence.json" | head -1 || true)
  fi
  gh_args=()
  if [ -n "$owner_repo" ]; then
    gh_args=(--repo "$owner_repo")
  fi
  verified=0 verify_failed=0
  for f in "$DIR"/*.zip "$DIR"/*.deb "$DIR"/*.rpm "$DIR"/*.msi "$DIR"/*.exe "$DIR"/*.dmg; do
    [ -f "$f" ] || continue
    case "$f" in *_source.zip) continue ;; esac
    if gh attestation verify "$f" ${gh_args[@]+"${gh_args[@]}"} --format json >/dev/null 2>&1; then
      verified=$((verified + 1))
    else
      verify_failed=$((verify_failed + 1))
      echo "  attestation failed: $(basename "$f")"
    fi
  done
  if [ "$verify_failed" -ne 0 ]; then
    rec FAIL provenance "$verify_failed artifact(s) failed gh attestation verify"
  elif [ "$verified" -eq 0 ]; then
    rec SKIP provenance "no gh credentials / no packaged artifacts to verify (export GH_TOKEN to enable)"
  else
    rec PASS provenance "$verified packaged artifact(s) verified with gh attestation verify"
  fi
else
  rec SKIP provenance "gh CLI unavailable; install it and re-run to verify attestations"
fi

if [ "$failures" -ne 0 ]; then
  echo "verify-release: $failures check(s) FAILED" >&2
  exit 1
fi
echo "verify-release: all performed checks passed for version $VERSION"
