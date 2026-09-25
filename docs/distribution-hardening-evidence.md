# Distribution Hardening — Evidence Ledger

Authoritative task: Jackie-SDX/Nayla-SD-JACKIE-Fun-WhatsApp-Bot issue #138
(CPP Project Template — Core + Useful Distribution Hardening Benchmark).

Target repository: `Jackie-SDX/cpp-project-template`, base `main`,
branch `oc/remote-Jackie-SDX-cpp-project-template-main-4de40d00448e`.

Method: every row records **finding → evidence → planned change → validation
command → expected result → actual result → remaining gap**. Rows are updated as
each PASS completes. Nothing is marked validated until a command, CI run, or
artifact inspection actually produced the recorded result.

---

## PASS 0 — Reconnaissance (baseline, before any edit)

| ID | Finding | Evidence | Planned change | Validation command | Expected | Actual | Gap |
|---|---|---|---|---|---|---|---|
| P0-1 | Target HEAD recorded | `git rev-parse HEAD` = `b40c7e900eac533bdf12f06985c4bd88710863d8`, branch `oc/remote-Jackie-SDX-cpp-project-template-main-4de40d00448e`, `gh api .../branches/main` → same SHA, `protected=false` | none (record) | `git rev-parse HEAD` | SHA recorded | `b40c7e9…` | none |
| P0-2 | Actions CI green on HEAD, CircleCI commit statuses red on same SHA | `gh api .../commits/b40c7e9…/check-runs` → 20/20 success; `gh api .../commits/b40c7e9…/status` → `state=failure`, 8 of 12 `ci/circleci:*` contexts `failure` | CORE-9 | re-check statuses after change | no new contradictory CircleCI status on the branch| .circleci/config.yml disabled with `workflows.pipeline.when: false` (config retained with re-enable instructions; CORE-9 stop obsolete reporting, no deletion) | post-push check: no `ci/circleci:*` status may appear on this branch/PR head |
| P0-3 | **Windows runtime DLL closure broken in published release** — 7/9 Windows legs ship `projectwx.exe` (or its payload) with required wx DLLs absent | v0.0.9 assets downloaded; PE import parse of every Windows `.zip`: `windows-mingw-{x86_64,i686}`, `windows-llvm-{x86_64,i686,arm64}`, `windows-msvc-arm64`, `windows-clangarm64-arm64` import e.g. `wxbase333u_gcc_x64_custom.dll` / `wxmsw333u_core_clang_custom.dll` / `libc++.dll` and ship **zero** DLLs; only `windows-msvc-{x86_64,i686}` are closed | CORE-1 | install-time closure deployment + verifier on final trees | every leg closed| defect re-proven: `cmake/windows/Resolve-WindowsRuntimeDeps.ps1` run against all 9 v0.0.9 Windows zips flags the 7 broken legs (missing wx DLLs and/or wrong-arch PEs); resolver + `-Deploy` install hook wired into `release.yml` package/expanded verify steps and both smoke workflows | every-leg closure proof requires the release-matrix dispatch / tag run |
| P0-4 | **Wrong-architecture artifact published**: `cpp-project-template_0.0.9_windows-mingw-i686.zip` contains `PE32+ x86-64` executables | `file i686/bin/*.exe` → `PE32+ executable (console) x86-64` on both exes | CORE-2/CORE-8 | PE machine assertion before packaging, per leg | i686 leg must contain `i686` binaries or fail| validator on v0.0.9 subset: `[FAIL] pe-arch windows-mingw-i686` (expected i686); per-leg `gcc -dumpmachine` assert added to release.yml mingw legs and the x64 smoke | assert must go green on real runners (dispatch pending) |
| P0-5 | Mixed-architecture payload on ARM64 legs: `windows-msvc-arm64.zip` / `windows-llvm-arm64.zip` contain `arm64` **and** `x86_64` machine-type files | PE machine scan of all payload members (v0.0.9) | CORE-1 (arch check in closure verifier) | verifier rejects machine mismatch | rejected| validator reproduces `[FAIL] pe-arch windows-llvm-arm64 … bin/vcruntime140_1.dll=x86_64`; resolver `-ExpectedArch arm64` rejects machine mismatch | runner run pending (release-matrix dispatch) |
| P0-6 | **DEB internal version `0.0.1` under a `0.0.9` filename** — GitHub release path resolves the version after configure/build | `dpkg-deb -I cpp-project-template_0.0.9_linux-gcc-x86_64.deb` → `Version: 0.0.1`; `.github/scripts/configure.cmake` receives no `CPP_PROJECT_TEMPLATE_VERSION` (only GitLab passes it, `.gitlab-ci.yml` lines 547/599/813/…) | CORE-10 | resolve tag version before configure on every path + identity assertion | package versions == tag version everywhere| local rebuild with `-D CPP_PROJECT_TEMPLATE_VERSION=0.0.9` → `dpkg-deb -I` `Version: 0.0.9` (also built 0.0.10 for the upgrade test); release.yml resolve step exports `CPP_PROJECT_TEMPLATE_VERSION` from the tag before Configure in both package jobs; validator still fails v0.0.9's `Version=0.0.1` (regression detector proven) | tag-run package inspection |
| P0-7 | Stale product identity in package metadata: `Maintainer: NaylaCruz` (no address), `Homepage: https://github.com/NaylaCruz/cpp-project-template`; `CMakeLists.txt:92,96,97` (`HOMEPAGE_URL`, `AUTHOR_NAME`, `ORGANIZATION`), `release.yml:176` cache gate conditioned on `github.repository == 'NaylaCruz/cpp-project-template'` | `dpkg-deb -I` output; `grep -rn NaylaCruz --include=*.cmake --include=CMakeLists.txt --include=*.yml` | CORE-10 | identity scan over packaging surfaces; regenerate DEB and inspect `control` | stale identity absent from generated package metadata| `verify_release_identity.sh` → all checks PASS (homepage, maintainer, stale-identity, overwrite, dev-fallback, arch-vocabulary); regenerated DEB: `Maintainer: Jackie <omonzejieelijah@gmail.com>`, `Homepage: https://github.com/Jackie-SDX/cpp-project-template` | none (validate-release uploads identity evidence on every run) |
| P0-8 | DEB runtime deps are hand-maintained and include a **development package fallback**: `Depends: …, libwxgtk3.2-1 \| libwxgtk3.2-dev` | `dpkg-deb -I`; `cmake/cpack_module.cmake:146,152`; `grep -r SHLIBDEPS` → 0 hits | CORE-3 | enable `CPACK_DEBIAN_PACKAGE_SHLIBDEPS`, install on clean Ubuntu container | runtime-only dependency closure resolved by `dpkg-shlibdeps`| `CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON` → local DEB `Depends: libc6 (>= 2.34), libgcc-s1 (>= 3.0), libstdc++6 (>= 13.1), libwxbase3.2-1t64 (>= 3.2.4+dfsg), libwxgtk3.2-1t64 (>= 3.2.4+dfsg)` — no `-dev` fallback; Ubuntu 24.04 container install auto-resolved and ran | GitLab arm64 package job (dpkg-dev + libwxgtk3.2-dev now installed) first real run |
| P0-9 | macOS GUI ships **without an application bundle**: released `macos-clang-arm64.zip` contains `bin/projectwx`, no `.app`, no `Info.plist` | `python3 -c zipfile` listing of v0.0.9 macOS zip; `src/projectwx/src/CMakeLists.txt` has no `MACOSX_BUNDLE` | CORE-4 | macOS runner asserts `.app`/`Info.plist`/arch/version | `.app` present and valid| MACOSX_BUNDLE + id `com.github.jackiesdx.cppprojecttemplate` implemented; `Verify macOS package payload` step (package + expanded) asserts .app/Contents/MacOS, Info.plist parse/id/version (checker unit-tested: accept, reject wrong version, reject foreign id), `lipo -archs`, otool developer-path scan, DMG mount, bounded 8 s GUI launch | requires the real macOS runner run (3 legs) — not yet executed |
| P0-10 | GitLab release has **no completeness floor** (only `count -eq 0` check) while GitHub requires all 54 | `.gitlab/.gitlab-ci.yml:2592-2597` vs `release.yml:716-772` | CORE-7 | `scripts/release_contract.sh check --scope gitlab-floor` on synthetic partial inventories | missing leg/format fails loudly with the missing item named| `create_release` runs `sh scripts/release_contract.sh check --scope gitlab-floor` + `check-forbidden` before `glab release create`; synthetic 15-file floor PASSes under dash/busybox-ash/bash (after fixing `set -o pipefail` portability); v0.0.9 subset FAILs naming every missing artifact; injected `…linux-gcc-x86_64.zip` FAILs as unexpected | GitLab cannot be triggered from here (no token; upstream project has only v0.0.1) — floor proven locally + by mutation only |
| P0-11 | GitHub publish uses `overwrite_files: true` (same-name asset replacement) | `.github/workflows/release.yml:894` | CORE-6 | publish with overwrite disabled + post-publication digest comparison | replacement refused; digests match| `overwrite_files` removed (identity overwrite check PASS); publish = refuse-existing-release (`gh release view` → fail) → freeze `pre-publish-digests.txt` → upload without overwrite → post-publish `sha256sum -c`, file-set diff, `gh attestation verify` loop, shipped `verify-release.sh` | end-to-end proof needs a tag publish |
| P0-12 | Expected inventory is hard-coded twice (validate + publish), diverging from CPack naming (`i686` in workflow vs `x86` from `cpack_module.cmake:40-43`), and GitLab publishes the CPack (`x86`) name while GitHub publishes `i686` | `release.yml:728-750,825-843`; `cmake/cpack_module.cmake:40-43`; GitLab `.package_windows_outputs` uses `canonical_package_name.txt` unmodified | CORE-5/CORE-8 | single contract file consumed by both pipelines; `release_contract.sh expected` matches published names | one vocabulary: `x86_64`/`i686`/`arm64`| one `packaging/release-contract.tsv` (61 rows) drives GH validate (56), GH publish (61), GitLab floor (15); local build output `cpp-project-template_0.0.9_linux-gcc-x86_64.{tar.gz,deb,rpm}` matches contract rows exactly | none |
| P0-13 | CI smoke artifact names use `x64` (`linux-gcc-x64.*`, `windows-mingw-x64.*`) while releases use `x86_64`/`i686` | `ci.yml:330-342`; `windows-package-smoke.yml:135-167` | CORE-8 | smoke files use canonical names | `x64` absent from artifact filenames| ci.yml smoke writes `linux-gcc-x86_64.*`; release.yml package-smoke job/artifact renamed `release-linux-gcc-x86_64-pr-smoke`; both Windows smokes name artifacts from the canonical CPack base incl. `_nsis`/`_wix` (hardcoded `windows-msvc-arm64.*` removed) | observe CI artifact names on first run |
| P0-14 | Archives are not deterministic: `tar -czf` without `--sort=name --mtime --owner/group`, `Compress-Archive`, `cmake -E tar`, `cpack -G ZIP` produce different bytes across providers | `release.yml:518,543,1331,1356`; `grep SOURCE_DATE_EPOCH` → 0 hits | USEFUL-1/2 | two independent local builds → identical `sha256` | byte-identical tarballs| deterministic builders wired into release.yml (all legs), ci.yml and GitLab (Windows zip + both Linux tars); measurements: tar.gz ×2 → `459dea97…` identical; cpack DEB ×2 with `SOURCE_DATE_EPOCH` → `240e97a5…` identical (without it: every run differs); RPM ×2 → `386ea41b…` identical; epoch now exported in GitLab Linux jobs, ci.yml smoke and release.yml package-smoke; remaining nondeterminism documented (DEFLATE varies across .NET majors; NSIS/WiX/DMG carry tool timestamps) | cross-.NET / cross-runner byte identity explicitly not claimed (documented limit) |
| P0-15 | No artifact attestations, SBOM, runtime-dependency reports, or consumer verification path | `grep -rn "attest\|sbom\|SPDX"` → 0 hits in workflows | USEFUL-6/7/8 | `gh attestation verify` after publish; reports uploaded | attestations verify against published assets| attestations (pinned SHAs), SPDX SBOM, PE/ELF/Mach-O runtime reports and shipped `verify-release.sh` wired; `verify_release.sh` on v0.0.9 subset FAILed correctly (arch defect); `runtime_deps_elf.sh` real run over local tar+deb+rpm → `total=20 bundled=0 system=16 missing=0 host-only=4` valid JSON (JSON-join bug found and fixed in both report scripts) | `gh attestation verify` + SBOM/digest binding against a real published release (tag run) |
| P0-16 | Audit snapshots reconciled: `OpenCode2.md` (83ed040) and `docs/AUDIT.md` (11d1726) agree on formats; live HEAD re-verified for every claim above rather than trusted | direct source + artifact inspection in this pass | — | — | — | audits treated as leads, all rows above re-proven from HEAD/live artifacts | none |

