# Release Archive Policy — Session Record

This document replaces the obsolete root `BUGS.txt` (which has served its purpose: all items it
listed are resolved or carried forward below) and records the 2026-09-23 changes to the standalone
release archive policy on this repository, including the shift to the **strict
one-archive-per-platform** rule for `v0.0.9`.

| Field | Value |
|---|---|
| Date | 2026-09-23 |
| Target repository | `Jackie-SDX/cpp-project-template` |
| Origin | Issue #130 ("UPDATE ON DISTANT REPO") on the controlling fork |
| Affected releases | `v0.0.8`, `v0.0.9` |
| Document scope | Plan, actions, decisions, bugs observed, validation evidence, follow-ups |

## 1. Objective

Harden the standalone release archive policy so every upload "just works" for the platform it targets.

Policy history on this date:

- **`v0.0.8` (Option A, merged via PR #8):** removed the 20 `.7z` standalone archives entirely;
  kept the Linux `.zip` and macOS `.tar.gz` convenience archives; installers and source archives
  untouched.
- **`v0.0.9` (strict policy, supersedes Option A):** after inspection, the existing `v0.0.8`
  assets still shipped two standalone archives per Linux/macOS toolchain (Linux `.zip` + `.tar.gz`,
  macOS `.tar.gz` + `.zip`). Per explicit owner direction in the issue thread, the convenience
  archives were dropped so **each platform ships exactly one standalone archive per toolchain**.

## 2. New policy (current, `v0.0.9`)

| Platform | Standalone archive (only) | Installers (unchanged) |
|---|---|---|
| Windows | `.zip` | `.exe` (NSIS), `.msi` (WiX) |
| Linux | `.tar.gz` | `.deb`, `.rpm` |
| macOS | `.zip` | `.dmg` |

`.7z` is never generated, uploaded, checksummed, or published. The historical Windows
`cpack -G 7Z` alternative remains in the source as a **commented-out, disabled block**
in the Windows packaging steps so the option stays documented without shipping (see
`.github/workflows/release.yml`, `.github/workflows/windows-package-smoke.yml`,
`.github/workflows/windows-arm64-package-smoke.yml`, and GitLab parity comments).
The `7zip`/`7z` tool provisioning retained by the Windows runners exists solely so the
commented alternative can be restored as-is.

## 3. Inventory math

| Class | Before (85) | After Option A (65) | After strict policy (54) |
|---|---|---|---|
| Windows core packages (7 toolchains × 3 formats) | 28 | 21 | 21 |
| Windows ARM64 packages (2 × 3 formats) | 8 | 6 | 6 |
| Linux packages (5 × 3 formats) | 25 | 20 | 15 |
| macOS packages (6 × 3 formats) | 24 | 18 | 12 |
| **Total packages** | **85** | **65** | **54** |
| Source archives | 2 | 2 | 2 |
| Global `SHA256SUMS` lines | 87 | 67 | 56 |
| Release assets | 88 | 68 | 57 |

## 4. Bugs and observations found during inspection

- `vcpkg-cache-warmup.yml` provisions `7zip` on the Windows runner and uses
  `7z | Select-Object -First 1` purely as a version probe — tooling, not artifact
  generation; left unchanged.
- `docs/install.md` lines 243-244 point at third-party `mingw-builds-binaries` `.7z`
  downloads (niXman releases) — third-party toolchain archives, out of scope; left unchanged.
- `cmake/cpack_module.cmake` and the top-level `CMakeLists.txt` contain no `.7z` logic —
  no changes needed there.
- No `.7z` references exist under `.circleci/`, `HISTORICAL/`, `packaging/`, or `scripts/`.
- `v0.0.5` (a historical prerelease) still carries 88 assets including `.7z`; that is a
  historical tag and is intentionally left untouched.
- `v0.0.8` still shipped Linux `.zip` and macOS `.tar.gz` convenience archives alongside
  the canonical archives. This was the direct trigger for the strict one-archive-per-platform
  policy in `v0.0.9`.

## 5. Files changed

GitHub Actions workflows (`v0.0.8` + `v0.0.9` combined):

- `.github/workflows/release.yml`:
  - `v0.0.8`: header + policy banner; removed the two
    `(cd instdir && cmake -E tar cf ... --format=7zip .)` lines in the `package` and
    `expanded-package` Linux/macOS steps; removed the `cmake -E tar --format=7zip`
    block in the `expanded-package` Windows step; commented-out the `cpack -G 7Z`
    alternative in the `package` "Package Windows" step; removed `.7z` from the
    expected/actual inventory globs and printf lists in `validate-release` and
    `publish`; updated counts 85 → 65 and `SHA256SUMS` 87 → 67.
  - `v0.0.9` (strict): removed the Linux `(cd instdir && cmake -E tar cf
    "../release-assets/${PREFIX}.zip" --format=zip .)` lines in the `package`,
    `package-smoke`, and `expanded-package` Linux steps; removed the macOS
    `(cd instdir && tar -czf "../release-assets/${PREFIX}.tar.gz" .)` lines in the
    `package` and `expanded-package` macOS steps; removed the corresponding
    `.zip` / `.tar.gz` entries from the expected/actual inventory printf lists and
    globs in `validate-release` and `publish`; updated counts 65 → 54 and
    `SHA256SUMS` 67 → 56; header + policy banner rewritten with the strict policy.
- `.github/workflows/ci.yml`:
  - `v0.0.8`: Linux packaging smoke no longer generates or asserts `linux-gcc-x64.7z`.
  - `v0.0.9`: Linux packaging smoke no longer generates or asserts `linux-gcc-x64.zip`.
- `.github/workflows/windows-package-smoke.yml` — header; `cpack -G 7Z` block now a
  commented-out disabled alternative; `.7z` removed from the expected-artifacts list.
- `.github/workflows/windows-arm64-package-smoke.yml` — header; `cpack -G 7Z` block
  now a commented-out disabled alternative; `.7z` removed from the expected list and
  the `Get-FileHash` glob.
- `.gitlab/.gitlab-ci.yml`:
  - `v0.0.8`: removed the Windows `cpack -C Release -G 7Z` step and the `*.7z`
    copy/upload in the Windows/Linux/macOS legs (with comments documenting the policy);
    updated related format mentions in comments.
  - `v0.0.9`: Linux legs no longer run `cpack -C Release -G ZIP` or copy `*.zip`;
    the macOS leg no longer manually builds `release-assets/${CANONICAL_BASE}.tar.gz`
    (the `.zip` from CPack's ZIP generator remains); comments updated to the strict policy.

Documentation (`v0.0.8` + `v0.0.9` combined):

- `docs/PROJECT_DOCUMENTATION.md` — current-pipeline inventory count reflected for
  Option A (65 / 67) and then the strict policy (54 / 56); release-flow ascii diagram
  updated; § 6.5 archive-format policy decision record updated to the strict
  one-archive-per-platform rule; `BUGS.txt` references rewritten to the new session
  document.
- `docs/install.md` — Archive section now documents the single-archive-per-platform
  policy table (Windows `.zip`, Linux `.tar.gz`, macOS `.zip`).
- `RELEASE_ARCHIVE_POLICY_SESSION.md` — this document (replaces `BUGS.txt`).
- `BUGS.txt` — deleted (obsolete; residual follow-ups carried into § 7 below).

## 6. Validation

- YAML parse of every edited workflow plus `workflow-lint.yml`'s `actionlint` gate.
- PowerShell/bash syntax checks of the edited inline script blocks.
- Grep proof: no active (non-comment) `.7z` path remains anywhere in the pipeline
  (GitHub Actions + GitLab CI); no active Linux `.zip` or macOS `.tar.gz` generation
  path remains in the pipeline.
- Refactored inventory-validator simulation: 54 expected packages, 56 `SHA256SUMS`
  lines, 57 release assets.
- CI verification on the pull request branch (GitHub Actions) before merge.
- Post-release asset inspection of `v0.0.8` via the GitHub API: 68 assets, correct
  extensions, no `.7z`; the remaining duplicate-archive shape (Linux `.zip`,
  macOS `.tar.gz`) documented and fixed in `v0.0.9`.
- Post-release asset inspection of `v0.0.9` via the GitHub API: 57 assets, exactly
  one standalone archive per platform/toolchain, no `.7z`.

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

Follow-up items are tracked as GitHub issues after the `v0.0.9` release.

## 8. Team / evidence note

Work was executed by the autonomous engineering agent (OpenCode) in an isolated session
branch. A second-brain peer review (GitHub Copilot CLI) was requested via the controller's
peer-invitation helper but the Copilot CLI was not available in this execution environment;
this is recorded as a quality-degradation event, not a blocker. In its place the change was
subjected to the repo's own CI gates (actionlint 1.7.12, PR packaging smoke, full build
matrix), local script-syntax validation, an executed simulation of the actual
inventory/preflight logic, and an adversarial self-review of the complete diff before
publication.