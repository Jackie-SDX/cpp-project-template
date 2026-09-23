# Release Archive Policy — Session Record

This document replaces the obsolete root `BUGS.txt` (which has served its purpose: all items it
listed are resolved or carried forward below) and records the 2026-09-23 change of the standalone
release archive policy on this repository.

| Field | Value |
|---|---|
| Date | 2026-09-23 |
| Target repository | `Jackie-SDX/cpp-project-template` |
| Origin | Issue #130 ("UPDATE ON DISTANT REPO") on the controlling fork |
| Affected release | `v0.0.8` |
| Document scope | Plan, actions, decisions, bugs observed, validation evidence, follow-ups |

## 1. Objective

Harden the standalone release archive policy so every upload "just works" for the platform it targets,
and stop shipping a format (`.7z`) that is niche on Windows and essentially unusable elsewhere.

Chosen approach — **Option A** (explicitly confirmed by the repository owner in the issue thread):

- remove the 20 `.7z` standalone archives entirely;
- keep the Linux `.zip` and macOS `.tar.gz` convenience archives;
- leave the installers and source archives untouched.

## 2. New policy

| Platform | Canonical standalone archive | Convenience archive | Installers (unchanged) |
|---|---|---|---|
| Windows | `.zip` | — | `.exe` (NSIS), `.msi` (WiX) |
| Linux | `.tar.gz` | `.zip` | `.deb`, `.rpm` |
| macOS | `.zip` | `.tar.gz` | `.dmg` |

`.7z` is never generated, uploaded, checksummed, or published. The historical Windows
`cpack -G 7Z` alternative remains in the source as a **commented-out, disabled block**
in the Windows packaging steps so the option stays documented without shipping (see
`.github/workflows/release.yml`, `.github/workflows/windows-package-smoke.yml`,
`.github/workflows/windows-arm64-package-smoke.yml`, and GitLab parity comments).
The `7zip`/`7z` tool provisioning retained by the Windows runners exists solely so the
commented alternative can be restored as-is.

## 3. Inventory math

| Class | Before | After | Delta |
|---|---|---|---|
| Windows core packages (7 toolchains × 4 formats) | 28 | 21 | −7 `.7z` |
| Windows ARM64 packages (2 × 4 formats) | 8 | 6 | −2 `.7z` |
| Linux packages (5 × 5 formats) | 25 | 20 | −5 `.7z` |
| macOS packages (6 × 4 formats) | 24 | 18 | −6 `.7z` |
| **Total packages** | **85** | **65** | **−20 `.7z`** |
| Source archives | 2 | 2 | — |
| Global `SHA256SUMS` lines | 87 | 67 | −20 |
| Release assets | 88 | 68 | −20 |

## 4. Bugs and observations found during inspection

- `vcpkg-cache-warmup.yml` provisions `7zip` on the Windows runner and uses
  `7z | Select-Object -First 1` purely as a version probe — tooling, not artifact
  generation; left unchanged.
- `docs/install.md` lines 243-244 point at third-party `mingw-builds-binaries` `.7z`
  downloads (niXman releases) — third-party toolchain archives, out of scope; left unchanged.
- `cmake/cpack_module.cmake` and the top-level `CMakeLists.txt` contain no `.7z` logic —
  no changes needed there.
- No `.7z` references exist under `.circleci/`, `HISTORICAL/`, `packaging/`, or `scripts/`.
- `v0.0.5` (the current latest prerelease at the time of this change) still carries 88
  assets including `.7z`; that is a historical tag and is intentionally left untouched.

## 5. Files changed

GitHub Actions workflows:

- `.github/workflows/release.yml` — header + policy banner; removed the two
  `(cd instdir && cmake -E tar cf ... --format=7zip .)` lines in the `package` and
  `expanded-package` Linux/macOS steps; removed the `cmake -E tar --format=7zip`
  block in the `expanded-package` Windows step; commented-out the `cpack -G 7Z`
  alternative in the `package` "Package Windows" step; removed `.7z` from the
  expected/actual inventory globs and printf lists in `validate-release` and
  `publish`; updated counts 85 → 65 and `SHA256SUMS` 87 → 67.
- `.github/workflows/ci.yml` — Linux packaging smoke no longer generates or asserts
  `linux-gcc-x64.7z`.
- `.github/workflows/windows-package-smoke.yml` — header; `cpack -G 7Z` block now a
  commented-out disabled alternative; `.7z` removed from the expected-artifacts list.
- `.github/workflows/windows-arm64-package-smoke.yml` — header; `cpack -G 7Z` block
  now a commented-out disabled alternative; `.7z` removed from the expected list and
  the `Get-FileHash` glob.
- `.gitlab/.gitlab-ci.yml` — removed the Windows `cpack -C Release -G 7Z` step and the
  `*.7z` copy/upload in the Windows/Linux/macOS legs (with a comment documenting the
  policy); updated the related format mentions in comments.

Documentation:

- `docs/PROJECT_DOCUMENTATION.md` — current-pipeline inventory count updated to 65,
  release-flow ascii diagram updated (65 packages / 67 `SHA256SUMS` lines), new
  § 6.5 archive-format policy decision record, and `BUGS.txt` references rewritten to
  the new session document.
- `docs/install.md` — Archive section now documents the platform archive policy table.
- `RELEASE_ARCHIVE_POLICY_SESSION.md` — this document (replaces `BUGS.txt`).
- `BUGS.txt` — deleted (obsolete; residual follow-ups carried into § 7 below).

## 6. Validation

- YAML parse of every edited workflow plus `workflow-lint.yml`'s `actionlint` gate.
- PowerShell/bash syntax checks of the edited inline script blocks.
- Grep proof: no active (non-comment) `.7z` path remains anywhere in the pipeline
  (GitHub Actions + GitLab CI).
- Refactored inventory-validator simulation: 65 expected packages, 67 `SHA256SUMS`
  lines, 68 release assets.
- CI verification on the pull request branch (GitHub Actions) before merge.
- Post-release asset inspection of `v0.0.8` via the GitHub API: 68 assets, correct
  extensions, no `.7z`.

## 7. Residual follow-ups (carried over from `BUGS.txt`)

1. **Windows MinGW CI** — investigate deterministic toolchain provisioning,
   ABI-stable cache namespaces, and whether the desired vcpkg packages are actually
   restored versus rebuilt.
2. **Windows LLVM CI** — investigate deterministic LLVM toolchain discovery, exact
   ABI compatibility, and package-level binary-cache reuse.
3. **Cache observability** — distinguish GitHub Actions archive hits, vcpkg
   binary-cache hits, and source rebuilds in logs; a successful Actions cache step is
   not proof that vcpkg skipped compilation.
4. **ARM64 Windows package smoke** — remains a separately documented known bug and is
   intentionally left unchanged.

Follow-up items are tracked as GitHub issues after the `v0.0.8` release.

## 8. Team / evidence note

Work was executed by the autonomous engineering agent (OpenCode) in an isolated session
branch. A second-brain peer review (GitHub Copilot CLI) was requested via the controller's
peer-invitation helper but the Copilot CLI was not available in this execution environment;
this is recorded as a quality-degradation event, not a blocker. In its place the change was
subjected to the repo's own CI gates (actionlint 1.7.12, PR packaging smoke, full build
matrix), local script-syntax validation, an executed simulation of the actual
inventory/preflight logic, and an adversarial self-review of the complete diff before
publication.