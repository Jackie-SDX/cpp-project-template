#!/usr/bin/env bash
set -ex

# Generate compilation database for clang-tidy
cmake -S . -B build-tidy -D CMAKE_EXPORT_COMPILE_COMMANDS=ON -G Ninja -D CMAKE_MAKE_PROGRAM=ninja

echo "Running clang-tidy on source files..."
# Find all target source files, aggressively excluding standard unneeded directories
find . -type f \( -name "*.cpp" -o -name "*.c" -o -name "*.hpp" -o -name "*.h" \) \
     -not -path "./build*/*" \
     -not -path "./external/*" \
     -not -path "./.git/*" \
     -not -path "./docs/*" \
     -print0 | xargs -0 clang-tidy -p build-tidy