### Baseline release contract (live, `v0.0.9`)

- 57 assets = 54 platform packages (27 Windows, 15 Linux, 12 macOS) + 2 source archives + `SHA256SUMS`.
- Formats: Windows `zip` + `_nsis.exe` + `_wix.msi`; Linux `tar.gz` + `.deb` + `.rpm`; macOS `zip` + `.dmg`.
- Forbidden (must remain absent): `.7z`, Linux `zip`, macOS `tar.gz`, MSIX, AppImage, Flatpak, Snap.

### Deferred (per issue §7, must not block)

Authenticode signing/timestamping; Apple Developer ID + notarization/stapling; Linux
package signing keys; WiX major-version migration; new package formats; auto-update;
unrelated refactors; external publishing.

---

## PASS 1-3 — Implementation and local validation (2026-09-25)

Everything below was executed in this workspace; nothing is inferred.

### Deliverables (new files)

- `packaging/release-contract.tsv` — 61-row single source of truth (scopes:
  github-packages 56 / github-full 61 / gitlab-floor 15; counts printed by
  `sh scripts/release_contract.sh expected --version 0.0.9 --scope <s>`).
- `scripts/release_contract.sh` — expected/check/check-forbidden/list/json;
  runs under bash, dash and busybox ash (portable `pipefail` guard).
