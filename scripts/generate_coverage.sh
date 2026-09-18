#!/usr/bin/env bash
#
# Generates an lcov HTML report plus a machine-readable summary line.
#
# 2026-09-08: the final command used to be `lcov --list`, which prints a
# per-file TABLE ending in "Total:|85.7%". GitLab's coverage extractor for this
# job uses  /lines.*:\s*\d+\.\d+%/  -- and the table format never matches it.
# Coverage was therefore never actually captured, despite this script printing
# "Coverage summary for GitLab regex:" and the job passing. `lcov --summary`
# prints "  lines......: 85.7% (12 of 14 lines)", which does match.
# Both are emitted now: --list for a human reading the log, --summary for the
# regex.
#
# Also added: --ignore-errors for lcov 2.x, which is far stricter than 1.x and
# aborts on mismatched/negative counts instead of warning.

set -euo pipefail

if ! command -v lcov >/dev/null 2>&1; then
    echo "lcov not found; installing."
    apt-get update && apt-get install -y lcov
fi

LCOV_IGNORE=""
if lcov --version 2>/dev/null | grep -qE 'version 2'; then
    # lcov 2.x aborts where 1.x warned. Keep it non-fatal in CI.
    LCOV_IGNORE="--ignore-errors mismatch,negative,unused,empty,gcov"
fi

echo "Capturing coverage data..."
# shellcheck disable=SC2086
lcov --capture --directory build --output-file coverage.info $LCOV_IGNORE

echo "Filtering coverage data (system headers, tests, third-party, build tree)..."
# shellcheck disable=SC2086
lcov --remove coverage.info \
     '/usr/*' \
     '*/tests/*' \
     '*/test/*' \
     '*/external/*' \
     '*/build/*' \
     '*/vcpkg/*' \
     --output-file coverage_filtered.info $LCOV_IGNORE

echo "Generating HTML report..."
genhtml coverage_filtered.info --output-directory coverage --legend --show-details

echo ""
echo "Per-file breakdown:"
# shellcheck disable=SC2086
lcov --list coverage_filtered.info $LCOV_IGNORE

echo ""
echo "Coverage summary (this is the line GitLab's coverage regex matches):"
# shellcheck disable=SC2086
lcov --summary coverage_filtered.info $LCOV_IGNORE
