# C++ Project Template — Fork Lineage, Engineering Decisions, and Future Work

**Project:** `cpp-project-template`
**Scope of this document:** a complete, evidence-based analysis of the repository's origins
(`MangaD/cpp-project-template`), its intermediate fork (`NaylaCruz/cpp-project-template`), and the
current fork (`Jackie-SDX/cpp-project-template`) — everything that was built, every decision taken,
the alternatives that were considered, and the work still worth doing.

**Point in time:** snapshot taken against `Jackie-SDX/cpp-project-template` at
`main` = `96240c0` (2026-09-21); `MangaD/cpp-project-template` at `71cae18` (2026-08-23);
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
released assets of all three repositories. Section 12 carries the verification ledger.

**At a glance:**

| Repository | Created | Commits | Files | GH workflows | GitLab CI size | Releases |
|---|---|---|---|---|---|---|
| `MangaD/cpp-project-template` (original) | 2023-06-02 | 72 | 82 | 4 | 129 lines | `v0.0.1` (20 assets) |
| `NaylaCruz/cpp-project-template` (intermediate) | 2026-08-29 | 335 | ~118 | ~12 | ~2 600 lines | `v0.0.4` … `v7.7.9` (up to 100 assets) |
| `Jackie-SDX/cpp-project-template` (current) | 2026-08-22 | 339 | 122 | 11 | 2 606 lines | `v0.0.2` (96), `v0.0.3` (88), `v0.0.4` (88) |

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
  `.tar.gz`/`.7z`/`.zip` everywhere.
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
  inventory job (expected vs actual, 85 packages), a global `SHA256SUMS`, and a single `publish` job
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
  (88 assets, post PR #5), `v0.0.4` (88 assets, post PR #6, flagged prerelease).

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
   files were also deleted from existing releases, and `MERGE_NOTES.md` was rewritten in neutral voice.
4. **`v0.0.3` / `v0.0.4` releases** with clean 88-asset inventories (85 packages + 2 source archives +
   `SHA256SUMS`).

---

## 6. Comparative Deep-Dive: Original vs Current

### 6.1 File inventory delta (original `71cae18` → current `96240c0`)

- Git equivalent: `61 files changed, +8 966 −1 189`.
- **Added (42 files):** `.circleci/config.yml`; nine workflows (`ci.yml`,
  `experimental-platform-matrix.yml`, `opencode.yml`, `release.yml`, `vcpkg-cache-warmup.yml`,
  `windows-arm64-package-smoke.yml`, `windows-package-smoke.yml`, `windows-test.yml`,
  `workflow-lint.yml`); the `.gitlab/vcpkg-triplets/` tree (18 CMake triplet files incl. the
  `x64-win-llvm` chainloaded toolchain); `BUGS.txt`, `MERGE_NOTES.md`, `cmake/PackageManager.cmake`,
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

---

## 7. Decisions Taken (with the alternatives considered)

### 7.1 D1 — Absorb the divergent GitHub/GitLab copies into one repo
**Decision:** consolidate both pipelines, triplets, scripts, and source fixes into one tree
(see `MERGE_NOTES.md`).
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
fragility — see the `canonical_package_name.txt` note in `MERGE_NOTES.md`, a candidate future change).
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
   └─► validate-release  : inventory must == 85 packages; SHA256SUMS written + verified; manifests rm -f
   └─► publish (tag only): re-verify, preflight (85 packages; SHA256SUMS 87 lines), softprops upload
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
8. **`BUGS.txt` is "obsolete / all fixed"** but still lists Windows MinGW/LLVM vcpkg cache
   observability and a separately-known ARM64 Windows package-smoke bug as follow-ups.
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
- **Investigate Windows MinGW/LLVM vcpkg cache behavior** (from `BUGS.txt`): distinguish Actions-cache
  hits, vcpkg binary-cache hits, and source rebuilds in logs.
- **Native ARM64 Windows package smoke** — promote once the known bug is fixed.
- **Migrate GitHub release name extraction** to the same `canonical_package_name.txt` written by
  `cpack_module.cmake` (noted in `MERGE_NOTES.md` as the fragile `sed` on `CPackConfig.cmake`).

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

## 11. Verification Ledger (evidence cited in this document)

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
| E11 | Manager abstraction, ADRs, MERGE_NOTES, BUGS.txt, CMakePresets content | full-text reads of those files at `96240c0` |
| E12 | CI transient earlier: one Windows CLANGARM64 MinGW Debug flake in msys2 `paccache` (rerun green) | run log from the pointing run; unrelated to the doc’s claims |

---

## 12. References

- Original repo: https://github.com/MangaD/cpp-project-template
- Intermediate fork: https://github.com/NaylaCruz/cpp-project-template
- Current fork: https://github.com/Jackie-SDX/cpp-project-template
- PR #5 (Android removal + workflow docs): https://github.com/Jackie-SDX/cpp-project-template/pull/5
- PR #6 (release-asset hygiene): https://github.com/Jackie-SDX/cpp-project-template/pull/6
- Releases: `v0.0.2` / `v0.0.3` / `v0.0.4` on the current fork.
- In-repo records merged at `96240c0`: `MERGE_NOTES.md`, `BUGS.txt`,
  `docs/architecture/decisions/001…005`, `TODO.md`, `README.md`.

---

*This document was generated from verified repository state; all hashes, counts, asset lists, and run
results were read directly from the three Git repositories and the GitHub API. Any later change to
`main` supersedes the exact figures above.*