- `scripts/validate_release_artifacts.sh` — 11 check families, `--scope`,
  `--evidence` JSON.
- `scripts/verify_release_identity.sh` — identity/version/arch scans → PASS.
- `scripts/verify_release.sh` — standalone consumer verifier (ships as
  `verify-release.sh`).
- `scripts/runtime_deps_elf.sh`, `scripts/runtime_deps_macos.sh` — USEFUL-4.
- `scripts/make_deterministic_tarball.sh`, `scripts/make_deterministic_zip.ps1`
  — USEFUL-1/2 builders.
- `cmake/WindowsRuntimeDeps.cmake{,.in}`, `cmake/windows/Resolve-WindowsRuntimeDeps.ps1`
  — CORE-1 (verify mode in CI, `-Deploy` at install time).
- `docs/distribution-hardening-evidence.md` — this ledger.

### Validation results (commands → output)

- Identity: `bash scripts/verify_release_identity.sh` → `all checks passed`
  (homepage, maintainer-identity, stale-identity, overwrite, dev-fallback,
  arch-vocabulary).
- Contract floor mutations: 15-file synthetic dir → `GitLab completeness floor
  OK: 15 required artifact(s)` (exit 0) under `sh`/`bash`/`busybox sh`;
  v0.0.9 subset → 11 × `FLOOR MISSING: <file>` (exit 1); injected
  `cpp-project-template_0.0.9_linux-gcc-x86_64.zip` → `UNEXPECTED …` (exit 1);
  `prog.AppImage` → `forbidden format published` (case-insensitive; bug fixed).
