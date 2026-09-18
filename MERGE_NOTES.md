# Merge notes: GitHub copy + GitLab copy → one repository

This documents exactly how `cpp-project-template-main` (GitHub) and `bs-main`
(GitLab) were merged, and why, so you can review the judgment calls instead of
just trusting them. Both source zips were inspected file-by-file; nothing was
merged by pattern-matching filenames alone.

## Short version

- **`.github/workflows/*` + `.github/scripts/*`** → GitHub copy, wholesale.
  `.gitlab-ci.yml` never calls these scripts, so GitLab's copies of them were
  dead/stale files, not an intentional GitLab-side change.
- **`.gitlab/.gitlab-ci.yml` + `.gitlab/vcpkg-triplets/*`** (except four files,
  see below) → GitLab copy, wholesale. It's the actively-used, far larger
  (124 KB vs 14 KB) pipeline; GitHub's copy of it was the stale template
  default.
- **`CMakePresets.json`, `CTestConfig.cmake`, `CITATION.cff`, `conanfile.txt`,
  `cmake/PackageManager.cmake`, `scripts/generate_coverage.sh`** → GitLab
  copy. Each has a dated comment explaining a real, specific bug it fixes
  (wrong CDash project, GitLab's coverage regex never matching, RPM license
  format, etc.) and none conflict with GitHub's side.
- **`tutorial_1.hpp`, `tutorial_1_gtest.cpp`, `UserOpt.cpp`, `utils.cpp`,
  `projectwx/src/CMakeLists.txt`** → GitHub copy. In every one of these, the
  GitHub version has a genuine fix the GitLab version lacks (overflow/negative
  checks in `factorial()`, a character-dropping bug in `wordWrap()`, ARM64
  Windows support). Confirmed by reading the actual logic, not just diffing.
- **Four files hand-merged, not picked wholesale**: root `CMakeLists.txt`,
  the four classic Windows vcpkg triplets, `src/projectlib/test/CMakeLists.txt`,
  `cmake/cpack_module.cmake`. Details below — this is where the real risk was.
- **`BUGS.txt`** (GitHub-only) and **`.circleci/`** (GitLab-only) both carried
  over as pure additions. Neither pipeline references the other's extra file,
  so there's nothing to reconcile — but you may not have realized a CircleCI
  config is riding along; delete `.circleci/` if you don't use it.

## The one decision worth reading closely: static vs. dynamic CRT on Windows

This is the "CMakeLists.txt is somehow different" problem you flagged, and it
runs deeper than that one file.

**What was found:** GitHub's `CMakeLists.txt` forces the MSVC runtime to
static (`CMAKE_MSVC_RUNTIME_LIBRARY`, justified in its own comment as
"consistent with the existing GitHub static-vcpkg toolchain"). GitLab's
`CMakeLists.txt` doesn't set it at all (CMake then defaults to dynamic). This
exact same static/dynamic split is mirrored in the four "classic" vcpkg
triplets that exist under both `.gitlab/vcpkg-triplets/` with the *same
filenames* but opposite `VCPKG_CRT_LINKAGE` — GitHub: static, GitLab: dynamic.
Mixing a statically-linked project with dynamically-linked vcpkg dependencies
(or vice versa) doesn't just warn, it fails to link.

**How it was resolved, not guessed:** GitHub's own `windows-test.yml` (a
workflow that only exists in the GitHub copy) turned out to already be a
cross-validation test for exactly this question — it clones the GitLab repo,
copies *GitHub's own* `.gitlab/vcpkg-triplets/` on top of it (overwriting
GitLab's), and builds+tests the result. That's GitHub's own CI asserting "my
triplet content is the one that should work against the full GitLab tree."
Combined with GitHub's `CMakeLists.txt` static-CRT comment pointing at the
same triplets, static CRT is the configuration that's actually being
validated, so the four classic triplet files keep GitHub's `static` value
(GitLab's extra comments on the two `-debug` variants, explaining a real
zlib/wxWidgets header-install ordering issue, were kept too — they're good
documentation independent of the CRT question).

**Why this isn't a blanket "GitHub wins" and what was actually changed:**
GitLab separately added real, working LLVM/Clang-CL cross-compilation support
(`x64-win-llvm`, `x86-win-llvm`, `Clang-CL-override.cmake`, etc. — all kept,
see below) that deliberately uses **dynamic** CRT, via its own chainloaded
toolchain file. If GitHub's static override had been kept as a plain
`set(CMAKE_MSVC_RUNTIME_LIBRARY ...)`, it would silently win over that
toolchain file for the rest of the configure run and break the LLVM path.
So the merged `CMakeLists.txt` sets `CMAKE_MSVC_RUNTIME_LIBRARY_DEFAULT`
instead of the variable directly — a *default* that the LLVM toolchain file's
own (later-executing) setting naturally overrides, rather than a value that
clobbers it. The same conflict existed one level down, in
`src/projectlib/test/CMakeLists.txt`, where the MSVC branch directly forces
the test target's runtime library; that branch is now skipped specifically
under clang-cl (`AND NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang"`) so it
doesn't override the LLVM path there either. Both fixes are explained
in comments at the point they're made.

