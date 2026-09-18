# ADR 004: Manual Coverity Scans

## Status
Accepted

## Context
Coverity Scan was previously configured to run on every push to `main`. This exhausted the project's weekly scan quota and unnecessarily delayed the main CI pipeline.

## Decision
Move Coverity execution to a strictly `workflow_dispatch` trigger. It will no longer run automatically on pushes or PRs.

## Consequences
- **Positive:** Preserves scan quotas. Speeds up standard CI feedback loops.
- **Negative:** Requires manual intervention or an external cron job to trigger scans periodically.