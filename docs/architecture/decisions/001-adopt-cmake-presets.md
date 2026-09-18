# ADR 001: Adopt CMakePresets.json

## Status
Accepted

## Context
The CI pipelines previously relied on custom wrapper scripts (`.github/scripts/configure.cmake`) or raw command-line arguments that drifted from local developer environments. This caused "works on my machine" discrepancies and made CI YAML files overly verbose.

## Decision
We will adopt `CMakePresets.json` as the single source of truth for build configurations (Debug, Release, CI-specific flags). CI pipelines will invoke `cmake --preset <name>` instead of manually specifying generators, toolchains, and cache variables.

## Consequences
- **Positive:** Parity between local IDEs (VS Code, CLion) and CI. Drastically simplified CI YAML files.
- **Negative:** Requires developers to learn CMake Presets syntax.
- **Alternatives Considered:** Keeping wrapper scripts (rejected due to maintenance burden).