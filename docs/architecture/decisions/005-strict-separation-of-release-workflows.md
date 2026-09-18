# ADR 005: Strict Separation of Release Workflows

## Status
Accepted

## Context
The release packaging logic (CPack, NSIS, WiX) was embedded in the standard build workflow and triggered on every Pull Request. This wasted compute minutes building installers that were never used.

## Decision
Create a dedicated `release.yml` workflow that triggers **only** on semantic version tags (`v*`). The standard `ci.yml` will handle PR validation and matrix testing without generating installers.

## Consequences
- **Positive:** Significant reduction in PR compute costs. Clearer separation of concerns.
- **Negative:** Installers are only generated for tagged releases, not for PR artifacts (acceptable trade-off).