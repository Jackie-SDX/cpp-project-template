# ADR 002: Deterministic Cache Keys via hashFiles()

## Status
Accepted

## Context
The previous GitHub Actions workflows used timestamp-based cache keys (`string(TIMESTAMP ...)`). This resulted in a 100% cache miss rate on every run, defeating the purpose of caching and wasting compute minutes.

## Decision
Replace timestamp generation with deterministic hashing using GitHub's `hashFiles('**/CMakeLists.txt', '**/vcpkg.json')`. The cache key format is now `${{ runner.os }}-${{ matrix.config.name }}-${{ matrix.build_type }}-ccache-${{ hashFiles(...) }}`. We include a `restore-keys` fallback to allow partial cache hits.

## Consequences
- **Positive:** Massive reduction in CI build times. Efficient use of GitHub Actions storage.
- **Negative:** Cache invalidation requires modifying `CMakeLists.txt` or `vcpkg.json` (which is the desired behavior).