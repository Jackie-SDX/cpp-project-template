#!/usr/bin/env bash
# make_deterministic_tarball.sh -- byte-reproducible .tar.gz (USEFUL-1).
#
#   make_deterministic_tarball.sh --epoch SECONDS --input DIR --output FILE
#                                  [--prefix NAME]
#
# Normalizes everything a tarball records:
#   * entry order      : sorted by path (--sort=name)
#   * mtime            : forced to the release epoch (tag commit time)
#   * owner/group      : root/root numeric (0/0), no user/group names
#   * format           : gnu (no pax headers carrying atime/ctime)
#   * compression      : gzip -n (no embedded file name / timestamp)
#
# The epoch must come from the tagged commit:
#   git log -1 --format=%ct  (SOURCE_DATE_EPOCH)
set -euo pipefail

epoch="" input="" output="" prefix=""
while [ $# -gt 0 ]; do
  case "$1" in
    --epoch) epoch=$2; shift 2 ;;
    --input) input=$2; shift 2 ;;
    --output) output=$2; shift 2 ;;
    --prefix) prefix=$2; shift 2 ;;
    *) echo "make_deterministic_tarball: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$epoch" ] || { echo "make_deterministic_tarball: --epoch is required" >&2; exit 2; }
[ -n "$input" ] || { echo "make_deterministic_tarball: --input is required" >&2; exit 2; }
[ -n "$output" ] || { echo "make_deterministic_tarball: --output is required" >&2; exit 2; }
[ -d "$input" ] || { echo "make_deterministic_tarball: not a directory: $input" >&2; exit 2; }
case "$epoch" in ''|*[!0-9]*) echo "make_deterministic_tarball: --epoch must be a unix timestamp" >&2; exit 2 ;; esac

mkdir -p "$(dirname -- "$output")"
tmp=$(mktemp "${output}.tmp.XXXXXX")
trap 'rm -f "$tmp" "$tmp.gz"' EXIT

if [ -n "$prefix" ]; then
  stage=$(mktemp -d)
  trap 'rm -f "$tmp" "$tmp.gz"; rm -rf "$stage"' EXIT
  mkdir -p "$stage/$prefix"
  # copy contents (not the directory itself), preserving executability
  (cd "$input" && tar -cf - .) | (cd "$stage/$prefix" && tar -xf -)
  tar --format=gnu \
      --sort=name \
      --owner=0 --group=0 --numeric-owner \
      --mtime="@$epoch" \
      -C "$stage" -cf "$tmp" "$prefix"
else
  # no prefix: reproduce the historical layout (entries ".", "./bin", ...)
  tar --format=gnu \
      --sort=name \
      --owner=0 --group=0 --numeric-owner \
      --mtime="@$epoch" \
      -C "$input" -cf "$tmp" .
fi

gzip -n -9 -c "$tmp" > "$tmp.gz"
mv "$tmp.gz" "$output"
rm -f "$tmp"

echo "make_deterministic_tarball: wrote $output (epoch=$epoch, prefix=${prefix:-none})" >&2
