# ADR 003: Pinning CI Dependencies to SHAs

## Status
Accepted

## Context
Third-party GitHub Actions were pinned to mutable tags (e.g., `@master`, `@v4`). This introduces a severe supply-chain security risk; if a maintainer's account is compromised, malicious code could execute in our CI environment.

## Decision
All third-party actions are pinned to immutable 40-character commit SHAs. Dependabot will be configured to monitor these SHAs and automatically propose PRs when new versions are released.

## Consequences
- **Positive:** Eliminates tag-spoofing and supply-chain attacks.
- **Negative:** YAML files are slightly harder to read. Requires Dependabot configuration.