- Validator vs v0.0.9 subset: FAILs recorded for inventory, `Version=0.0.1`
  (P0-6), `Maintainer=NaylaCruz` (P0-7), dev-fallback (P0-8),
  `windows-mingw-i686` arch (P0-4), `windows-llvm-arm64 vcruntime140_1.dll=x86_64`
  (P0-5) — each defect detected, each PASS line clean where the baseline was
  clean.
- Local Linux build: `cmake … -D PACKAGE_TOOLCHAIN=gcc` → CPack target
  `linux-gcc-x86_64`; build OK; `ctest` **8/8 passed**; install tree contains
  `bin/projectcli`, `bin/projectwx`.
- Package metadata: `dpkg-deb -I` → `Version: 0.0.9`,
  `Maintainer: Jackie <omonzejieelijah@gmail.com>`, homepage, shlibdeps-derived
  `Depends` (see P0-8); `rpm -qip` → `Version: 0.0.9`, `Vendor: Jackie-SDX`,
  wx auto-requires present; RPM `%description` bug (CMake generic template)
  fixed via `CPACK_RPM_PACKAGE_DESCRIPTION`.
- Lifecycle (USEFUL-5, containers):
  - Ubuntu 24.04: `apt-get install ./…0.0.9.deb` → CLI+GUI present, `Version:
    0.0.9` → upgrade `…0.0.10.deb` → `Version: 0.0.10` → `apt-get remove` →
    `/usr/bin/projectcli` and `/usr/bin/projectwx` gone. **OK**
  - Fedora 42: same sequence via `dnf install/upgrade/remove`. **OK**
  - Bounded GUI launch: `timeout 6 xvfb-run -a projectwx` → rc=124 (alive at
    6 s, killed). **OK**
