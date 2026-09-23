# Standalone Release & Distribution Architecture Audit

| Field | Value |
|---|---|
| **Repository** | `Jackie-SDX/cpp-project-template` |
| **Branch** | `main` |
| **Audited commit** | `83ed0407e8e8d2adb1933b514af6faba93ae2792` ("Add forensic packaging/distribution architecture audit (OpenCode2.md)", 2026-09-23T22:28:56Z) |
| **Audit type** | Read-only forensic investigation. No source, CI, packaging, or release changes were made. |
| **Audit date** | 2026-09-23 |
| **Auditor** | OpenCode agent (issue #130, controller fork `Jackie-SDX/Nayla-SD-JACKIE-Fun-WhatsApp-Bot`) |
| **Scope** | Standalone archive format policy (Windows `.zip`, Linux `.tar.gz`, macOS `.zip`), installers (`.exe`/`.msi`, `.deb`/`.rpm`, `.dmg`), source archives, CPack packaging, the full CI/CD distribution pipeline (GitHub Actions, GitLab CI, CircleCI), checksum integrity, signing/notarization, and reproducibility. |

> This document supersedes the previous 926-byte draft (which terminated after section heading 5 with
> no content) and is written as an original, self-contained deliverable. It reads the current
> repository state directly; nothing is copied from the existing engineering documents. Evidence,
> exact file locations, and command outputs are cited inline so every claim is independently
> checkable at the same commit.

---

## 0. Executive summary

The repository ships a genuinely extensive, multi-platform packaging architecture. On 2026-09-23 it
was deliberately tightened to a **strict one-standalone-archive-per-platform** policy under issue #130
direction:

| Platform | Standalone archive | Installers (unchanged) |
|---|---|---|
| Windows | `.zip` (`.7z` retired) | `.exe` (NSIS), `.msi` (WiX) |
| Linux | `.tar.gz` (no `.zip`) | `.deb`, `.rpm` |
| macOS | `.zip` (no `.tar.gz`) | `.dmg` |

The audit confirms that the policy is **correctly implemented and enforced end-to-end**:

- Release `v0.0.9` (published 2026-09-23T15:07:25Z) carries exactly **57 assets**: 54 platform
  packages + 2 source archives + 1 global `SHA256SUMS`. **No `.7z` asset exists** and no active
  (non-commented) `.7z`, Linux `.zip`, or macOS `.tar.gz` generation path remains in GitHub Actions
  or GitLab CI.
- The GitHub Actions release pipeline for the `v0.0.9` tag completed **fully green** (package legs,
  source, inventory validation, publish). Main-head CI (build/test matrix, actionlint, docs) is also
  green.
- Strengths worth preserving: shared CPack module, canonical one-name-per-artifact scheme, an
  inventory gate that fails the release on any deviation (54 package + 2 source + 56-line SHA256SUMS),
  duplicate-filename protection in GitLab release collection, MSVC runtime-CRT consistency handling,
  deterministic compiler/wxWidgets pins, and Windows PE-header architecture assertion.

Four material gaps remain, none of which contradict the archive policy but all of which should be
tracked as open risks:

1. **No cryptographic code-signing or notarization on any platform** (no Authenticode signtool, no
   macOS codesign/hdiutil-notarization, no Linux GPG signatures/SBOM). The release is currently
   integrity-protected by checksums only, with no provenance authentication.
2. **The parallel CircleCI status surface shows red/pending on the same commits** that are green on
   GitHub Actions. Because external providers publish through commit statuses, this creates split,
   conflicting CI signal for consumers.
3. **Archive production tooling is not unified across suites** (GitHub uses `cmake -E tar`/
   `Compress-Archive`; GitLab Windows uses `Compress-Archive`; GitLab macOS uses CPack ZIP), so
   byte-identical artifacts across providers are not guaranteed.
4. **CI smoke names diverge from release naming** (`linux-gcc-x64.*` in CI smoke vs
   `…_linux-gcc-x86_64.*` in releases), a cosmetic but real documentation/automation footgun.

The archive policy itself is sound, stable, and correctly enforced; the recommended actions below are
all additive hardening, none of which should reopen the policies users have already accepted.

---

## A. Current inventory

### A.1 Release asset inventory — `v0.0.9` (live, measured via GitHub API)

Counts measured from `releases/tags/v0.0.9` (`published_at 2026-09-23T15:07:25Z`, not a prerelease):

| Class | Count | Assets |
|---|---|---|
| Windows `.zip` | 9 | `windows-msvc-x86_64`, `windows-msvc-i686`, `windows-mingw-x86_64`, `windows-mingw-i686`, `windows-llvm-x86_64`, `windows-llvm-i686`, `windows-llvm-arm64`, `windows-msvc-arm64`, `windows-clangarm64-arm64` |
| Windows `_nsis.exe` | 9 | same 9 toolchain/arch legs as above |
| Windows `_wix.msi` | 9 | same 9 toolchain/arch legs as above |
| Linux `.tar.gz` | 5 | `linux-gcc-x86_64`, `linux-gcc-i686`, `linux-gcc-arm64`, `linux-clang-x86_64`, `linux-clang-arm64` |
| Linux `.deb` | 5 | same 5 Linux legs |
| Linux `.rpm` | 5 | same 5 Linux legs |
| macOS `.zip` | 6 | `macos-apple-clang-x86_64`, `macos-clang-arm64`, `macos-gcc-x86_64`, `macos-gcc-arm64`, `macos-llvm-x86_64`, `macos-llvm-arm64` |
| macOS `.dmg` | 6 | same 6 macOS legs |
| Source archives | 2 | `cpp-project-template_0.0.9_source.zip`, `cpp-project-template_0.0.9_source.tar.gz` |
| Integrity | 1 | global `SHA256SUMS` |
| **Total** | **57** | 54 platform packages + 2 source archives + 1 checksum manifest |

Confirmed independently: **no `.7z`** in the asset list; exactly one standalone archive per
platform/toolchain. The previous release `v0.0.8` still had 68 assets (it predates the strict policy
and still carried the Linux `.zip` / macOS `.tar.gz` convenience archives and the `.7z` retirement
footprint), which is the cleanest before/after proving the policy diff.

### A.2 Packaging/install component inventory (source)

| Component | Location | Role |
|---|---|---|
| CPack configuration (shared GitLab+GitHub) | `cmake/cpack_module.cmake` | Package identity `{project}_{version}_{os}-{toolchain}-{arch}`, NSIS/WiX/DMG/DEB/RPM settings, arch normalization, WiX ARM64, canonical-name sidecar file |
| Top-level build/install rules | `CMakeLists.txt` | Version guard, MSVC CRT policy, CPack-WiX upgrade GUID, install targets |
| GitHub release pipeline | `.github/workflows/release.yml` | Full package matrix + inventory validation + publish |
| GitHub CI build/test matrix | `.github/workflows/ci.yml` | 10 configs × Debug/Release + Linux packaging smoke |
| Windows PR package smoke | `.github/workflows/windows-package-smoke.yml` | Label-gated MinGW x64 zip/exe/msi smoke |
| Windows ARM64 package smoke | `.github/workflows/windows-arm64-package-smoke.yml` | Native ARM64 MSVC zip/exe/msi smoke, PE-header `0xAA64` check |
| Experimental full matrix | `.github/workflows/experimental-platform-matrix.yml` | 21-leg staging matrix with PE/Mach-O arch verification |
| Workflow linter | `.github/workflows/workflow-lint.yml` | `actionlint:1.7.12` on every workflow file |
| Docs publishing | `.github/workflows/doxygen-gh-pages.yml` | Pinned CMake/Doxygen/Graphviz → Doxygen → `gh-pages` |
| Windows cache warmup | `.github/workflows/vcpkg-cache-warmup.yml` | Pre-builds Windows vcpkg binary caches used by release |
| Cache wipe helper | `.github/workflows/clear_cache.yml` | Manual-only Actions-cache reset |
| Manual Windows Debug CI | `.github/workflows/windows-test.yml` | GitLab-style `x64-windows-debug` triplet build/test |
| `/oc` responder | `.github/workflows/opencode.yml` | OpenCode on issue comments (`anomalyco/opencode/github@latest`) |
| GitLab pipeline | `.gitlab/.gitlab-ci.yml` | Build → package → release (tag-gated), build attestation, canonical naming |
| GitLab vcpkg triplets | `.gitlab/vcpkg-triplets/` | `x64/x86-windows-debug/release`, `x64/x86-win-llvm`, MSVC/Clang-CL overrides |
| CircleCI mirror | `.circleci/config.yml` | Pre-flight mirror of the GitLab job set for hosted runners |
| CMake driver scripts | `.github/scripts/configure.cmake`, `build.cmake`, `test.cmake` | `cmake -P` wrappers used by all CI containers |
| Package resources | `packaging/windows/{nsis,wix}` (icons/banners), `packaging/apple` (icns/icon), `packaging/linux` (desktop/icon) | Installer branding and desktop integration |
| Dependency manifest | `vcpkg.json` | `wxwidgets`, `gtest`, `builtin-baseline a1cae005…` |

### A.3 Current format mapping (policy → implementation)

| Policy target | GitHub Actions | GitLab CI | Status |
|---|---|---|---|
| Windows standalone archive `.zip` | `Compress-Archive …\${PREFIX}.zip` (`release.yml` "Package Windows"); `.7z` present only as a commented-out disabled block | `.package_windows_outputs` → `Compress-Archive "$canonicalBase.zip"`; 7Z step removed | ✅ enforced |
| Windows installers `.exe`/`.msi` | `cpack -G NSIS64/NSIS` + `cpack -G WIX` | `cpack -G $env:NSIS_GENERATOR` + best-effort `cpack -G WIX` | ✅ preserved |
| Linux standalone archive `.tar.gz` | `tar -czf` of `instdir` | `tar -C instdir -czf …` | ✅ enforced |
| Linux installers `.deb`/`.rpm` | `cpack -G DEB` + `cpack -G RPM` | `cpack -G DEB`/`-G RPM` (non-fatal on failure) | ✅ preserved |
| macOS standalone archive `.zip` | `cmake -E tar cf … --format=zip` | `cpack -C Release -G ZIP` | ✅ enforced |
| macOS installer `.dmg` | `cpack -G DragNDrop` (with busy-detach retry loop) | `cpack -C Release -G DragNDrop` (non-fatal) | ✅ preserved |
| Source archives `.zip` + `.tar.gz` | `git archive` in `source` job | `git archive` in `create_release` | ✅ preserved |

---

## B. Architecture assessment

Each item is classified **KEEP / HARDEN / FIX / ADD / CONSIDER** with the evidence that supports it.

### B.1 Windows `.zip` (standalone archive) — KEEP / HARDEN

- **KEEP.** `.zip` is the correct, lowest-friction standalone archive for Windows consumers.
  Implemented via PowerShell `Compress-Archive` off the installed (stripped) tree
  (`release.yml` "Package Windows"; likewise in the smoke workflows). It round-trips without the
  extra runtime tooling that `.7z` would require, and the strict policy that superseded `.7z` builds
  on the fact that users "just want it to work".
- **HARDEN (reproducibility).** `Compress-Archive` embeds timestamps; there is no normalized
  timestamp/mode/owner normalization like the Linux `tar -czf` affords via `--mtime`. For byte-level
  reproducibility *across* providers this matters (see B.6).
- Evidence: `release.yml` lines ~492–510 ("Package Windows"), 1302–1323; `windows-package-smoke.yml`
  lines 133–155; `windows-arm64-package-smoke.yml` lines 174–191. No active `.7z` path: the only
  mentions are comments/disabled blocks (verified by grep).
- **Not advised:** re-adding `.7z`. The disabled block that documents how to restore it is exactly
  the right archaeological artifact: present, commented, reviewable, never shipped.

### B.2 Windows NSIS `.exe` — KEEP

- The primary Windows installer. Both GitHub and GitLab generate it with CPack NSIS64/NSIS, install
  NSIS via Chocolatey, and treat NSIS as **strict** (a failure aborts the Windows leg), which is the
  correct severity ordering: NSIS is the artifact users actually run.
- `cmake/cpack_module.cmake` configures DPI awareness (`CPACK_NSIS_MANIFEST_DPI_AWARE`),
  uninstall-before-install, PATH modification, menu links, MUI icons/banners, and a runtime FFI-safe
  `CPACK_NSIS_DEFINES` (empty) to avoid emitting malformed `VIAddVersionKey` (documented in-file).
  WiX/ARM64 note: only the `arm64` MSVC leg changes the generator (`CPACK_WIX_ARCHITECTURE arm64`).
- Evidence: `cmake/cpack_module.cmake` lines 82–128; `release.yml` "Package Windows".

### B.3 Windows WiX `.msi` — KEEP / HARDEN

- **KEEP.** `.msi` is the managed-enterprise installer and correctly preserved. Both pipelines treat
  it as **best-effort on GitLab** (`$global:WixAvailable` gate verifies `candle.exe` reachable via
  PATH *or* the `WIX` env var before even attempting generation), while GitHub's release workflow
  requires it (`Test-Path "package\$env:BASE.msi"` throws). The asymmetry is defensible: GitHub is
  the publishing source of truth and has WiX installed deterministically; GitLab is a parity/backup
  lane.
- **KEEP.** `CPACK_WIX_UPGRADE_GUID` is pinned in `CMakeLists.txt` (`02FBAAA4-…`), giving stable
  per-machine upgrade identity.
- Evidence: `CMakeLists.txt` line 113; `release.yml` lines 507–509 (WIX), 1320–1322; GitLab
  `.windows_package_prep` (WiX v3 via Chocolatey, registry/PATH `WIX` fallback, correction notes on
  WiX v3 vs v4); `.gitlab-ci.yml` `package_windows_arm64_release` documents the known-weaker WiX v3
  ARM64 path.

### B.4 Linux `.tar.gz` (standalone archive) — KEEP / HARDEN

- **KEEP.** `.tar.gz` is the correct default standalone archive for Linux (via strips, preserves
  permissions, splittable, universally available). Implemented by `tar -C instdir -czf` in both
  pipelines and in the CI smoke.
- **HARDEN (reproducibility).** The pipeline does not pass a normalized timestamp (`--mtime=@…`),
  sorted input (`--sort=name`), or `--owner/--group=0`. For byte-identical rebuilds across CI runs
  and providers these flags are inexpensive and safe.
- Evidence: `release.yml` lines 518, 1331; `ci.yml` lines 323–342; GitLab
  `package_linux_x64_release` / `package_linux_arm64_release`.

### B.5 Linux `.deb` / `.rpm` — KEEP

- Both preserved unchanged, as directed. Dependencies are explicit and well-scoped:
  `CPACK_DEBIAN_PACKAGE_DEPENDS "libc6 (>= 2.32), libstdc++6 (>= 12)"` plus a wxGTK alternation when
  the GUI is built, and the RPM equivalents (`glibc >= 2.32, libstdc++ >= 12`, `MIT` license, URL).
  Ubuntu smoke asserts the artifacts exist and are non-empty; GitHub release validates `.deb`/`.rpm`
  presence per Linux leg.
- Evidence: `cmake/cpack_module.cmake` lines 141–159; `ci.yml` lines 321–342; `release.yml`
  "Package Linux".
- **Risk note (not blocking):** GitLab's Linux package jobs use `|| echo "… failed"` — a `.deb`/`.rpm`
  failure on GitLab logs but does not fail the job. GitHub treats them as required. Keep this exact
  asymmetry and do not weaken the GitHub side.

### B.6 macOS `.zip` and `.dmg` — KEEP / HARDEN

- **KEEP.** `.zip` for macOS (Safari/Archive Utility friendly) and `.dmg` for the flexible
  drag-and-drop installer are both correct and both preserved. DMG builds even handle CPack's
  transient mount-busy detach with a force-detach retry loop (`hdiutil detach … -force` ×3).
- **HARDEN (Gatekeeper).** Nothing signs the `.app` inside the DMG/zip, and nothing notarizes the
  DMG. Un-notarized unsigned builds are quarantined/slow-path on modern macOS. This is the single
  most impactful macOS hardening item (see F.1).
- **CONSIDER (universality).** The matrix builds `macos-llvm-*` via Homebrew LLVM and `macos-gcc-*`
  via Homebrew GCC; these extra toolchains broaden the matrix but are also the legs most likely to
  be affected by Homebrew bumps. They are gated/staged appropriately (expanded matrix), so value vs
  cost is acceptable.
- Evidence: `release.yml` "Package macOS" (1352–1378), expanded legs; `.gitlab-ci.yml`
  `package_macos_release`; `cmake/cpack_module.cmake` lines 134–139.

### B.7 CPack module (`cmake/cpack_module.cmake`) — KEEP / HARDEN

- **KEEP.** Single shared module is the right centralization. It produces a **globally unique,
  human-meaningful package name** `{project}_{version}_{os}-{toolchain}-{arch}`, normalizes arch
  (`x86_64`/`i686`/`arm64`, including the 32-bit-pointer correction under vcvars32), and handles the
  WiX-ARM64 special case. This uniqueness is what makes the GitLab duplicate-filename guard and the
  GitHub inventory gate possible — without it, artifacts silently collide.
- **KEEP.** The `canonical_package_name.txt` sidecar (`file(WRITE …)`) is the correct escape from
  reverse-parsing CMake's generated `CPackConfig.cmake`. Both pipelines now read it directly — a
  genuinely solid fix that eludes fragile regex parsing (documented in GitLab with the exact failure).

### B.8 GitHub release pipeline (`release.yml`) — KEEP / HARDEN

- **KEEP the gate chain.** `cache-gate → package/source/expanded-package → validate-release →
  publish` is exactly right:
  - The release *only* publishes on `v*` tag pushes, `publish` requires `validate-release`.
  - `validate-release` downloads everything and **asserts the exact expected 54-name inventory**
    (`wc -l expected.sorted -eq 54`), asserts actual = expected (`cmp`), rejects empty artifacts,
    deletes temp manifests before they can leak (fixing the `v0.0.2/v0.0.3` stray-asset bug), then
    writes the global `SHA256SUMS` and verifies it (`sha256sum -c`).
  - `publish` repeats the inventory check (54), asserts `SHA256SUMS` has **56 lines** (54 packages +
    2 source), and uses `softprops/action-gh-release` with `fail_on_unmatched_files: true` and
    `overwrite_files: true`.
- **KEEP. PR-time packaging coverage** is layered and sensible: label-gated `windows-package-smoke`
  and the ARM64 smoke, and a cheap Linux GCC smoke on every PR, with the full matrix opt-in via the
  `full-release-test` label.
- **HARDEN (budget/policy).** The matrix is huge (multi-hundred-step) and runs on public runners;
  cache reliance is high. `cache-gate` on the upstream repo enforces a pre-seeded release-cache
  contract. Document the cost expectation and keep the warmup cadence.
- Evidence: `release.yml` lines 1–58 (header/policy), 84–188 (cache-gate), 576–650 (smoke),
  654–791 (source + validate-release), 796–897 (publish), 901–1385 (expanded-package).

### B.9 CI (`ci.yml`) and packaging smoke — KEEP / FIX

- **KEEP.** 10 toolchain/arch configs × Debug/Release, `fail-fast: false`, ccache + vcpkg cache
  layering with per-compiler fingerprints, MSVC environment discovery via vswhere, MSYS2 MinGW,
  coverage on Linux Debug (Codecov + Coveralls), and a Linux Release packaging smoke.
- **FIX (naming).** The CI smoke emits `linux-gcc-x64.tar.gz/.deb/.rpm` while release artifacts use
  the canonical `…_linux-gcc-x86_64.*` (arch `x86_64`, platform+toolchain prefix). The same
  convention drift existed in GitLab historically and was flagged as a Q&A item in the docs. Aligning
  the smoke names to the canonical scheme (or explicitly naming them as non-release smoke artifacts)
  removes a recurring confusion source.
- Evidence: `ci.yml` lines 23, 321–342; `release.yml` "Resolve release version and naming".

### B.10 GitLab CI (`/release`) — KEEP / HARDEN

- **KEEP.** ADR-005 separation, tag-gated `package`/`release` stages, the
  `.release_package` tag rule, and the extensive failure-mode hardening (allow_failure semantics,
  attestation checks, dependency/`needs` behavior fixes) show unusually thorough production thinking.
- **KEEP the provenance gate.** Build jobs write `build/.build_attestation.json`
  (`{commit, pipeline, job}`) and package jobs refuse to package unless it exists *and* its commit
  matches the current pipeline — this prevents a cancelled/failed upstream build from being packaged
  from a stale `build/` tree.
- **HARDEN (signing/provenance).** GitLab supports release asset signatures and SBOM; neither is
  emitted today. Adding a per-asset `.sig`/SBOM from the CI job token would close the trust gap
  without touching artifact formats.

### B.11 CircleCI mirror — FIX (left of the release path)

- `.circleci/config.yml` is a well-written mirror (with excellent fix notes about the
  no-output-timeout, matrix-templating, and filter-regex classes of bugs). But on the *same commits*
  where GitHub Actions is green, the CircleCI status surface reports **failure/pending** on most
  Linux/Windows contexts (`ci/circleci: build-linux-gcc-*`, `build-linux-clang-*`, `clang-tidy`,
  `build-windows-*`) and success only on arm64/macOS — verified via the commit status API on both the
  `v0.0.9` tag and current `main` head.
- Because external providers publish through **commit statuses** (a CI surface independent of
  Actions check runs), consumers see genuinely conflicting red/green signal. **Recommendation:** either
  restore the mirror to green (its stated purpose is pre-flight validation before spending GitLab
  compute) or document it as best-effort and have it stop reporting on `v*` tags. Do not let a
  dead lane masquerade as a failing gate.
- Evidence: `.circleci/config.yml` lines 1–440; commit status API output for `83ed040…` and `v0.0.9`.

### B.12 Versioning and configuration — KEEP

- Single-source version resolution (tag `vX.Y.Z` → `X.Y.Z` passed as
  `CPP_PROJECT_TEMPLATE_VERSION`; local builds default to the distinctive `0.0.1.0` placeholder) is
  sound and consistently consumed by every version stamp (`version.rc.in`, desktop template,
  `config.h.in`, doxygen/sphinx, cpack). Keep.
- vcpkg is pinned (`builtin-baseline a1cae005…`) with overlay triplets pinned to a commit; wxWidgets
  and gtest are the only deps. Good supply-chain practice.
- Action versions are pinned to commit SHAs across workflows (ADR 003) — keep.

### B.13 Documentation — KEEP

- `docs/PROJECT_DOCUMENTATION.md` (sections 6.5 policy, 7 decisions, 13 session record) and
  `docs/install.md` archive section state the policy clearly and correctly, including the
  `windows-package-smoke`/ARM64 commented `.7z` blocks and the grep proof that no active `.7z` path
  remains. Installer instructions (NSIS, WiX, DEB, RPM, DMG/productbuild) are readable. Keep.

---

## C. Current-vs-target matrix

The required targets from the issue (one standalone archive per platform, installers unchanged) are
already met by `v0.0.9`:

| Platform / consumer | Target (issue #130 policy) | Actual (v0.0.9) | Delta |
|---|---|---|---|
| Windows standalone | `.zip` | `.zip` ×9 | ✅ |
| Windows installers | `.exe`, `.msi` (unchanged) | `.exe` ×9, `.msi` ×9 | ✅ |
| Linux standalone | `.tar.gz` | `.tar.gz` ×5 | ✅ |
| Linux installers | `.deb`, `.rpm` (unchanged) | `.deb` ×5, `.rpm` ×5 | ✅ |
| macOS standalone | `.zip` | `.zip` ×6 | ✅ |
| macOS installer | `.dmg` (unchanged) | `.dmg` ×6 | ✅ |
| Source archives | unchanged | `.zip` + `.tar.gz` | ✅ |
| `.7z` anywhere | absent | absent (commented-only in source) | ✅ |
| Convenience dupes (Linux `.zip`, macOS `.tar.gz`) | absent | absent | ✅ |
| Integrity | checksums | global `SHA256SUMS` (56 lines) | ✅ |
| Provenance/trust | — (new) | attestation JSON (GitLab) only; no signatures/SBOM | ⚠ additive gap |
| Signing/notarization | — (new) | none on any platform | ⚠ additive gap |
| CI signal consistency | all surfaces green | Actions green; CircleCI statuses red/pending on same commit | ❌ fix |

---

## D. Proposed improvements

Read-only recommendation list. Ordered by impact; each is additive and none reopens the archive
policy.

1. **[ADD, highest value] Release signing and provenance.**
   - Linux: sign `.tar.gz`/`.deb`/`.rpm` and the `SHA256SUMS` with a GPG release key
     (`gpg --detach-sign --armor`) and publish `SHA256SUMS.sig` + `.asc` per package. Optionally
     attach a CycloneDX/Syft SBOM per release.
   - Windows: Authenticode-sign the NSIS `.exe` (and WiX `.msi`) with an EV cert via a signing
     service or `AzureSignTool`/`signtool` step in `release.yml` (tag-only).
   - macOS: `codesign` the `.app` (Developer ID) and `notarytool submit`/`stapler` the `.dmg`.
     Accept build/attestation as the interim trust model.
   - GitLab: use the release-cli signature support and/or CI-job-token generation of signatures+SBOM
     to mirror GitHub evidence.
2. **[HARDEN] Deterministic artifact timestamps.** Add `--sort=name --mtime=@VERSION_EPOCH
   --owner=0 --group=0 --numeric-owner` to Linux `tar`; consider a reproducible ZIP creation path
   (e.g., `cmake -E tar --format=zip` with normalized mtimes) shared by GitHub *and* GitLab so the
   two lanes can produce byte-identical archives.
3. **[FIX] Unify archive production tooling per platform across providers** so GitHub and GitLab use
   the same generator (e.g., standardize on `cmake -E tar … --format=zip` for macOS and Windows
   zip, and the identical `tar` for Linux). Document that cross-provider byte-identity is not
   guaranteed until this lands.
4. **[FIX] Align CI smoke artifact names** with the canonical release naming
   (`linux-gcc-x86_64.*` etc.) or explicitly label them `smoke-*`. Eliminates name drift between
   smoke and release and prevents automation from treating smoke artifacts as release-shaped.
5. **[FIX] Restore or disable the CircleCI status lane.** Either bring the mirror back to green for
   the Linux/Windows contexts (its purpose is pre-flight before GitLab compute) or gate it off
   `v*` tags so consumers are not shown contradictory CI signal.
6. **[ADD] Automated release-gate regression test.** Add a step-level check (e.g., in
   `validate-release`) that fails if any committed workflow/enum diverges from the 54-name expected
   inventory — a tiny script that regenerates `expected.txt` from the workflow's own loops and diffs,
   so policy drifts are caught in CI, not by a human.
7. **[CONSIDER] SBOM + dependency pin review.** vcpkg baseline is pinned; periodically diff
   `vcpkg.json` outcomes and record resolved versions in the release notes for auditability.
8. **[CONSIDER] macOS app-bundle metadata.** Ensure `Info.plist` (`CFBundleIdentifier`,
   `LSMinimumSystemVersion`) is generated consistently for every macOS leg (part of hardening B.6).

---

## E. Changes deliberately NOT advised

These are intentionally excluded, even though they appear "modern" or tempting:

- **Do NOT re-add `.7z`.** The strict policy explicitly forbids it; the commented block exists only
  to document the historical option.
- **Do NOT remove or redesign `.exe`/`.msi`/`.deb`/`.rpm`/`.dmg`.** Explicit issue constraint; they
  are kept and only hardened.
- **Do NOT revert to multiple standalone archives per platform (Linux `.zip`, macOS `.tar.gz`),
  even as "convenience".** That was the exact two-archive state the owner explicitly rejected.
- **Do NOT publish the CHANGELOG/manifest/inventory temp files into the release.** Guarded already;
  keep the protection.
- **Do NOT make every PR run the full release matrix.** Keep it label-gated; the cost is enormous
  and the smokes already cover packaging regressions.
- **Do NOT merge GitLab's best-effort semantics back into GitHub's strict release job** — GitHub is
  the authoritative publishing lane; keeping it strict is what guarantees the 54-asset contract.
- **Do NOT hard-fail GitLab releases on optional `.msi`/`.dmg` failures** — that is the whole point
  of the `|| echo` + allowed-failure pattern; tightening it would reintroduce single-platform outages
  blocking the whole release.
- **Do NOT switch the NSIS/WiX toolchain versions casually.** WiX v4 (dotnet tool) and CMake WiX-4
  mode would change both pipelines and the ARM64 story; the current v3 + `candle.exe` path is
  verified and stable.

---

## F. Open risks

| ID | Risk | Severity | Mitigation status |
|---|---|---|---|
| F.1 | Unsigned, unnotarized macOS output (Gatekeeper/quarantine friction; no release-authenticity) | High | Not mitigated — requires Apple Developer ID + notarization credentials |
| F.2 | Unsigned Windows `.exe`/`.msi` (SmartScreen warnings; tamper-undetectable) | High | Not mitigated — requires EV/OV cert signing pipeline |
| F.3 | No Linux signature/SBOM (checksum-only integrity) | Medium | Not mitigated — GPG key + signing job needed (see D.1) |
| F.4 | Contradictory CI signal: CircleCI statuses red/pending on the green Actions commit | Medium | Needs lane repair or suppression on `v*` (D.5) |
| F.5 | Cross-provider archive byte-identity not guaranteed (different zip/tar producers) | Low | Documented; mitigated only by D.3 |
| F.6 | GitLab `.deb`/`.rpm` failures silently tolerated on the parity lane | Low | Accepted design (GitHub lane is strict); documented |
| F.7 | Homebrew-managed macOS toolchains (LLVM/GCC legs) can bump between releases without a pin | Low | ccache + pins partially contain; consider brew lockfile review |
| F.8 | Release depends on Actions cache availability (large matrix, cold-start cost) | Low | `cache-gate` + weekly warmup mitigate; document cost expectation |
| F.9 | WiX v3 ARM64 MSI known-weaker path | Low | Documented in GitLab `package_windows_arm64_release`; best-effort there |
| F.10 | Local version placeholder `0.0.1.0` could leak into a mistakenly-tagged build | Low | Version resolved from tag only in tag pipelines; single-source anchor |

---

## G. Validation evidence

### G.1 Policy implementation proof (static)

- **No active `.7z` path.** Source-level grep of `.github/workflows/*.yml`,
  `.gitlab/.gitlab-ci.yml`, `.circleci/config.yml`, `cmake/`, `CMakeLists.txt`: every `.7z`/
  `-G 7Z` occurrence is a comment or a commented-out disabled block. Remaining harness-level
  references (`docs/install.md` MinGW download links) are third-party dev-time downloads, not
  release artifacts.
- **No active Linux `.zip` or macOS `.tar.gz` generation.** `release.yml` produces `.tar.gz` only
  for Linux and `.zip` only for Windows/macOS; GitLab matches (`package_linux_*` tar.gz-only,
  `package_macos_release` ZIP+DMG).
- **Expected inventory is asserted as a hard gate.** `validate-release` builds `expected.txt`
  (54 names), asserts `wc -l -eq 54` for both expected and actual, and `cmp`-compares them;
  `publish` repeats it and asserts `SHA256SUMS` has 56 lines. A single wrong/missing/extra artifact
  aborts publishing.

### G.2 Release-level validation (live, GitHub API)

- **`v0.0.9` asset list (2026-09-23T15:07:25Z):** 57 assets; 9 `.zip` + 9 `.exe` + 9 `.msi`
  (Windows), 5 `.tar.gz` + 5 `.deb` + 5 `.rpm` (Linux), 6 `.zip` + 6 `.dmg` (macOS), 2 source
  archives, 1 global `SHA256SUMS`. **No `.7z`.**
- **`v0.0.8` comparison:** 68 assets (pre-strict policy: Linux `.zip` + macOS `.tar.gz`
  convenience archives and the `.7z` retirement footprint still present). 88→68→**57** asset and
  85→65→**54** package trajectory is exactly the documented policy math.
- **Tag check-runs:** all Actions check runs on `v0.0.9` are `success`/`completed` for
  `Publish release`, `Validate release inventory`, every `package`/`expanded-package` leg, `Source
  archives`, and the Windows cache-gate legs (PR smoke correctly `skipped`).
- **Main-head CI (`83ed040…`):** `CI` (all 10 configs × {Debug,Release} incl. ARM64 runners),
  `Workflow Lint` (actionlint), and `GH Doxygen` are green (`run id 35928581190/…` completed
  successfully).

### G.3 Cross-surface verification (commit statuses)

- On **both** `v0.0.9` and `main@{83ed040}`, the Actions check surface is green **while** the
  commit-status surface (`ci/circleci:*`) is entirely failure/pending except runner-successful arm64
  and macOS contexts. This is the F.4 risk in raw form: two CI surfaces disagree on the same SHA.

### G.4 Checksum integrity (repo-asserted, and spot-verified)

- Global `SHA256SUMS` (56 lines) is written and self-checked inside `validate-release` and
  `publish` before the release is created; `softprops/action-gh-release` upload fails on unmatched
  files. Spot-check of the live `SHA256SUMS` asset confirms 56 checksum lines covering every
  package + source archive.

### G.5 What was NOT found (absence evidence)

- No `signtool`/`AzureSignTool`, no `codesign`/`notarytool`/`stapler`, no `gpg --detach-sign`, no
  SBOM generation anywhere in GitHub Actions, GitLab CI, or CircleCI. Confirms the F.1–F.3 signing
  gap is real, not merely undocumented.
- No workflow publishes any inventory/manifest temp file (`expected.txt`, `actual.txt`) — a
  regression against the historical `v0.0.2/v0.0.3` bug is guarded and present.

---

## Appendix — exact evidence anchors (commit `83ed040`)

- Archive policy declaration + inventory math: `release.yml` header (lines 25–37); docs § 6.5.
- Commented `.7z` disabled blocks: `release.yml` ~500–506, ~1315–1322;
  `windows-package-smoke.yml` 146–152; `windows-arm64-package-smoke.yml` 182–188.
- Canonical naming + arch normalization + WiX ARM64: `cmake/cpack_module.cmake` 59–71, 47–49.
- Missed smoke/release name drift: `ci.yml` 323–342 vs `release.yml` "Resolve release version and
  naming".
- Inventory gate: `release.yml` `validate-release` (~714–791) and `publish` (~816–897).
- GitLab provenance gate: `.gitlab-ci.yml` `.write_attestation_bash`/`.check_attestation_bash`/
  `.check_attestation_pwsh` (~374–420).
- CircleCI status split: commit status API for `83ed040…` and `v0.0.9`.
- Live release assets: GitHub API `releases/tags/{v0.0.8,v0.0.9}`.

*End of audit. No files were modified; this document supersedes the truncated prior draft of
OpenCode2.md at the same repository root.*