**What to verify first:** I could not run an actual CMake configure in the
sandbox this was built in (no network, so no vcpkg/wxWidgets/gtest to fetch,
and no local `cmake` binary to even syntax-check against). Everything above
is based on reading the actual `.cmake` files, GitHub's own designed
cross-validation workflow, and CMake's documented (not just assumed) variable
scoping rules — but it has not been build-tested end to end. **The first
thing to watch after pushing this** is the "Windows LLVM x64" leg in
`ci.yml` and GitLab's own LLVM/Clang-CL jobs — if those two mechanisms
(`CMAKE_MSVC_RUNTIME_LIBRARY_DEFAULT` in the top-level file, and the
clang-cl-skip in the test CMakeLists) don't compose the way documented above,
that's where a link error would show up first, and it's an isolated,
easy-to-spot failure mode (a CRT-mismatch linker error), not a silent one.

## `cmake/cpack_module.cmake`

Neither side was a strict superset here, so this one was hand-merged too:

- Base: **GitHub's** version. It fixes a real bug GitLab's still has — a
  `CPACK_NSIS_DEFINES` block with quoted `VIAddVersionKey` arguments that
  GitHub's own comment explains produces malformed NSIS commands (confirmed
  against how CPack tokenizes that variable) — and uses safer
  `file(TO_CMAKE_PATH ...)` path handling instead of GitLab's raw backslash
  escapes.
- Added back from **GitLab**: the `canonical_package_name.txt` write. This
  isn't optional — `.gitlab-ci.yml`'s packaging jobs read that file back and
  hard-fail (`throw` / exit) if it's missing. It's a pure addition and
  doesn't affect GitHub's release process, which currently extracts the
  package name its own way (a `sed` pattern over `CPackConfig.cmake` in
  `release.yml`) — left untouched since it's not broken, though GitLab's own
  comment notes that approach is the fragile one they moved away from. Worth
  switching GitHub's `release.yml` to read the same file at some point, but
  that's a change to a workflow you said is fully working, so it wasn't made
  here without being asked.
- Also added back from GitLab: `CPACK_DMG_BACKGROUND_IMAGE` for the macOS
  installer (cosmetic, no downside).

## Everything carried over from GitLab as-is (no GitHub equivalent to compare against)

`x64-win-llvm.cmake`, `x64-win-llvm-release.cmake`, `x86-win-llvm.cmake`,
`Clang-CL-C.cmake`, `Clang-CL-CXX.cmake`, `Clang-CL-override.cmake`,
`Windows-MSVC.cmake`, `extra_setup.cmake`, `port_specialization.cmake`, and
the `x64-win-llvm/` subfolder. These are only referenced by `.gitlab-ci.yml`
(confirmed by grepping for each name) — GitHub's workflows get their LLVM
triplet from a separate external repo
(`Neumann-A/my-vcpkg-triplets`, checked out at a pinned commit in `ci.yml` /
`release.yml`), so there's no overlap to resolve.

## Not touched — pre-existing, not introduced by this merge

- Some files still say `MangaD` / `David Gonçalves` (the original template's
  upstream identity — e.g. `CITATION.cff`'s ORCID, a test file's `@author`
  doc-comment) while `CMakeLists.txt` uses `NaylaCruz`. That inconsistency
  already existed identically in both copies; it's a leftover-templating
  cleanup, not a merge conflict, so it was left alone.
- `src/projectwx/src/CMakeLists.txt` has one more `)` than `(` by a naive
  paren count — it's inside a commented-out line (`#MSVC_RUNTIME_LIBRARY
  ...DLL")`), present byte-for-byte in GitHub's original file. Not a real
  imbalance, just noting it was checked.

## What was actually validated in this sandbox (no network, no local `cmake`)

- Every `.yml`/`.json` CI/config file in the merged tree — `ci.yml`,
  `release.yml`, `clear_cache.yml`, `doxygen-gh-pages.yml`,
  `vcpkg-cache-warmup.yml`, both Windows smoke-test workflows,
  `windows-test.yml`, `.gitlab-ci.yml`, `.circleci/config.yml`,
  `CMakePresets.json` — parses cleanly (PyYAML / `json`).
- Every hand-written or hand-edited `.cmake`/`CMakeLists.txt` file has
  balanced parentheses and balanced `if/endif` blocks (regex-based check, not
  a real parser — CMake itself was not available to do a real `--fresh`
  configure).
- A full `diff -rq` of the merged tree against both originals was reviewed
  line-by-line; every difference traces back to one of the decisions above,
  nothing unaccounted for.
