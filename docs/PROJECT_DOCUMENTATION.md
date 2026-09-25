# C++ Project Template — Engineering Documentation

**Project:** `cpp-project-template`
**Scope of this document:** the single, consolidated engineering record for this repository. It
covers the repository's origins (`MangaD/cpp-project-template`), its intermediate fork
(`NaylaCruz/cpp-project-template`), and the current fork (`Jackie-SDX/cpp-project-template`) —
everything that was built, every decision taken, the alternatives considered, the GitHub + GitLab
merge notes, the standalone release archive policy and its session record, the 2026-09-23 compiler
& architecture Q&A, and the work still worth doing. Content that previously lived in separate
record files (`MERGE_NOTES.md`, `RELEASE_ARCHIVE_POLICY_SESSION.md`, and the proposed
`docs/COMPILER_ABI_NOTES.md`) is consolidated here as a single document (see Sections 11-13).

**Point in time:** snapshot taken against `Jackie-SDX/cpp-project-template` at
`main` = `96240c0` (2026-09-21), extended through the archive-policy releases `v0.0.8`/`v0.0.9`
(2026-09-23, PRs #8/#9); `MangaD/cpp-project-template` at `71cae18` (2026-08-23);
`NaylaCruz/cpp-project-template` at `522bc3a` (2026-09-18).

---

## 1. Executive Summary

`cpp-project-template` started in June 2023 as *MangaD*'s pedagogical C++20 template: CMake +
CTest + CPack, a static library, a console app, a wxWidgets GUI app, GoogleTest, Doxygen/Sphinx
documentation, a single GitHub Actions build matrix, a compact GitLab pipeline, and DEB/RPM/NSIS/WiX
installer packaging against a `v0.0.1` release.

Two forks later the project is a substantially larger engineering asset. `NaylaCruz`'s fork added a
large, hardened, multi-toolchain release pipeline (GitLab + GitHub parity, vcpkg triplets, LLVM/Clang-CL
and ARM64 Windows support, ADRs, SHA-pinned actions, deterministic caches, a dual vcpkg/Conan-2 package
manager, opt-in CDash, and an experimental Android/NDK arm). `Jackie-SDX`'s fork absorbed that work
(merge commit `7e610ee`), added the OpenCode automation entrypoint (commit `6b1bd2e`), and then — under
two reviewed pull requests — **removed Android/NDK from the pipeline** ([PR #5](https://github.com/Jackie-SDX/cpp-project-template/pull/5))
and **fixed a release-asset hygiene bug** in which temporary inventory manifests leaked into releases
([PR #6](https://github.com/Jackie-SDX/cpp-project-template/pull/6)).

Every claim below was verified against the actual git history, the GitHub API, the live workflows, and the
released assets of all three repositories. Section 14 carries the verification ledger.

**At a glance:**

| Repository | Created | Commits | Files | GH workflows | GitLab CI size | Releases |
|---|---|---|---|---|---|---|
| `MangaD/cpp-project-template` (original) | 2023-06-02 | 72 | 82 | 4 | 129 lines | `v0.0.1` (20 assets) |
| `NaylaCruz/cpp-project-template` (intermediate) | 2026-08-29 | 335 | ~118 | ~12 | ~2 600 lines | `v0.0.4` … `v7.7.9` (up to 100 assets) |
| `Jackie-SDX/cpp-project-template` (current) | 2026-08-22 | 339 | 122 | 11 | 2 606 lines | `v0.0.2` (96), `v0.0.3`/`v0.0.4`/`v0.0.5` (88), `v0.0.8` (68), `v0.0.9` (57) |

---

## 2. Repository Lineage and Fork Graph

The ancestry (verified via GitHub API `parent` fields and git merge-base):

```
MangaD/cpp-project-template            (original template, authored 2023-06-02…2026-08-23)
   └─► Jackie-SDX/cpp-project-template (fork, created 2026-08-22; base = MangaD main ~86a1213)
          └─► NaylaCruz/cpp-project-template  (fork of Jackie-SDX, created 2026-08-29)
                  (264 commits of pipeline hardening on top of MangaD's history)
          ◄── NaylaCruz/main merged back into Jackie-SDX/main via PR #1 (merge 7e610ee, 2026-09-18)
          ├── 6b1bd2e  (2026-09-19) add opencode GitHub workflow
          ├── e79bddc  (2026-09-21) [PR #5] remove Android/NDK; document all 11 workflows
          └── 96240c0  (2026-09-21) [PR #6] fix stray release assets (expected.txt/actual.txt leak)
```

Key dates and events:

| Date | Repo | Event |
|---|---|---|
| 2023-06-02 | MangaD | `first commit` — start of the template |
| 2023-07-12 | MangaD | Release `v0.0.1` (20 assets, version string `1.0.0.0`) |
| 2023-08-27 | MangaD | Doxygen TOC work; codebase stabilizes |
| 2025-02…2026-08 | MangaD | Drift updates (wxGTK 3.2, CMake/Doxygen/Graphviz pins, GH Pages, coverage) |
| 2026-08-22 | Jackie-SDX | Fork of MangaD created |
| 2026-08-29 | NaylaCruz | Fork of Jackie-SDX created; begins a large CI/CD hardening pass |
| 2026-08-29…09-18 | NaylaCruz | 264 commits + releases `v0.0.4`…`v7.7.9` |
| 2026-09-18 | Jackie-SDX | Merges `NaylaCruz/main` via PR #1 (`7e610ee`) |
| 2026-09-19 | Jackie-SDX | Adds `opencode.yml` comment-triggered automation (`6b1bd2e`) |
| 2026-09-21 | Jackie-SDX | PR #5 Android removal + workflow docs → `e79bddc` → release `v0.0.3` |
| 2026-09-21 | Jackie-SDX | PR #6 release-asset hygiene → `96240c0` → release `v0.0.4` |

> Why the fork graph looks this way: GitHub records NaylaCruz as a fork of *Jackie-SDX*, but NaylaCruz
> carried the full MangaD history under it (its earliest commits are MangaD's). The Jackie-SDX main branch
> then pulled the entire NaylaCruz line back in through a single merge (`7e610ee`, parents `86a1213` +
> `522bc3a`). In practice the effective lineage for the current fork is
> **MangaD → NaylaCruz → back into Jackie-SDX**.

---

## 3. The Original Repo: `MangaD/cpp-project-template`

### 3.1 Purpose

A "production-ready template" for modern cross-platform C++ projects: CMake, CI/CD, unit tests,
coverage, static/dynamic analysis, auto-formatting, package management, documentation, GUI, installers.
It intentionally uses a *wxWidgets* GUI and a GoogleTest-backed static library both to be immediately
useful and to serve as pedagogical examples.

### 3.2 What it contained (82 files)

```
.devcontainer/                       dev container (Ubuntu + C++ toolchain, VS Code extensions)
.github/workflows/                   build-debug.yml, build-release.yml, clear_cache.yml, doxygen-gh-pages.yml
.github/scripts/                     build.cmake, configure.cmake, test.cmake
.gitlab/.gitlab-ci.yml (129 lines)   compact GitLab pipeline + docker_scripts/
CMakeLists.txt                       single build file for lib + CLI + wxGUI
CMakePresets.json                    tidy + cppcheck presets only
CTestConfig.cmake                    CDash submit → my.cdash.org project "cpp-project-template"
CITATION.cff / LICENSE (MIT) / CODEOWNERS / TODO.md / FUNDING.yml
cmake/                               CodeCoverage, FindSphinx, clang-format, cpack_module, doxygen,
                                     memcheck, sphinx modules
docs/                                getting_started, install, development_guide, doxygen/, sphinx/
packaging/                           apple (icns), linux (desktop template), windows (icon/rc, NSIS, WiX)
src/                                 projectcli (console main), projectlib (library + gtest),
                                     projectwx (wxWidgets App/MainFrame/splashscreen/utils)
clang-format / clang-tidy / cppcheck / sanitizer / valgrind configs
.github submodules, .gitmodules      doxygen-awesome-css
```

### 3.3 Engineering characteristics of the original

- **Build:** CMake ≥ 3.21, C++20, out-of-source builds enforced, in-source builds rejected.
- **Test:** GoogleTest for the library; CTest wrapper tests for the CLI (`-h`, `-v`, invalid arg).
- **Quality gates in CI:** `ccache`, `clang-tidy`, `clang-format`, `cppcheck`, `valgrind` memcheck,
  Coverity Scan, Codecov, Coveralls, CDash (submission to the *upstream author's* dashboard).
- **Packaging:** CPack → DEB/RPM (Linux), NSIS `.exe` + WiX `.msi` (Windows), DMG (macOS),
  and a strict one-archive-per-platform policy (Windows/Linux/macOS → `.zip`/`.tar.gz`/`.zip`;
  upstream's `.7z` variant and the Linux `.zip`/macOS `.tar.gz` convenience archives retired 2026-09 — § 6.5).
- **CI:** GitHub Actions `build-debug` (`BUILD_TYPE=Coverage`) and `build-release`
  (`BUILD_TYPE=Release`) matrix (3 OS × {MSVC, MinGW, GCC, Clang, LLVM}), a manual cache-clear
  workflow, and a Doxygen pages workflow. GitLab CI mirrored the GitHub copy via docker images.
- **Release:** single tag `v0.0.1`, 20 assets (Linux DEB/RPM/7z/tar.gz, macOS DMG/7z, Windows
  MSVC/MinGW/LLVM zip/7z/NSIS/WiX), checksummed as part of the workflow.
- **Docs:** Doxygen (with doxygen-awesome-css + GitHub corner), Sphinx, a development guide, an
  install guide, and a "getting started" guide, plus a progress-status dashboard in the README.

### 3.4 Known limitations of the original

- The two build workflows duplicated the matrix; installers were built on **every** PR (expensive).
- CDash/Codecov/Coveralls all pointed at **MangaD's** projects/dashboards (ineluctable for a fork).
- Windows triplets were a small hand-written set (`x86/x64-windows` and `-static`); no LLVM/Clang-CL
  cross-compile, no ARM64, no Conan path.
- Timestamp-based cache keys → ~100% cache miss on every run.
- Third-party actions pinned to mutable tags (`@main`, `@v4`) — a supply-chain risk.
- native Windows ARM64 support and a working MinGW/LLVM story were absent/experimental.
- The README's progress-status table flags several "todo" items that are still unimplemented
  (Qt, Boost, Catch2, i18n, code signing, productbuild, Jenkins, gdb/gprof…).

---

## 4. The Intermediate Fork: `NaylaCruz/cpp-project-template`

Created 2026-08-29 as a fork of Jackie-SDX (which was itself a fork of MangaD). Between 2026-08-29 and
2026-09-18 (`86a1213..522bc3a`) it added **264 commits** — the bulk of the engineering that defines the
current pipeline. Commit message histogram over that range:

```
102 fix:     51 ci:     34 experimental:     13 build:     10 perf:      8 chore:
  6 feat:     6 release:  13 "Add files via upload"  4 merge   2 test:  2 docs:  2 refactor …
```

### 4.1 What NaylaCruz's pass introduced (the durable core)

- **A tag-gated release pipeline** (`release.yml` on `v*` tags) with a full cross-platform package
  matrix — Windows MSVC/MinGW/LLVM × {x64, x86, ARM64}, Linux GCC/Clang × {x86_64, i686, arm64}, macOS
  Clang/GCC/LLVM × {x86_64, arm64}; an AI/CMake-inventoried expected-artifact list, a `validate-release`
  inventory job (expected vs actual, 54 packages since the 20 `.7z` and the Linux
  `.zip`/macOS `.tar.gz` convenience archives were retired), a global `SHA256SUMS`, and a single `publish` job
  built on `softprops/action-gh-release`.
- **Cache discipline:** Windows cache-gate jobs per toolchain, deterministic `hashFiles()` cache keys,
  shared vcpkg/ccache namespaces, `restore-keys` fallbacks, and a separate vcpkg cache warmup workflow.
- **vcpkg triplets** under `.gitlab/vcpkg-triplets/` (Clang-CL overrides, x64/x86-win-llvm chainloaded
  toolchains, Windows-MSVC triplet, debug/release variants) plus a pinned external triplets repo
  (`Neumann-A/my-vcpkg-triplets` reference in `ci.yml`/`release.yml`).
- **ARM64 Windows story:** WiX native ARM64 MSIs, CLANGARM64 jobs, a Windows ARM64 package smoke
  workflow, windows-11-arm runners in the release matrix.
- **ADR record:** five Architecture Decision Records (001 presets, 002 deterministic cache keys,
  003 SHA-pinned actions, 004 manual Coverity, 005 strict release/workflow separation).
- **Package-manager abstraction:** `cmake/PackageManager.cmake` selecting `vcpkg` (default) vs
  `conan2` vs `system`, backed by both `vcpkg.json` and `conanfile.txt`.
- **GitLab pipeline growth:** `.gitlab/.gitlab-ci.yml` grew 129 → ~2 600 lines with tag-scoped
  pipelines, a single `resolve_version` anchor, attestation helpers, ARM64/MinGW/LLVM Windows builds,
  Docker image builds, and a `create_release` job.
- **Experimental all-platforms branch/workflow** (`experimental/all-platforms-architectures-v2`) as a
  staging lane for configurations not yet promoted to main.
- **Android/NDK arm** (later removed — see Section 7): an `experimental-android-ndk.yml` workflow,
  `package_android_apk.sh`, and `packaging/android/` (Manifest + MainActivity) that produced 8 APK/ZIP
  artifacts. This is the only feature that was subsequently *deliberately removed*.

### 4.2 Releases produced by this fork

| Tag | Assets | Notes |
|---|---|---|
| `v0.0.4` … `v1.2.5` | 33 → 96 | progressive pipeline expansion |
| `v7.7.7` | 0 | early experimental tag |
| `v7.7.9` | 100 | final: Android ×4 ABI top-ups + 4 stray manifests (`expected*`/`actual*`) |

> The `actual.sorted`/`actual.txt`/`expected.sorted`/`expected.txt` entries on `v7.7.9` are the *origin*
> of the manifest-leak bug fixed later in the current fork (Section 7.3).

### 4.3 Trade-offs visible from history

- Many fast "fix:" churn commits on the release pipeline (YAML folding, PowerShell escaping, WiX
  conditions, cache key field names) indicate the matrix grew quickly and took several iterations to
  stabilize.
- Both GitHub and GitLab pipelines exist and run similar work — deliberate parity, but also a
  maintenance surface.

---

## 5. The Current Fork: `Jackie-SDX/cpp-project-template`

### 5.1 State on `main` (`96240c0`)

- **Commits:** 339; **files:** 122; **GH workflows:** 11; **GitLab CI:** 2 606 lines.
- **Branches:** `main` plus `experimental/all-platforms-architectures-v2` namespace, smoke branches,
  and a stale `ci/remove-android` (already merged via PR #5).
- **Releases:** `v0.0.1` (an early smoke tag), `v0.0.2` (96 assets, pre-Android-removal), `v0.0.3`
  (88 assets, post PR #5), `v0.0.4` (88 assets, post PR #6, flagged prerelease), `v0.0.5`
  (pre-release, 88 assets), `v0.0.8` (68 assets, PR #8 archive-policy), `v0.0.9`
  (57 assets, PR #9 strict one-archive-per-platform).

### 5.2 Changes owned by the current fork (relative to NaylaCruz `522bc3a`)

```
18 files changed, +433 / −600   (from NaylaCruz tip to current main)
```

1. **`6b1bd2e` — opencode workflow.** Adds `.github/workflows/opencode.yml`, which answers `issue_comment`
   and PR-review comments containing `/oc` or `/opencode`. This is the automation entrypoint used by the
   controlling agent infrastructure; it intentionally does minimal work (checkout + single agent action).
  2. **PR #5 (`e79bddc`) — remove Android; document workflows.** Stripped all Android/NDK support
   (workflow, packager script, manifest/activity) and added a Purpose/Trigger/References banner with
   documentation links to *every* remaining workflow. Re-verified with `actionlint` 1.7.12, `yamllint`,
   `cmake -P configure.cmake` smoke, and `git diff --check`.
  3. **PR #6 (`96240c0`) — release-asset hygiene.** The `validate-release` and `publish` jobs wrote their
   comparison manifests (`expected.txt`/`actual.txt`/`expected.sorted`/`actual.sorted`) into
   `release-assets/`, which `softprops/action-gh-release` uploads via `release-assets/*` — so every
   release carried 4 junk files. Both jobs now `rm -f` the manifests after the comparison; the stale
   files were also deleted from existing releases, and the merge notes (now § 12) were rewritten in a
   neutral voice.
  4. **`v0.0.3` / `v0.0.4` releases** with clean 88-asset inventories (85 packages + 2 source archives +
   `SHA256SUMS`).
  5. **2026-09-23 archive-policy releases.** PR #8 (`959f475`) retired the 20 `.7z` archives; PR #9
   (`a0503fd`) enforced the strict one-archive-per-platform rule and shipped final asset totals of 68
   (`v0.0.8`) and 57 (`v0.0.9`) — see § 6.5 and § 13.

---

## 6. Comparative Deep-Dive: Original vs Current

### 6.1 File inventory delta (original `71cae18` → current `96240c0`)

- Git equivalent: `61 files changed, +8 966 −1 189`.
- **Added (42 files):** `.circleci/config.yml`; nine workflows (`ci.yml`,
  `experimental-platform-matrix.yml`, `opencode.yml`, `release.yml`, `vcpkg-cache-warmup.yml`,
  `windows-arm64-package-smoke.yml`, `windows-package-smoke.yml`, `windows-test.yml`,
`workflow-lint.yml`); the `.gitlab/vcpkg-triplets/` tree (18 CMake triplet files incl. the
   `x64-win-llvm` chainloaded toolchain); `BUGS.txt` (since retired — content absorbed into § 13),
   `MERGE_NOTES.md` (since retired — content absorbed into § 12), `cmake/PackageManager.cmake`,
  `conanfile.txt`, `vcpkg.json`, five ADRs (`docs/architecture/decisions/001…005`), and two scripts
  (`scripts/generate_coverage.sh`, `scripts/run_clang_tidy.sh`).
- **Removed (2 files):** `.github/workflows/build-debug.yml`, `.github/workflows/build-release.yml`
  — replaced by the unified `ci.yml` + tag-gated `release.yml`.
- **Shared & modified (17 files):** the four triplet files kept GitHub's `static` CRT value; the
  root `CMakeLists.txt` (MSVC runtime `_DEFAULT`, `CPP_PROJECT_TEMPLATE_VERSION`, scoped llvm-rc
  workaround, `PackageManager.cmake` include, THEN the Android `if(ANDROID)` collapsed by PR #5);
  `CMakePresets.json` (full preset matrix); `CTestConfig.cmake` + `.github/scripts/test.cmake`
  (opt-in CDash); `cmake/cpack_module.cmake` (canonical names, WiX ARM64, PACKAGE_TOOLCHAIN suffix);
  `.gitlab/.gitlab-ci.yml` (129 → 2 606 lines); docs; CITATION; and the source bug fixes in
  `tutorial_1.hpp` / `tutorial_1_gtest.cpp` / `UserOpt.cpp` / `utils.cpp` / `projectwx` CMake.

### 6.2 Source-level changes worth calling out

| File | Change | Why |
|---|---|---|
| `src/projectlib/src/tutorial_1.hpp` | `factorial()` rewritten with `if constexpr` signed check, overflow detection, `bool` `static_assert`, `std::domain_error`/`std::overflow_error` | Correctness — the original `constexpr` loop overflowed and mis-behaved on negatives |
| `src/projectwx/src/utils.cpp` | `wordWrap()` no longer drops the next character; `width == 0` → `std::invalid_argument` | Real character-dropping bug fix |
| `src/projectcli/UserOpt.cpp` | `args.size()==0` → `args.empty()`; `#include` hygiene | Style + correctness |
| `src/projectwx/src/CMakeLists.txt`, `src/projectlib/test/CMakeLists.txt` | ARM64 Windows support; clang-cl guard on the static-CRT branch | LLVM/ARM64 matrix support without breaking MSVC |
| `CMakeLists.txt` | `CMAKE_MSVC_RUNTIME_LIBRARY_DEFAULT` (not the non-default cache var) | Lets the chainloaded LLVM toolchain keep its dynamic CRT while classic triplets stay static |
| `CMakeLists.txt` | `CPP_PROJECT_TEMPLATE_VERSION` argument fed by the CI from the git tag | Single source of truth for the release version instead of per-job re-derivation |
| `CMakeLists.txt` | `if(ANDROID)$`… remains only as the collapsed `option(BUILD_PROJECTWX …)` form | Android removal, PR #5 |

### 6.3 Workflow inventory: original vs current

| Workflow | Original | Current | Trigger |
|---|---|---|---|
| `build-debug.yml` / `build-release.yml` | ✔ (2) | — | replaced by `ci.yml` + `release.yml` |
| `ci.yml` | — | ✔ | push/PR to `main` + manual |
| `workflow-lint.yml` | — | ✔ | push/PR/manual (actionlint gate, pin `1.7.12`) |
| `release.yml` | — | ✔ | `v*` tag (full), PR (smoke with `full-release-test` label), manual |
| `vcpkg-cache-warmup.yml` | — | ✔ | manual/release (warms Windows + Linux caches) |
| `experimental-platform-matrix.yml` | — | ✔ | push to `experimental/…-v2` + manual |
| `windows-test.yml` / `windows-(arm64-)package-smoke.yml` | — | ✔ | manual / label-gated PR / parity branch |
| `doxygen-gh-pages.yml` | ✔ | ✔ | push to `main` + manual (pins CMake/Doxygen/Graphviz) |
| `clear_cache.yml` | ✔ | ✔ | manual only |
| `opencode.yml` | — | ✔ | issue/PR comment containing `/oc` |

### 6.4 Release asset delta (MangaD `v0.0.1` → current `v0.0.4`)

- Original `v0.0.1`: 20 assets, version `1.0.0.0`, three OS families.
- NaylaCruz `v7.7.9`: 100 assets (incl. 8 Android + 4 stray manifests).
- Current `v0.0.2`: 96 assets (8 Android + 88 core) — the interim tag used to validate PR #5.
- Current `v0.0.3` / `v0.0.4`: exactly **88 assets** = 85 packages (Windows MSVC i686/x86_64 + ARM64,
  CLANGARM64 ARM64, MinGW i686/x86_64, LLVM i686/x86_64/ARM64; Linux GCC i686/x86_64/ARM64,
  Clang x86_64/ARM64; macOS Clang/GCC/LLVM × x86_64/arm64) + 2 source archives + `SHA256SUMS`, with
  **zero** stray manifests.

The difference between `v7.7.9` (100) and current (88) is exactly the **8 Android artifacts removed**
plus the **4 strays** — i.e. no other product asset changed.

### 6.5 Archive-format policy (decision record, 2026-09-23)

Issued from issue #130 ("UPDATE ON DISTANT REPO") on the current fork. The policy tightened in two
steps the same day:

1. **Option A** (`v0.0.8`, merged via PR #8): remove the 20 `.7z` standalone archives only; keep the
   Linux `.zip` and macOS `.tar.gz` convenience archives.
2. **Strict one-archive-per-platform** (`v0.0.9`, supersedes Option A): the `v0.0.8` assets still
   shipped two standalone archives per Linux/macOS toolchain, so per explicit owner direction the
   convenience archives were also removed. Each platform now ships exactly one standalone archive.

| Platform | Standalone archive (only) | Installers (unchanged) |
|---|---|---|
| Windows | `.zip` | `.exe` (NSIS), `.msi` (WiX) |
| Linux | `.tar.gz` | `.deb`, `.rpm` |
| macOS | `.zip` | `.dmg` |

- `.7z` is no longer generated, uploaded, checksummed, or published in any workflow (GitHub Actions
  `release.yml`/`ci.yml`/package-smoke workflows and GitLab CI). The historical Windows `cpack -G 7Z`
  alternative remains in the source as a **commented-out, disabled block** so the option stays
  documented without shipping.
- Inventory math: 85 → 65 → **54** packages (20 `.7z` + Linux `.zip`/macOS `.tar.gz` retired; Windows
  3×7=21, Windows ARM64 3×2=6, Linux 3×5=15, macOS 2×6=12), global `SHA256SUMS` 87 → 67 → **56**
  lines, release assets 88 → 68 → **57** (54 + 2 source archives + `SHA256SUMS`).
- Decision context, actions taken, validation evidence, and residual follow-ups are recorded in
  § 13 (Release Archive Policy — Session Record), which replaces the obsolete root `BUGS.txt` (the
  former `RELEASE_ARCHIVE_POLICY_SESSION.md`, whose content now lives in this document).

---

## 7. Decisions Taken (with the alternatives considered)

### 7.1 D1 — Absorb the divergent GitHub/GitLab copies into one repo
**Decision:** consolidate both pipelines, triplets, scripts, and source fixes into one tree
(see § 12, Merge Notes).
**Rationale:** the two copies had genuinely diverged (different CMake flags, opposite CRT linkage,
different triplet sets, different bug fixes). Keeping one source of truth prevents silent drift.
**Alternatives:** leave both copies live and keep a sync job (rejected — drift already bit twice);
fork-and-never-merge (rejected — loses NaylaCruz's fixes).

### 7.2 D2 — Strict separation of release workflows (`ADR 005` + `ci.yml`)
**Decision:** `release.yml` triggers only on `v*` tags (or an explicit `full-release-test` label on a
PR); `ci.yml` covers PR validation without building installers.
**Rationale:** previously installers were rebuilt on every PR, wasting compute and producing unusable
artifacts.
**Alternatives:** keep packaging in `ci.yml` (rejected — expensive); build installers on every PR but
discard them (rejected — same waste).

### 7.3 D3 — Release inventory manifests must never leak into uploads
**Decision:** `validate-release` and `publish` delete `expected/actual` manifests after comparison;
release still runs `verify-inventory` + `SHA256SUMS` preflight.
**Rationale:** `expected.txt`/`actual.txt`/`expected.sorted`/`actual.sorted` were real, downloadable junk
on releases (already on NaylaCruz `v7.7.9` and current `v0.0.2`/`v0.0.3`).
**Alternatives:** publish from an explicitly enumerated file list (rejected — a glob is simpler and
safe once the directory is clean); keep manifests but rename them (rejected — hide, not fix).

### 7.4 D4 — Remove Android/NDK entirely
**Decision:** delete `experimental-android-ndk.yml`, `package_android_apk.sh`, `packaging/android/`,
the NDK branch in `configure.cmake`, and collapse the `if(ANDROID)` in `CMakeLists.txt`; release
inventory drops 93+2 → 85+2.
**Rationale:** the CI matrix is desktop-only (Linux/Windows/macOS); Android adds an ABI-exhaustive
matrix that nobody in this lineage ships or tests; keeping a semi-working APK path is worse than none.
**Alternatives:** keep Android on the experimental branch only (rejected — dead config, `actionlint` +
inventory noise); keep but gate with a label (rejected — untested config still ships).

### 7.5 D5 — Deterministic cache keys (`ADR 002`)
**Decision:** `hashFiles('**/CMakeLists.txt','**/vcpkg.json')`-based keys + `restore-keys` fallback.
**Rationale:** timestamp-based keys caused ~100% cache misses and wasted hours per week.
**Alternatives:** no caching (rejected — rebuild cost); manual cache invalidation (rejected — fragility).

### 7.6 D6 — Pin third-party actions to commit SHAs (`ADR 003`)
**Decision:** all third-party actions pinned to immutable SHAs; Dependabot nominated to propose updates.
**Rationale:** mutable tags (`@main`, `@v4`) are a supply-chain risk (compromised repo → arbitrary code
in CI).
**Alternatives:** keep `@vN` tags (rejected — spoofable); vendor all actions (rejected — maintenance).

### 7.7 D7 — CMakePresets as the single source of build truth (`ADR 001`)
**Decision:** `CMakePresets.json` exposes `default`, `release`, `coverage`, `tidy`, `cppcheck` (+
CLI `-D` when a preset is not sufficient).
**Rationale:** parity between local (IDE) and CI builds; fewer hand-assembled `cmake -D` lines.
**Alternatives:** keep wrapper scripts (rejected — drift and maintenance).

### 7.8 D8 — Manual Coverity (`ADR 004`)
**Decision:** Coverity runs only on `workflow_dispatch`.
**Rationale:** DAST quota is weekly; running on every push exhausted it.
**Alternatives:** cron-scheduled scan (rejected — still quota-bound); drop Coverity (rejected — signal value).

### 7.9 D9 — Dual package manager, vcpkg default (`PackageManager.cmake` + D9 rationale)
**Decision:** `PACKAGE_MANAGER` ∈ {vcpkg (default), conan2, system}; same `find_package()` calls
everywhere.
**Rationale:** both managers provision the same two deps (wxWidgets, GTest); third-party (employer)
requested Conan support; CI only provisions vcpkg today, so the default cannot flip yet.
**Alternatives:** vcpkg only (rejected — requirement); Conan default now (rejected — breaks every
pipeline until `conan install` is wired in).

### 7.10 D10 — Static vs dynamic CRT on Windows
**Decision:** seed `CMAKE_MSVC_RUNTIME_LIBRARY_DEFAULT` (static) so classic triplets stay static while
the chainloaded LLVM/Clang-CL toolchain (dynamic CRT) can override it; the test-target MSVC branch is
skipped under clang-cl.
**Rationale:** GitLab used dynamic, GitHub static; a plain `set(CMAKE_MSVC_RUNTIME_LIBRARY)` would win
over the LLVM toolchain file and break the link. Cross-validated by `windows-test.yml`.
**Alternatives:** static everywhere (rejected — breaks LLVM/Clang-CL); dynamic everywhere (rejected —
breaks the classic static triplets).

### 7.11 D11 — Opt-in CDash instead of upstream submission
**Decision:** `CTestConfig.cmake` now requires `-D CDASH_SUBMIT=ON -D CDASH_PROJECT_NAME=<you>` ;
`test.cmake` reads its script-scope variable first, env var second.
**Rationale:** the original silently submitted every CI run to **the upstream author's** CDash project.
**Alternatives:** keep upstream submission (rejected — data pollution); self-host a dashboard now
(rejected — no infra yet).

### 7.12 D12 — Single version resolution anchor
**Decision:** `vX.Y.Z → X.Y.Z` validated once (`resolve_version` anchors in GitLab; `CPP_PROJECT_TEMPLATE_VERSION`
argument from the tag in GitHub), local builds stay `0.0.1.0`.
**Rationale:** the release number is derived consistently instead of re-parsed per job (a known
fragility — see the `canonical_package_name.txt` note in § 12, a candidate future change).
**Alternatives:** per-job sed on `CPackConfig.cmake` (rejected — fragile, still used on GitHub side);
hardcode (rejected).

### 7.13 D13 — Windows ARM64 native installers
**Decision:** WiX emits native ARM64 MSIs (`CPACK_WIX_ARCHITECTURE=arm64`), windows-11-arm runners
validate them, and a Windows ARM64 smoke workflow checks the PE machine header is `0xAA64`.
**Rationale:** the ARM64 artifact previously defaulted to an x64 MSI.
**Alternatives:** ship ARM64 payload under an x64 installer (rejected — wrong header); drop ARM64
(rejected — runner availability).

### 7.14 D14 — Experimental staging lane
**Decision:** `experimental/all-platforms-architectures-v2` + `experimental-platform-matrix.yml` keeps
unproven configs off `main`.
**Rationale:** failures in the experimental lane never block the primary gates.
**Alternatives:** test everything on `main` (rejected — noise); delete unproven configs (rejected —
loses the work).

### 7.15 D15 — OpenCode automations on the repo itself
**Decision:** add `opencode.yml` (comment-triggered) to the fork so the controlling agent can operate on
this repository end-to-end.
**Rationale:** the whole Android-removal + documentation + hygiene pass above was executed through this
entrypoint; keeping it in the tree makes the capability durable.
**Alternatives:** control everything from a separate orchestrator repo (the current architecture keeps
policy in the controller repo; the fork's action is intentionally minimal).

---

## 8. How the Project Works Now (Operational View)

### 8.1 Build system
1. `cmake --preset <name>` (or CI equivalents) → configure with Ninja.
2. `cmake/PackageManager.cmake` picks `vcpkg`/`conan2`/`system`; vcpkg uses the pinned builtin-baseline
   + app-local or external triplets.
3. Targets: `projectlib` (static lib + GoogleTest), `projectcli` (console), `projectwx` (wxWidgets GUI);
   `BUILD_SOURCE`/`BUILD_PROJECTWX`/`BUILD_TESTING` switches.
4. CTest runs unit + CLI wrapper tests; optional memcheck (Linux) and coverage (Linux/gcc) stages.
5. CPack produces the artifact set; `cpack_module.cmake` names everything
   `cpp-project-template_<ver>_<os>-<toolchain>-<arch>.<ext>`.

### 8.2 GitHub Actions (11 workflows)
- `ci.yml`: primary PR/`main` gate (Debug+Release for Ubuntu GCC, macOS Clang, Windows MSVC x64/i686,
  Windows LLVM x64, Windows MinGW x64/i686), coverage uploads, ccache + vcpkg cache restore.
- `workflow-lint.yml`: `actionlint` on every workflow (the repo's own gate for any workflow change).
- `release.yml`: cache-gate → package/source/expanded-package → validate-release → publish (tag-only).
- `vcpkg-cache-warmup.yml`: pre-bakes the toolchain caches into the Actions cache for fast releases.
- `experimental-platform-matrix.yml`: staging lane configs.
- `windows-test.yml`, `windows-package-smoke.yml`, `windows-arm64-package-smoke.yml`: targeted Windows
  checks outside `ci.yml`.
- `doxygen-gh-pages.yml` (built docs → `gh-pages`), `clear_cache.yml` (manual wipe), `opencode.yml`.

### 8.3 Release flow (what happens on a `v*` tag push)
```
cache-gate (8 Windows legs)
   ├─► package (8 configs) + source (2 archives) + expanded-package (fills ARM64/Clang/32-bit/macOS)
   └─► validate-release  : inventory must == 54 packages; SHA256SUMS written + verified; manifests rm -f
   └─► publish (tag only): re-verify, preflight (54 packages; SHA256SUMS 56 lines), softprops upload
```

### 8.4 GitLab pipeline
Mirrors the same matrix (docker images → static analysis → build → docs → package → release → cache
maintenance) with tag-scoped rules so release tags skip non-consumed jobs, honoring ADR 005.

---

## 9. Known Issues and Residuals (honest inventory)

1. **`ci/circleci:*` checks fail on PRs in the current fork** — pre-existing on `main` (also failed on
   `e79bddc`). The `.circleci/config.yml` is not referenced by any GitHub workflow and no CircleCI
   project is wired to the fork; the failing external check is noise from GitHub's old CircleCI app.
2. **README stale badges:** the README still badges `build-debug.yml`/`build-release.yml`, which were
   removed, and points release/status shields at the MangaD repo. Cosmetic but stale.
3. **`ci/remove-android` branch** remains after PR #5 merged (harmless leftovers).
4. **`v0.0.2` release still contains 8 Android assets** (it predates PR #5) — intentional; it is a
   historical tag.
5. **CDash/Coverity/Codecov/Coveralls** shields reference upstream projects; forks contribute to
   another author's dashboards unless they configure their own (now opt-in — see D11).
6. **Circles of dependencies** — vcpkg builtin-baseline, external triplets repo, and CMake version pins
   must be bumped together; there is no Dependabot config in the tree yet.
7. **Conan is configured but not CI-provisioned** — `PACKAGE_MANAGER=conan2` works locally but no
   pipeline runs `conan install` (by design, D9).
8. **The root bug ledger was consolidated into the release-archive-policy session record**
   (§ 13, replacing `BUGS.txt`); the legacy Windows MinGW/LLVM vcpkg
   cache observability and ARM64 Windows package-smoke follow-ups carry over there.
9. Minor: `packaging/windows/version.rc.in` still uses the old project-author identity in places;
   `CITATION.cff` still points at MangaD URLs.
10. `docs/architecture/decisions/.test` and `scripts/.test` / `.gitlab/vcpkg-triplets/.test` are
    empty placeholder files (informational only).

---

## 10. Future Work (candidates)

**Pipeline / reliability**
- **Prune dead workflows/config:** decide whether `.circleci/config.yml` is wired up or deleted;
  remove the stale `ci/remove-android` branch.
- **Dependabot config** for the SHA-pinned actions + vcpkg baselines.
- **Investigate Windows MinGW/LLVM vcpkg cache behavior** (carried over from the archived bug ledger):
  distinguish Actions-cache hits, vcpkg binary-cache hits, and source rebuilds in logs.
- **Native ARM64 Windows package smoke** — promote once the known bug is fixed.
- **Migrate GitHub release name extraction** to the same `canonical_package_name.txt` written by
  `cpack_module.cmake` (noted in § 12 as the fragile `sed` on `CPackConfig.cmake`).

**Product / build**
- Make `conan2` the default once `conan install` is wired into every CI config that needs it (D9).
- Promote the experimental all-platforms lane entries that prove stable into `ci.yml`/`release.yml`.
- Close the README "progress status" gaps if they matter (Qt, Boost, Catch2, signing, i18n, Jenkins).

**Docs / governance**
- Refresh README badges/site shields to the fork's own repos and workflows.
- Archive the old `v0.0.2` / `v0.0.1` tags or annotate them as historical to avoid confusion.
- Decide the fate of the GitLab copy (keep it exercised, or freeze it) — the two-pipeline maintenance
  cost is real.

**Automation**
- Extend `opencode.yml` capabilities (context, timeouts, secret scope) to keep the fork's
  autonomous-workflow story in line with the hardened controller-side policy.

---

## 11. Compiler & Architecture Q&A (2026-09-23)

Answers recorded from issue #130 ("UPDATE ON DISTANT REPO") on the controlling fork, consolidated
here as the single in-tree reference. The architecture items are **recommendations**, not accepted
policy — record them as candidates and implement only where they clearly help.

### 11.1 Q: What is the difference between "CLANG" and "LLVM" in the matrix?

**macOS**

- **macOS Clang (apple-clang):** Apple's own fork of Clang shipped with Xcode/Command Line Tools
  (what our `macos-apple-clang-*` artifacts use). Patched and versioned by Apple, tightly coupled to
  the Apple SDK, default toolchain on a Mac.
- **macOS LLVM:** upstream Clang/LLVM straight from the LLVM project (e.g. Homebrew `llvm` or an
  official LLVM release). Same compiler family, but stock/upstream — usually newer than Apple's
  build, no Apple-specific patches, and you point it at the SDK yourself.

So: both are Clang; "apple-clang" = Apple's Xcode fork, "llvm" = upstream LLVM project build.

**Windows**

- Unlike macOS there is **no vendor fork** — on Windows, Clang *is* part of upstream LLVM, so
  "Windows Clang" and "Windows LLVM" are effectively the same toolchain. Any practical difference is
  just packaging/integration: standalone LLVM installer vs Clang bundled elsewhere, and driver mode
  (clang-cl with MSVC headers/libs/ABI vs GNU-style driver).
- The genuinely different Windows compiler in our matrix is **MSVC (`cl`)** — Visual Studio's own
  compiler, not LLVM at all. (MinGW is a third variant: GCC toolchain, or Clang in GNU/MinGW mode.)

### 11.2 Q: Are the architecture names the best? (i686, x86_64, arm64)

Short verdict: yes, they're good — those are the de-facto toolchain conventions
(`uname -m`/CMake/GCC style), so nothing is wrong. But there are a few refinements worth considering.

**Per-arch notes**

- **x86_64** — keep it. It's the most neutral, toolchain-faithful label (what `uname -m`,
  `CMAKE_SYSTEM_PROCESSOR`, and GCC emit). The alternatives are ecosystem-specific: `amd64`
  (Go, Debian, Rust targets, the kernel) and `x64` (Windows, Node, .NET RID). The only real trap is
  mixing them: e.g. the CI smoke names `linux-gcc-x64.zip` while release artifacts use `x86_64`.
  Pick exactly one canonical token and enforce it across every workflow.
- **arm64** — fine as a cross-platform choice (matches macOS/Windows/.NET `osx-arm64`/`arm64`), but
  Linux tooling calls this `aarch64` (`uname -m`, GCC triplets, Debian/Ubuntu). Since the scheme
  spans all three OSes, `arm64` is a reasonable canonical form — just publish a mapping table
  (`arm64 ↔ aarch64`) in the release docs so a Linux user can match an artifact to `uname -m`. If a
  Linux-only namespace is ever shipped, `aarch64` is the drop-in-faithful choice there.
- **i686** — legitimate: the conventional 32-bit x86 baseline (Pentium Pro ABI, what
  glibc/debian i386 builds assume). If 32-bit is needed at all, `i686` is the right label. The only
  real question is whether 32-bit support is needed at all: x86-32 is being retired across the
  ecosystem (distros, LLVM, most prebuilt deps), so if nothing consumes it, dropping it saves build
  inventory and CI time.

**General improvements (recommendations)**

1. **One canonical token per arch** — define `x86_64`, `i686`, `arm64` (or whatever is chosen) as
   the *only* strings allowed in names/globs/validators, and grep CI for stray `x64`/`amd64`/
   `aarch64` variants.
2. **Add a small arch-mapping table in the release docs** — `artifact arch → uname -m → Python
   platform.machine() → .NET RID`, so anyone can map an asset to their machine.
3. **Keep the `platform-compiler-arch` order** — `linux-clang-arm64` already reads well; just keep
   it consistent, including the short form users see.
4. **If architectures expand later**, mirror the standard GNU triplets (`armv7l`/`armhf`,
   `ppc64le`, `riscv64`, …) rather than inventing names.

Net: the names are standard and defensible; the only *actual* issues are the `x86_64`/`x64`
inconsistency and the undocumented `arm64`↔`aarch64` split.

### 11.3 Q: Are there benefits to compiling across all these compiler variants?

Yes — for a distributed C++ project, building across the compiler matrix has real benefits:

**Real benefits**

- **Different compilers catch different bugs.** MSVC, GCC, and Clang each have their own
  diagnostics, default warning levels, and standards-conformance strictness. Code that compiles
  cleanly on all three is almost always more portable and standard-compliant than code that only
  builds on one.
- **Portability proof.** Each compiler parses templates, UB-prone constructs, and standard-library
  usage slightly differently. A green matrix is real evidence the code isn't relying on one
  toolchain's quirks.
- **Users get a native match.** An MSVC user wants an MSVC-built `.exe`/`.msi` (matching their
  runtime, e.g. CRT), a MinGW user wants a GNU-ABI binary, and so on. Prebuilt artifacts per
  compiler mean fewer "won't run on my machine" reports.
- **Divergent optimizations/codegen.** Compilers optimize differently; building with all of them can
  expose latent bugs (e.g. miscompilation-sensitive code) and gives a sanity check that performance
  is in the same ballpark.

**Where it has diminishing returns**

- **Windows Clang vs LLVM** are effectively the same upstream toolchain (as discussed above) — that
  pairing is mostly packaging/integration coverage, not independent compiler coverage.
- **Apple-clang vs Homebrew LLVM on macOS** is the same Clang family; the value is SDK/version
  coverage more than a second opinion.
- The genuinely distinct "brains" in the matrix are: **MSVC, GCC, Clang/LLVM (incl. MinGW as its ABI
  flavor), and Apple-clang as a vendor fork.** Those provide the independent bug-catching.

**Bottom line:** keep at least one build from each genuinely distinct compiler family (MSVC, GCC,
Clang, Apple-clang). Beyond that, extra variants mainly buy ABI/packaging coverage (MinGW,
clang-cl) and CI cost rather than much additional bug-finding. If CI time ever becomes a pain, the
first things to trim are duplicate legs like Clang-vs-LLVM on the same OS, not the four core
families.

---

## 12. Merge Notes: GitHub Copy + GitLab Copy

Records how the GitHub (`cpp-project-template-main`) and GitLab (`bs-main`) copies of the template
were merged into this single repository, and the reasoning behind each decision. Reference material
for reviewers; does not affect the build or releases.

### 12.1 Summary of decisions

- **`.github/workflows/*` + `.github/scripts/*`** — taken from the GitHub copy, wholesale.
  `.gitlab-ci.yml` never calls these scripts, so the GitLab-side copies of them were dead/stale
  files rather than an intentional GitLab-only change.
- **`.gitlab/.gitlab-ci.yml` + `.gitlab/vcpkg-triplets/*`** (except the four files called out
  below) — taken from the GitLab copy, wholesale. That is the actively used, far larger (124 KB vs
  14 KB) pipeline; the GitHub-side copy of it was the stale template default.
- **`CMakePresets.json`, `CTestConfig.cmake`, `CITATION.cff`, `conanfile.txt`,
  `cmake/PackageManager.cmake`, `scripts/generate_coverage.sh`** — taken from the GitLab copy. Each
  carries a dated comment describing a real, specific bug it fixes (wrong CDash project, a coverage
  regex that never matched, RPM license format, etc.) and none conflict with the GitHub side.
- **`tutorial_1.hpp`, `tutorial_1_gtest.cpp`, `UserOpt.cpp`, `utils.cpp`,
  `projectwx/src/CMakeLists.txt`** — taken from the GitHub copy. In every case the GitHub version
  contains a genuine fix the GitLab version lacks (overflow/negative checks in `factorial()`, a
  character-dropping bug in `wordWrap()`, ARM64 Windows support, verified by reading the logic).
- **Hand-merged files (not taken wholesale from either side):** root `CMakeLists.txt`, the four
  classic Windows vcpkg triplets, `src/projectlib/test/CMakeLists.txt`, and
  `cmake/cpack_module.cmake`. Details below.
- **`BUGS.txt`** (GitHub-only) and **`.circleci/`** (GitLab-only) were carried over as pure
  additions; neither pipeline references the other's extra file. `.circleci/` is unused and can be
  removed if the project will not use CircleCI.

### 12.2 Static vs. dynamic CRT on Windows

The root `CMakeLists.txt` is different between the two copies for a deeper reason than one file:

- GitHub's `CMakeLists.txt` forces the MSVC runtime to static
  (`CMAKE_MSVC_RUNTIME_LIBRARY`), justified in its own comment as "consistent with the existing
  GitHub static-vcpkg toolchain". GitLab's does not set it (CMake defaults to dynamic). The same
  split is mirrored in the four "classic" vcpkg triplets that exist in both `.gitlab/vcpkg-triplets/`
  trees with the same filenames but opposite `VCPKG_CRT_LINKAGE` — GitHub: static, GitLab: dynamic.
  Mixing a statically-linked project with dynamically-linked vcpkg dependencies (or vice versa)
  fails at link time.
- Resolution: GitHub's own `windows-test.yml` (a workflow that only exists in the GitHub copy)
  cross-validates this exact question — it clones the GitLab repo, overlays GitHub's
  `.gitlab/vcpkg-triplets/` on top, and builds and tests the result. Combined with GitHub's
  static-CRT comment pointing at the same triplets, GitHub's `static` value is the configuration that
  is actually validated. Therefore the four classic triplet files keep GitHub's `static` value;
  GitLab's extra comments on the two `-debug` variants (a real zlib/wxWidgets header-install
  ordering issue) were kept as documentation.
- GitLab separately added real, working LLVM/Clang-CL cross-compilation support
  (`x64-win-llvm`, `x86-win-llvm`, `Clang-CL-override.cmake`, etc.) that deliberately uses
  **dynamic** CRT via its own chainloaded toolchain file. Had GitHub's static override been kept as a
  plain `set(CMAKE_MSVC_RUNTIME_LIBRARY ...)`, it would silently win over that toolchain file and
  break the LLVM path. The merged `CMakeLists.txt` therefore sets
  `CMAKE_MSVC_RUNTIME_LIBRARY_DEFAULT` instead — a default that the LLVM toolchain file's own
  (later-executing) setting can override.
- The same conflict existed one level down in `src/projectlib/test/CMakeLists.txt`, where the MSVC
  branch directly forces the test target's runtime library. That branch is now skipped under clang-cl
  (`AND NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang"`) so it cannot override the LLVM path there
  either. Both fixes are explained in comments at the point they are made.
- First place to watch after merging is the "Windows LLVM x64" leg in `ci.yml` and the GitLab
  LLVM/Clang-CL jobs: if `CMAKE_MSVC_RUNTIME_LIBRARY_DEFAULT` and the clang-cl skip do not compose as
  documented, a CRT-mismatch linker error appears there — an isolated, easy-to-spot failure mode.

### 12.3 `cmake/cpack_module.cmake`

Neither side was a strict superset here, so it was hand-merged:

- Base: **GitHub's** version. It fixes a real bug still present in GitLab's — a
  `CPACK_NSIS_DEFINES` block with quoted `VIAddVersionKey` arguments that produces malformed NSIS
  commands — and uses safer `file(TO_CMAKE_PATH ...)` path handling instead of raw backslash
  escapes.
- Added back from **GitLab**: the `canonical_package_name.txt` write. `.gitlab-ci.yml`'s packaging
  jobs read that file back and hard-fail if it is missing. It is a pure addition and does not affect
  GitHub's release process, which extracts the package name its own way (a `sed` pattern over
  `CPackConfig.cmake` in `release.yml`). GitLab's own comment notes that sed approach is the fragile
  one; migrating `release.yml` to read the same file is a candidate future change but was
  deliberately not made unrequested.
- Also added back from **GitLab**: `CPACK_DMG_BACKGROUND_IMAGE` for the macOS installer (cosmetic).

### 12.4 Carried over from GitLab as-is

`x64-win-llvm.cmake`, `x64-win-llvm-release.cmake`, `x86-win-llvm.cmake`, `Clang-CL-C.cmake`,
`Clang-CL-CXX.cmake`, `Clang-CL-override.cmake`, `Windows-MSVC.cmake`, `extra_setup.cmake`,
`port_specialization.cmake`, and the `x64-win-llvm/` subfolder. These are referenced only by
`.gitlab-ci.yml` — GitHub's workflows get their LLVM triplet from a separate external repository
(`Neumann-A/my-vcpkg-triplets`, pinned in `ci.yml` / `release.yml`) — so there is no overlap to
resolve.

### 12.5 Pre-existing items intentionally not changed

- Some files still say `MangaD` / `David Gonçalves` (the original template's upstream identity —
  e.g. `CITATION.cff`'s ORCID, a test file's `@author` doc-comment) while `CMakeLists.txt` uses
  `NaylaCruz`. This inconsistency pre-existed in both copies and is a leftover-templating cleanup,
  not a merge conflict.
- `src/projectwx/src/CMakeLists.txt` has one more `)` than `(` by a naive paren count; the imbalance
  is inside a commented-out line (`#MSVC_RUNTIME_LIBRARY ...DLL")`), present in GitHub's original
  file, and is not a real imbalance.

---

## 13. Release Archive Policy — Session Record (2026-09-23)

Session record for the 2026-09-23 changes to the standalone release archive policy on this
repository, including the shift to the **strict one-archive-per-platform** rule for `v0.0.9`. This
section absorbs the former root `RELEASE_ARCHIVE_POLICY_SESSION.md` and replaces the obsolete root
`BUGS.txt` (which has served its purpose: all items it listed are resolved or carried forward in
§ 13.7 below).

| Field | Value |
|---|---|
| Date | 2026-09-23 |
| Target repository | `Jackie-SDX/cpp-project-template` |
| Origin | Issue #130 ("UPDATE ON DISTANT REPO") on the controlling fork |
| Affected releases | `v0.0.8`, `v0.0.9` |
| Document scope | Plan, actions, decisions, bugs observed, validation evidence, follow-ups |

### 13.1 Objective

Harden the standalone release archive policy so every upload "just works" for the platform it
targets.

Policy history on this date:

- **`v0.0.8` (Option A, merged via PR #8):** removed the 20 `.7z` standalone archives entirely;
  kept the Linux `.zip` and macOS `.tar.gz` convenience archives; installers and source archives
  untouched.
- **`v0.0.9` (strict policy, supersedes Option A):** after inspection, the existing `v0.0.8` assets
  still shipped two standalone archives per Linux/macOS toolchain (Linux `.zip` + `.tar.gz`, macOS
  `.tar.gz` + `.zip`). Per explicit owner direction in the issue thread, the convenience archives
  were dropped so **each platform ships exactly one standalone archive per toolchain**.

### 13.2 New policy (current, `v0.0.9`)

| Platform | Standalone archive (only) | Installers (unchanged) |
|---|---|---|
| Windows | `.zip` | `.exe` (NSIS), `.msi` (WiX) |
| Linux | `.tar.gz` | `.deb`, `.rpm` |
| macOS | `.zip` | `.dmg` |

`.7z` is never generated, uploaded, checksummed, or published. The historical Windows
`cpack -G 7Z` alternative remains in the source as a **commented-out, disabled block** in the
Windows packaging steps so the option stays documented without shipping (see
`.github/workflows/release.yml`, `.github/workflows/windows-package-smoke.yml`,
`.github/workflows/windows-arm64-package-smoke.yml`, and GitLab parity comments). The
`7zip`/`7z` tool provisioning retained by the Windows runners exists solely so the commented
alternative can be restored as-is.

### 13.3 Inventory math

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

### 13.4 Bugs and observations found during inspection

- `vcpkg-cache-warmup.yml` provisions `7zip` on the Windows runner and uses `7z | Select-Object
  -First 1` purely as a version probe — tooling, not artifact generation; left unchanged.
- `docs/install.md` lines 243-244 point at third-party `mingw-builds-binaries` `.7z` downloads
  (niXman releases) — third-party toolchain archives, out of scope; left unchanged.
- `cmake/cpack_module.cmake` and the top-level `CMakeLists.txt` contain no `.7z` logic — no changes
  needed there.
- No `.7z` references exist under `.circleci/`, `HISTORICAL/`, `packaging/`, or `scripts/`.
- `v0.0.5` (a historical prerelease) still carries 88 assets including `.7z`; that is a historical
  tag and is intentionally left untouched.
- `v0.0.8` still shipped Linux `.zip` and macOS `.tar.gz` convenience archives alongside the
  canonical archives. This was the direct trigger for the strict one-archive-per-platform policy in
  `v0.0.9`.

### 13.5 Files changed

GitHub Actions workflows (`v0.0.8` + `v0.0.9` combined):

- `.github/workflows/release.yml`:
  - `v0.0.8`: header + policy banner; removed the two `(cd instdir && cmake -E tar cf ...
    --format=7zip .)` lines in the `package` and `expanded-package` Linux/macOS steps; removed the
    `cmake -E tar --format=7zip` block in the `expanded-package` Windows step; commented-out the
    `cpack -G 7Z` alternative in the `package` "Package Windows" step; removed `.7z` from the
    expected/actual inventory globs and printf lists in `validate-release` and `publish`; updated
    counts 85 → 65 and `SHA256SUMS` 87 → 67.
  - `v0.0.9` (strict): removed the Linux `(cd instdir && cmake -E tar cf
    "../release-assets/${PREFIX}.zip" --format=zip .)` lines in the `package`, `package-smoke`, and
    `expanded-package` Linux steps; removed the macOS `(cd instdir && tar -czf
    "../release-assets/${PREFIX}.tar.gz" .)` lines in the `package` and `expanded-package` macOS
    steps; removed the corresponding `.zip` / `.tar.gz` entries from the expected/actual inventory
    printf lists and globs in `validate-release` and `publish`; updated counts 65 → 54 and
    `SHA256SUMS` 67 → 56; header + policy banner rewritten with the strict policy.
- `.github/workflows/ci.yml`:
  - `v0.0.8`: Linux packaging smoke no longer generates or asserts `linux-gcc-x64.7z`.
  - `v0.0.9`: Linux packaging smoke no longer generates or asserts `linux-gcc-x64.zip`.
- `.github/workflows/windows-package-smoke.yml` — header; `cpack -G 7Z` block now a commented-out
  disabled alternative; `.7z` removed from the expected-artifacts list.
- `.github/workflows/windows-arm64-package-smoke.yml` — header; `cpack -G 7Z` block now a
  commented-out disabled alternative; `.7z` removed from the expected list and the `Get-FileHash`
  glob.
- `.gitlab/.gitlab-ci.yml`:
  - `v0.0.8`: removed the Windows `cpack -C Release -G 7Z` step and the `*.7z` copy/upload in the
    Windows/Linux/macOS legs (with comments documenting the policy); updated related format mentions
    in comments.
  - `v0.0.9`: Linux legs no longer run `cpack -C Release -G ZIP` or copy `*.zip`; the macOS leg no
    longer manually builds `release-assets/${CANONICAL_BASE}.tar.gz` (the `.zip` from CPack's ZIP
    generator remains); comments updated to the strict policy.

Documentation (`v0.0.8` + `v0.0.9` combined):

- `docs/PROJECT_DOCUMENTATION.md` — current-pipeline inventory count reflected for Option A
  (65 / 67) and then the strict policy (54 / 56); release-flow ascii diagram updated; § 6.5
  archive-format policy decision record updated to the strict one-archive-per-platform rule; the
  session record itself consolidated into § 13 (this section).
- `docs/install.md` — Archive section (see § 6.5) now documents the single-archive-per-platform
  policy table (Windows `.zip`, Linux `.tar.gz`, macOS `.zip`).
- `RELEASE_ARCHIVE_POLICY_SESSION.md` — deleted; content absorbed into this section.
- `BUGS.txt` — deleted (obsolete; residual follow-ups carried into § 13.7).

### 13.6 Validation

- YAML parse of every edited workflow plus `workflow-lint.yml`'s `actionlint` gate.
- PowerShell/bash syntax checks of the edited inline script blocks.
- Grep proof: no active (non-comment) `.7z` path remains anywhere in the pipeline (GitHub Actions +
  GitLab CI); no active Linux `.zip` or macOS `.tar.gz` generation path remains in the pipeline.
- Refactored inventory-validator simulation: 54 expected packages, 56 `SHA256SUMS` lines, 57 release
  assets.
- CI verification on the pull request branch (GitHub Actions) before merge.
- Post-release asset inspection of `v0.0.8` via the GitHub API: 68 assets, correct extensions, no
  `.7z`; the remaining duplicate-archive shape (Linux `.zip`, macOS `.tar.gz`) documented and fixed
  in `v0.0.9`.
- Post-release asset inspection of `v0.0.9` via the GitHub API: 57 assets, exactly one standalone
  archive per platform/toolchain, no `.7z`.

### 13.7 Residual follow-ups (carried over from `BUGS.txt`)

1. **Windows MinGW CI** — investigate deterministic toolchain provisioning, ABI-stable cache
   namespaces, and whether the desired vcpkg packages are actually restored versus rebuilt.
2. **Windows LLVM CI** — investigate deterministic LLVM toolchain discovery, exact ABI
   compatibility, and package-level binary-cache reuse.
3. **Cache observability** — distinguish GitHub Actions archive hits, vcpkg binary-cache hits, and
   source rebuilds in logs; a successful Actions cache step is not proof that vcpkg skipped
   compilation.
4. **ARM64 Windows package smoke** — remains a separately documented known bug and is intentionally
   left unchanged.

Follow-up items are tracked as GitHub issues after the `v0.0.9` release.

### 13.8 Team / evidence note

Work was executed by the autonomous engineering agent (OpenCode) in an isolated session branch. A
second-brain peer review (GitHub Copilot CLI) was requested via the controller's peer-invitation
helper but the Copilot CLI was not available in that execution environment; this is recorded as a
quality-degradation event, not a blocker. In its place the change was subjected to the repo's own CI
gates (actionlint 1.7.12, PR packaging smoke, full build matrix), local script-syntax validation, an
executed simulation of the actual inventory/preflight logic, and an adversarial self-review of the
complete diff before publication.

---

## 14. Verification Ledger (evidence cited in this document)

| # | Claim | Evidence |
|---|---|---|
| E1 | Original history = 72 commits, 2023-06-02 → 2026-08-23 | `git log` on `MangaD/cpp-project-template` |
| E2 | Current history = 339 commits; merge `7e610ee` parents `86a1213`,`522bc3a` | `git log --first-parent`, `git cat-file -p` |
| E3 | NaylaCruz = 264 commits on `86a1213..522bc3a`, 63 files, +9.1k/−1.2k | `git rev-list --count`, `git diff --stat` |
| E4 | Original→current = 61 files, +8 966/−1 189; 42 added, 2 removed, 17 shared-modified | `git diff --stat / --name-status` |
| E5 | 11 workflows each carry Purpose/Trigger/References banner | full-text review of all `.github/workflows/*.yml` |
| E6 | Android fully removed; release inventory 85+2, SHA256SUMS 87 lines | `git grep -i android`, `actionlint 1.7.12` exit 0, inventory/preflight scripts on `96240c0` |
| E7 | `v0.0.4` = 88 assets, zero strays; `v0.0.2` = 96 (8 Android, 0 strays); NaylaCruz `v7.7.9` = 100 (4 strays) | GitHub API `releases/tags/{tag}` asset lists |
| E8 | Post-merge CI / Lint / Doxygen / vcpkg warmup green on `96240c0`; Release runs green for `v0.0.3`/`v0.0.4` | GitHub Actions run history (listed in §1–§5) |
| E9 | Original release `v0.0.1` = 20 assets, version `1.0.0.0` | GitHub API `MangaD/cpp-project-template/releases/tags/v0.0.1` |
| E10 | Source bug fixes present (factorial/wordWrap) and correct | diff `71cae18…96240c0` for the four source files |
| E11 | Manager abstraction, ADRs, merge notes (§ 12), CMakePresets content | full-text reads of those files at `96240c0`; the root `BUGS.txt` was later replaced by the session record consolidated into § 13 |
| E12 | CI transient earlier: one Windows CLANGARM64 MinGW Debug flake in msys2 `paccache` (rerun green) | run log from the pointing run; unrelated to the doc’s claims |
| E13 | § 11 Q&A (LLVM vs Clang; arch-naming review; multi-compiler benefits) reproduces the issue #130 answers verbatim | issue #130 comments `5798570508`, `5798660594`, `5798725416` on the controlling fork |
| E14 | § 12 Merge Notes reproduces the former `MERGE_NOTES.md`; § 13 reproduces the former `RELEASE_ARCHIVE_POLICY_SESSION.md` (incl. `BUGS.txt` residuals); both standalone files deleted | full-text reads at `eec83c9`; `git rm` record in the consolidation commit |
| E15 | `v0.0.8` = 68 assets, `v0.0.9` = 57 assets, exactly one standalone archive per platform/toolchain, no `.7z` | GitHub API `releases/tags/{v0.0.8,v0.0.9}` asset lists (2026-09-23) |
| E16 | Consolidation is docs-only: no workflow/CMake/source change, no `.7z`/`.zip`/`.tar.gz` references re-introduced | PR diff scope; `actionlint` gate green on the branch |

---

## 15. References

- Original repo: https://github.com/MangaD/cpp-project-template
- Intermediate fork: https://github.com/NaylaCruz/cpp-project-template
- Current fork: https://github.com/Jackie-SDX/cpp-project-template
- PR #5 (Android removal + workflow docs): https://github.com/Jackie-SDX/cpp-project-template/pull/5
- PR #6 (release-asset hygiene): https://github.com/Jackie-SDX/cpp-project-template/pull/6
- Releases: `v0.0.2` / `v0.0.3` / `v0.0.4` / `v0.0.5` (88 assets), `v0.0.8` (68 assets),
  `v0.0.9` (57 assets) on the current fork.
- Issue #130 ("UPDATE ON DISTANT REPO") on the controlling fork — origin of the archive-policy
  (PRs #8/#9) and the compiler & architecture Q&A recorded in § 11.
- In-repo records merged at `96240c0`: the merge notes (consolidated into § 12),
  `docs/architecture/decisions/001…005`, `TODO.md`, `README.md`. The root bug
  ledger (`BUGS.txt`) was retired and replaced by the release-archive-policy session record
  (consolidated into § 13) as part of the 2026-09 archive-format policy change.

---

## 16. CI cache and release publication repair (2026-09-25)

**Point in time:** `main` = `aa063e7` (2026-09-25);
tag `v0.0.10` = `aa063e7`;
release [`v0.0.10`](https://github.com/Jackie-SDX/cpp-project-template/releases/tag/v0.0.10)
published 2026-09-25T19:14:50Z with **61 assets**.
Tracked as issue #138 ("CPP distribution hardening benchmark — Core + Useful
implementation") on the controlling fork, `Jackie-SDX/Nayla-SD-JACKIE-Fun-WhatsApp-Bot`.

### 16.1 What was reported

Tag `v0.0.10` was pushed together with PR #11 (`3072b4d`, squash-merged 2026-09-25T16:39:36Z).
Four symptoms followed:

1. the `Release vcpkg cache warmup` workflow failed on `main`;
2. the `Release` workflow for `v0.0.10` failed;
3. no `windows-master-*` (release) cache had ever existed in the repository;
4. CI on `main` took 35 minutes, with the MinGW legs alone at 28–34 minutes.

### 16.2 Root causes and evidence

| # | Root cause | Evidence |
|---|---|---|
| A | `scripts/vcpkg_cache_gate.sh` rejected an empty `--hit` with a **usage error (exit 2)**. `actions/cache` documents exactly three `cache-hit` states — `true`, `false` and `''` — and `''` means "no cache found at all", so a never-seeded key died before the cold-start rules could run. | Release run [`36167681510`](https://github.com/Jackie-SDX/cpp-project-template/actions/runs/36167681510) (17:31:40→17:32:32, 52 s, **7 of 7** gate jobs failed): `--hit "" \` → `usage: vcpkg_cache_gate.sh --key K --hit true\|false …` → `##[error]Process completed with exit code 2.` |
| B | `vcpkg-cache-warmup.yml` counted restored entries with `find project/vcpkg_cache … \| wc -l`. On a cold start the directory does not exist, `find` exits 1, and the step ran under `bash … -e -o pipefail` — so the step aborted **before** `Save release vcpkg binary cache` could ever execute. | Warmup run [`36162164904`](https://github.com/Jackie-SDX/cpp-project-template/actions/runs/36162164904) (16:39:39→16:42:28, 2 m 49 s, **7 of 8** jobs failed): `Cache not found for input keys: windows-master-arm64-Release-…` immediately followed by `Run before="$(find project/vcpkg_cache …)"` → `Process completed with exit code 1`. The neighbouring `ci.yml` already guarded this with `mkdir -p project/vcpkg_cache`; the warmup did not. |
| C | The repository cache budget was **10.657 GB across 86 entries against GitHub's 10 GB per-repository limit**, so GitHub evicted least-recently-accessed entries. **40 of them (7.20 GB) were `refs/pull/11/merge` caches**, which are unreachable from `main` and from any future PR (a new PR gets a new merge ref). The release-family seeds were evicted with them. | `gh api --paginate "repos/Jackie-SDX/cpp-project-template/actions/caches?per_page=100"` → `7.20 GB n=40 refs/pull/11/merge`, `3.28 GB n=40 refs/heads/main`, `0.17 GB n=6 refs/heads/oc/remote-…`; **0** release-family keys on any ref. ADR 006 § 5 reserves deletion as an operator action — this was that action. |
| D | Slow CI was cold caches plus runner-image churn: the same run carried two image fingerprints (`316d8c5c` and `ccfd597b`) for `windows-latest`, splitting every image-scoped key in half. | CI run [`36162165228`](https://github.com/Jackie-SDX/cpp-project-template/actions/runs/36162165228) = 16:39:39→17:14:53 (**35 m 14 s**); per-job: MinGW x64 Debug 34.3 min, MinGW x64 Release 34.4 min, MinGW i686 Release 28.4 min. Cache keys observed on `main` for the same leg with `-316d8c5c-` and `-ccfd597b-`. |
| E | *(found only after A–D were fixed)* the shipped consumer verifier `verify_release.sh` compared a **NSIS installer's own PE header** with the contract architecture. NSIS always emits a 32-bit i386 stub regardless of payload. | Release run [`36175060932`](https://github.com/Jackie-SDX/cpp-project-template/actions/runs/36175060932) published 61 assets, then `[FAIL] arch … machine 0x014C != 0x8664 / != 0xAA64` on **6 of 9** NSIS installers → `verify-release: 1 check(s) FAILED`. |

### 16.3 Changes made

Two commits, pushed directly to `main` (the branch is unprotected — no rulesets, no branch
protection — and direct pushes were authorised for this task):

| Commit | Files | Change |
|---|---|---|
| `3eb6f13` | `scripts/vcpkg_cache_gate.sh`, `.github/workflows/release.yml`, `.github/workflows/vcpkg-cache-warmup.yml` | **A** — `--hit` now uses an `__unset__` sentinel so an *empty* value normalises to a miss while an *omitted* `--hit` is still a usage error; three new selftest cases. **B** — both `find` count sites treat an absent `project/vcpkg_cache` as zero entries. **coalesce** — `release.yml` passes `cache-hit \|\| 'false'` for both restore steps so the rendered command is explicit. |
| `aa063e7` | `scripts/verify_release.sh` | **E** — `*_nsis.exe` is now asserted against the i386 stub it always is (with the reason in-line); every other file keeps the contract expectation. Payload architecture is still covered: the sibling contract `.zip` row is checked by this script, and `scripts/validate_release_artifacts.sh` *unpacks* the installer during the tag run (17–22 payload PE members per installer). |

Nothing else was touched: no workflow semantics, no contract rows, no packaging behaviour.

### 16.4 Operator action: cache budget

The 40 orphaned `refs/pull/11/merge` caches were deleted through the Actions cache API
(`DELETE /repos/Jackie-SDX/cpp-project-template/actions/caches/{id}`), **40 succeeded, 0 failed**.

| | entries | size |
|---|---|---|
| before | 86 | **10.657 GB** (over the 10 GB limit → LRU eviction) |
| after deletion | 46 | 3.45 GB |
| after the seeds were written | 84 | 7.82 GB (2.18 GB headroom) |

### 16.5 Release re-cut procedure

`release.yml`'s publish job carries a **CORE-6 immutability guard**: it refuses to run if
`gh release view "$GITHUB_REF_NAME"` already succeeds. The tag therefore had to be re-cut.

1. The pre-existing `v0.0.10` release (created 16:39:35Z, **0 assets**, `main` = `3072b4d`) was
   deleted together with its tag, and `v0.0.10` was re-created at `3eb6f13` — without this the
   guard would have blocked publication of any assets at all.
2. That run published 61 assets but failed `verify-release.sh` (root cause E). The release that
   existed afterwards shipped the **buggy** `verify-release.sh`, so it could not stand as the
   deliverable: the release and tag were deleted a second time and `v0.0.10` re-created at
   `aa063e7`.

Both deletions were of releases that had to be replaced to reach the acceptance criteria; no
history was rewritten, nothing was force-pushed, and the release URL is unchanged.

### 16.6 Results

| Surface | Before | After |
|---|---|---|
| `Release vcpkg cache warmup` | [`36162164904`](https://github.com/Jackie-SDX/cpp-project-template/actions/runs/36162164904) **failure**, 7/8 jobs, 2 m 49 s | [`36170640084`](https://github.com/Jackie-SDX/cpp-project-template/actions/runs/36170640084) **success**, 8/8 jobs, 34 m 00 s (first real cold build) |
| release-family caches | **0** on any ref | **7** seeded on `refs/heads/main` (`windows-master-{x64,x86,arm64}`, `windows-llvm-master-{x64,x86}`, `windows-mingw-master-{x64,x86}`) + 7 `vcpkg-seed-*` records |
| `CI` on `main` | [`36162165228`](https://github.com/Jackie-SDX/cpp-project-template/actions/runs/36162165228) **35 m 14 s** | [`36177436812`](https://github.com/Jackie-SDX/cpp-project-template/actions/runs/36177436812) **10 m 57 s** (worst job 10.9 min; MinGW x64 Release 34.4 min → 4.1 min) |
| `Release` run 1 | [`36167681510`](https://github.com/Jackie-SDX/cpp-project-template/actions/runs/36167681510) **failure**, 52 s, 7 gate failures | — |
| `Release` run 2 | [`36175060932`](https://github.com/Jackie-SDX/cpp-project-template/actions/runs/36175060932) **failure**, 15 m 32 s, published assets then `verify-release` arch FAIL | — |
| `Release` run 3 | — | [`36177462008`](https://github.com/Jackie-SDX/cpp-project-template/actions/runs/36177462008) **success**, 16 m 43 s |
| check-runs at `aa063e7` | 7 failures | **52 success, 1 skipped (PR-only smoke), 0 failure** |

Cache visibility across refs was confirmed first-party: a run triggered on the tag restores from
its own ref scope and then falls back to the default branch ("*the `cache` action retries the same
steps on the default branch*"). The gate log for run `36177462008` shows the exact-hit chain:

```
Cache restored from key: vcpkg-seed-windows-master-x64-Release-…-36170640084-1   ← seeded on main
--hit "true" / --tool-hit "true"
```

so the tag run was warm, not merely permissive.

### 16.7 Validation performed

| Check | Command | Result |
|---|---|---|
| gate contract | `bash scripts/vcpkg_cache_gate.sh --selftest` | **18/18** (was 14/14; +3 for the empty-`--hit` states) |
| key contract | `bash scripts/vcpkg_cache_key.sh selftest` | **22/22** |
| shell lint | `shellcheck -S warning scripts/verify_release.sh scripts/vcpkg_cache_gate.sh scripts/vcpkg_cache_key.sh` | clean |
| workflow lint | `rhysd/actionlint:1.7.12 -color -shellcheck= -pyflakes=` | clean (0 lines) |
| YAML | `yaml.safe_load` over `.github/workflows/*.yml` | 11/11 parse |
| whitespace | `git diff --check` | clean |
| old-vs-new verifier against the **published** assets | `verify_release.sh --dir … --version 0.0.10 --partial --no-attest` | before → `arch FAIL`, `rc=1`; after → **all checks PASS, `rc=0`** |
| mutated non-i386 NSIS stub | same harness | still `FAIL` (detection retained) |
| mutated contract arch on a Windows `.zip` payload | same harness | still `FAIL` (detection retained) |
| end-to-end publish | run `36177462008` | `verify-release: all performed checks passed for version 0.0.10`; `arch … checked=184`; 49 attestations verified; 61/61 membership |

### 16.8 Residual risks and honest limits

- **Runner-image churn still splits keys.** `image_fp` is part of every key, so a mid-flight
  `ImageVersion` roll still forces a partial restore. Nothing was changed here: coarsening the
  fingerprint would weaken the ABI-safety guarantee of ADR 006.
- **`verify_release.sh` does not verify MSI or NSIS payload architecture itself.** An `.msi` starts
  with the OLE signature `D0CF11E0…`, so `pe_machine()` returns `None` and the row is counted as
  `checked` but never compared; NSIS payloads need `7z` to unpack, which a consumer machine may not
  have. Both are covered during the tag run by `scripts/validate_release_artifacts.sh`, which
  unpacks installers and fails closed without `7z`. Verified directly against
  `cpp-project-template_0.0.10_windows-msvc-x86_64_wix.msi` (`first 8 bytes: d0cf11e0a1b11ae1`).
- **The two release deletions in § 16.5 were necessary but not free.** Anything that referenced a
  published asset digest from the intermediate 16:39Z or 18:50Z publications is stale; the
  authoritative digests are those of the final `v0.0.10`.
- **Cache thrashing returns if the budget is exceeded again.** 7.82 GB of 10 GB is comfortable, but
  `refs/pull/*/merge` caches accumulate ~7 GB per merged PR and are never reclaimed automatically.
  Worth a scheduled cleanup or a size cap; not implemented here.
- **GitLab parity is untested** (unchanged by this work): the GitLab pipeline cannot be triggered
  from this repository (see § 10 and the P0-10 row of `docs/distribution-hardening-evidence.md`).
- The evidence-ledger rows in `docs/distribution-hardening-evidence.md` that were marked
  *"end-to-end proof needs a tag publish"* (P0-11, P0-15) are now satisfied by run `36177462008`;
  those rows were left unedited.

### 16.9 Evidence ledger

| Claim | Exact source | Observed | State |
|---|---|---|---|
| gate failed on empty `--hit` | run `36167681510`, job log line `--hit "" \` → `exit code 2` | 7/7 gate jobs failed | verified |
| warmup aborted before saving | run `36162164904`, job log `find … \| wc -l` → `exit code 1` | 7/8 jobs failed at ~35 s | verified |
| no release cache ever existed | `gh api …/actions/caches` | 0 `windows-master-*` entries | verified |
| budget exceeded | same | 10.657 GB / 86 entries vs 10 GB limit | verified |
| orphaned PR caches deleted | `DELETE …/actions/caches/{id}` × 40 | `deleted=40 failed=0` | verified |
| warmup fix works | run `36170640084`, `restored zip entries: 0 (exact hit: )` then `Cache saved with key: windows-master-x64-Release-…` | 8/8 success | verified |
| tag run sees main's caches | run `36177462008` gate log: `Cache restored from key: vcpkg-seed-…-36170640084-1`, `--hit "true"` | warm exact hit | verified |
| NSIS stub is i386 by design | `docs/AUDIT.md` *installer PE Machine 0x14c (Intel 386) — this describes the installer stub, not the bundled application payload*; `validate_release_artifacts.sh` 201 PASS / 0 FAIL | consistent | verified |
| shipped verifier now passes | publish log: `verify-release: all performed checks passed for version 0.0.10` | `rc=0` | verified |
| release complete | `gh release view v0.0.10` | 61 assets, `isDraft=false`, `publishedAt=2026-09-25T19:14:50Z` | verified |
| CI green at head | `gh api …/commits/aa063e7/check-runs` | 52 success, 1 skipped, 0 failure | verified |

---

*This document was generated from verified repository state; all hashes, counts, asset lists, and run
results were read directly from the three Git repositories and the GitHub API. Any later change to
`main` supersedes the exact figures above.*