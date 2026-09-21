# Merge notes: GitHub copy + GitLab copy

Records how the GitHub (`cpp-project-template-main`) and GitLab (`bs-main`)
copies of the template were merged into this single repository, and the
reasoning behind each decision. This is reference material for reviewers;
it does not affect the build or releases.

## Summary of decisions

- **`.github/workflows/*` + `.github/scripts/*`** — taken from the GitHub copy,
  wholesale. `.gitlab-ci.yml` never calls these scripts, so the GitLab-side
  copies of them were dead/stale files rather than an intentional GitLab-only
  change.
- **`.gitlab/.gitlab-ci.yml` + `.gitlab/vcpkg-triplets/*`** (except the four
  files below) — taken from the GitLab copy, wholesale. That is the actively
  used, far larger (124 KB vs 14 KB) pipeline; the GitHub-side copy of it was
  the stale template default.
- **`CMakePresets.json`, `CTestConfig.cmake`, `CITATION.cff`, `conanfile.txt`,
  `cmake/PackageManager.cmake`, `scripts/generate_coverage.sh`** — taken from
  the GitLab copy. Each carries a dated comment describing a real, specific bug
  it fixes (wrong CDash project, a coverage regex that never matched, RPM
  license format, etc.) and none conflict with the GitHub side.
- **`tutorial_1.hpp`, `tutorial_1_gtest.cpp`, `UserOpt.cpp`, `utils.cpp`,
  `projectwx/src/CMakeLists.txt`** — taken from the GitHub copy. In every case
  the GitHub version contains a genuine fix the GitLab version lacks
  (overflow/negative checks in `factorial()`, a character-dropping bug in
  `wordWrap()`, ARM64 Windows support, verified by reading the logic).
- **Hand-merged files (not taken wholesale from either side)**:
  root `CMakeLists.txt`, the four classic Windows vcpkg triplets,
  `src/projectlib/test/CMakeLists.txt`, and `cmake/cpack_module.cmake`.
  Details in the sections below.
- **`BUGS.txt`** (GitHub-only) and **`.circleci/`** (GitLab-only) were carried
  over as pure additions; neither pipeline references the other's extra file.
  `.circleci/` is unused and can be removed if the project will not use
  CircleCI.

## Static vs. dynamic CRT on Windows

The root `CMakeLists.txt` is different between the two copies for a deeper
reason than one file:

- GitHub's `CMakeLists.txt` forces the MSVC runtime to static
  (`CMAKE_MSVC_RUNTIME_LIBRARY`), justified in its own comment as "consistent
  with the existing GitHub static-vcpkg toolchain". GitLab's does not set it
  (CMake defaults to dynamic). The same split is mirrored in the four
  "classic" vcpkg triplets that exist in both `.gitlab/vcpkg-triplets/` trees
  with the same filenames but opposite `VCPKG_CRT_LINKAGE` — GitHub: static,
  GitLab: dynamic. Mixing a statically-linked project with dynamically-linked
  vcpkg dependencies (or vice versa) fails at link time.
- Resolution: GitHub's own `windows-test.yml` (a workflow that only exists in
  the GitHub copy) cross-validates this exact question — it clones the GitLab
  repo, overlays GitHub's `.gitlab/vcpkg-triplets/` on top, and builds and
  tests the result. Combined with GitHub's static-CRT comment pointing at the
  same triplets, GitHub's `static` value is the configuration that is actually
  validated. Therefore the four classic triplet files keep GitHub's `static`
  value; GitLab's extra comments on the two `-debug` variants (a real
  zlib/wxWidgets header-install ordering issue) were kept as documentation.
- GitLab separately added real, working LLVM/Clang-CL cross-compilation
  support (`x64-win-llvm`, `x86-win-llvm`, `Clang-CL-override.cmake`, etc.)
  that deliberately uses **dynamic** CRT via its own chainloaded toolchain
  file. Had GitHub's static override been kept as a plain
  `set(CMAKE_MSVC_RUNTIME_LIBRARY ...)`, it would silently win over that
  toolchain file and break the LLVM path. The merged `CMakeLists.txt` therefore
  sets `CMAKE_MSVC_RUNTIME_LIBRARY_DEFAULT` instead — a default that the LLVM
  toolchain file's own (later-executing) setting can override.
- The same conflict existed one level down in
  `src/projectlib/test/CMakeLists.txt`, where the MSVC branch directly forces
  the test target's runtime library. That branch is now skipped under clang-cl
  (`AND NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang"`) so it cannot override the
  LLVM path there either. Both fixes are explained in comments at the point
  they are made.
- First place to watch after merging is the "Windows LLVM x64" leg in `ci.yml`
  and the GitLab LLVM/Clang-CL jobs: if
  `CMAKE_MSVC_RUNTIME_LIBRARY_DEFAULT` and the clang-cl skip do not compose as
  documented, a CRT-mismatch linker error appears there — an isolated,
  easy-to-spot failure mode.

## `cmake/cpack_module.cmake`

Neither side was a strict superset here, so it was hand-merged:

- Base: **GitHub's** version. It fixes a real bug still present in GitLab's — a
  `CPACK_NSIS_DEFINES` block with quoted `VIAddVersionKey` arguments that
  produces malformed NSIS commands — and uses safer `file(TO_CMAKE_PATH ...)`
  path handling instead of raw backslash escapes.
- Added back from **GitLab**: the `canonical_package_name.txt` write.
  `.gitlab-ci.yml`'s packaging jobs read that file back and hard-fail if it is
  missing. It is a pure addition and does not affect GitHub's release process,
  which extracts the package name its own way (a `sed` pattern over
  `CPackConfig.cmake` in `release.yml`). GitLab's own comment notes that sed
  approach is the fragile one; migrating `release.yml` to read the same file is
  a candidate future change but was deliberately not made unrequested.
- Also added back from **GitLab**: `CPACK_DMG_BACKGROUND_IMAGE` for the macOS
  installer (cosmetic).

## Carried over from GitLab as-is

`x64-win-llvm.cmake`, `x64-win-llvm-release.cmake`, `x86-win-llvm.cmake`,
`Clang-CL-C.cmake`, `Clang-CL-CXX.cmake`, `Clang-CL-override.cmake`,
`Windows-MSVC.cmake`, `extra_setup.cmake`, `port_specialization.cmake`, and the
`x64-win-llvm/` subfolder. These are referenced only by `.gitlab-ci.yml` —
GitHub's workflows get their LLVM triplet from a separate external repository
(`Neumann-A/my-vcpkg-triplets`, pinned in `ci.yml` / `release.yml`) — so there
is no overlap to resolve.

## Pre-existing items intentionally not changed

- Some files still say `MangaD` / `David Gonçalves` (the original template's
  upstream identity — e.g. `CITATION.cff`'s ORCID, a test file's `@author`
  doc-comment) while `CMakeLists.txt` uses `NaylaCruz`. This inconsistency
  pre-existed in both copies and is a leftover-templating cleanup, not a merge
  conflict.
- `src/projectwx/src/CMakeLists.txt` has one more `)` than `(` by a naive
  paren count; the imbalance is inside a commented-out line
  (`#MSVC_RUNTIME_LIBRARY ...DLL")`), present in GitHub's original file, and is
  not a real imbalance.