- Runtime report (USEFUL-4): `runtime_deps_elf.sh` over real
  tar+deb+rpm → `total=20 bundled=0 system=16 missing=0 host-only=4`, exit 0,
  JSON parses (join bug fixed in ELF + macOS scripts).
- Determinism (USEFUL-1/2): tar.gz ×2 identical (`459dea97…`); DEB ×2
  identical with `SOURCE_DATE_EPOCH` (`240e97a5…`), different without; RPM ×2
  identical (`386ea41b…`); Windows zip builder proven byte-reproducible
  earlier in this session; epoch export added to GitLab Linux jobs, ci.yml
  smoke, release.yml package-smoke (main legs already had it via GITHUB_ENV).
- Workflows edited and YAML-validated: `.github/workflows/{release,ci,
  windows-package-smoke,windows-arm64-package-smoke}.yml`,
  `.gitlab/.gitlab-ci.yml`; `.circleci/config.yml` disabled (CORE-9);
  `bash -n` clean over every `scripts/*.sh`.

### Still runner/credential-dependent (cannot be claimed green yet)

- CORE-1 every-leg closure on real runners (release-matrix dispatch, tag).
- CORE-4 macOS assertions + USEFUL-5 macOS lifecycle → macOS runner legs.
- CORE-2 NSIS/MSI lifecycle + N-1 upgrade → windows-package-smoke run.
- CORE-9 branch status observation → after PR push.
- USEFUL-6 attestation/SBOM verification + USEFUL-8 published-verifier run →
  tag publish.
- GitLab floor live run (no token; documented limitation).
- USEFUL-9 docs sync (PROJECT_DOCUMENTATION.md, install.md) after CI is green.

