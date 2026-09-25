# ADR 006: One vcpkg Binary-Cache Key Contract (families, seeds, gate)

## Status
Accepted

## Context

Before this decision every workflow invented its own vcpkg binary-cache key:

| Producer | Old key shape |
| --- | --- |
| `vcpkg-cache-warmup.yml` / `release.yml` (MSVC) | `windows-<arch>-<build>-<hashFiles>` |
| `release.yml` (MinGW/LLVM) | `windows[-llvm\|-mingw]-<ns>-<triplets>-<arch>-<build>-<hashFiles>` |
| `ci.yml` | `windows[-mingw\|-llvm]-<ns>-<arch>-<build>-<extra>-<hashFiles>` |
| `windows-package-smoke.yml` | `windows-a1cae005…-x64-mingw-dynamic-<build>-<hashFiles>` |
| `windows-arm64-package-smoke.yml` | `windows-arm64-<hashFiles>-<build>` |
| `experimental-platform-matrix.yml` | `vcpkg-experimental-<cache_id>-…-<hashFiles>` |

Consequences observed:

* `hashFiles()` runs on Windows with CRLF file endings, so the manifest segment
  differed between workflows and could not be reproduced outside a runner;
  the warmup seeds and the release jobs therefore disagreed on what "the same
  dependency set" meant.
* Each workflow restored only its own layout. A miss in one namespace could
  not fall back to a bag another workflow had already produced, so a cold
  release paid for builds the warmup had already performed.
* The release cache gate was conditioned on a stale repository name
  (`NaylaCruz/cpp-project-template`), i.e. a dead condition: cache-miss
  enforcement never actually ran.
* Nothing explained *why* a key changed, and nothing proved that a key that
  should have been seeded still existed.

## Decision

1. **`scripts/vcpkg_cache_key.sh` is the only authority for cache keys.**
   Workflows call it (`github-env`) instead of writing `${{ … }}` key
   expressions. One layout everywhere:

   ```
   key = <family_prefix>-<build_type>-<image_fp>-<vcpkg_fp>-<triplets_fp>-<extra_fp>-<manifest_hash>
   family_prefix = <family>[-<toolchain>]-<namespace>-<arch>
   ```

   | Segment | Value |
   | --- | --- |
   | `image_fp` | first 8 hex of `sha256($ImageVersion)` — runner image, i.e. OS, Visual Studio/MSYS2/CMake/Ninja versions |
   | `vcpkg_fp` | first 8 hex of `sha256($VCPKG_GIT_REF)` |
   | `triplets_fp` | first 8 hex of `sha256($MY_VCPKG_TRIPLETS_COMMIT)` |
   | `extra_fp` | CI MinGW/LLVM compiler fingerprint; `none` elsewhere |
   | `manifest_hash` | double SHA-256 of `vcpkg.json` after CRLF→LF folding, so the value equals GitHub's LF `hashFiles()` result and is reproducible off-runner |

   Family prefixes: `windows` (warmup + `release.yml`), `windows-ci`,
   `windows-smoke`, `windows-arm64-smoke`, `windows-exp`.
   The triplet is **not** a segment: within a family, `(toolchain, arch)`
   selects exactly one triplet (e.g. release MinGW x64 ⇒ `x64-mingw-dynamic`,
   experimental MSVC x64 ⇒ `x64-windows-static`). That invariant is what keeps
   one family one ABI.

2. **Families isolate producers.** Only warmup and `release.yml` write the
   release family; CI, the two packaging smokes and the experimental matrix
   each own their namespace, so a PR-labelled run can never write into a
   release bag. Restore-keys (in order): the new `<family_prefix>-<build_type>-`
   prefix — which also matches every pre-contract key that shared the prefix —
   then the family's legacy layouts, so bags written before this ADR are still
   found (e.g. the smoke falls back to the warmup MinGW seed and to its old
   private namespace; the experimental matrix falls back per matrix leg, never
   pool-wide).

3. **Warmup is the seeder and the verifier.** It always runs
   `vcpkg install` (even on an exact hit) so every seed is proven usable, warns
   when an exact hit produced no new archive (stale seed), and afterwards
   writes a file-based seed record `vcpkg-seed-<key>-<run_id>-<attempt>`
   containing `key`, `seeded_at`, `seeded_at_epoch`.

4. **`scripts/vcpkg_cache_gate.sh` enforces the contract in `release.yml`.**
   Exact hit ⇒ pass. No record (cold start, fork, first run after a key
   change) ⇒ pass with a notice: build slowly, let the producer save — a cache
   miss never fails fast. A fresh record (≤ 24 h) with an exact miss ⇒ the
   seed we know should exist is gone: block on the canonical repository for
   non-pull-request events, warn elsewhere. The vcpkg *tool* cache is reported
   only; it never blocks (a miss costs a bootstrap, not a rebuild).

5. **No automatic cache deletion.** There is deliberately no
   `gh cache delete` self-heal and no `actions: write` permission: deletion is
   an operator action. Staleness is detected and warned instead, and
   `image_fp` bounds the damage — a runner-image update re-keys every bag
   within days anyway.

6. **Downloads are shared, not duplicated.** `vcpkg-downloads-windows-<arch>-`
   with a `<arch>-` restore prefix: 2 entries replace the previous 8.

7. **Misses are self-explanatory.** `github-env` prints an
   `inputs: family=… image=… vcpkg-ref=… triplets-ref=… extra-fp=… manifest=…`
   line; diffing two runs shows exactly which segment moved.

## Consequences

* **Positive:** one deterministic layout per workflow; warm bags are actually
  reused across releases (prefix restore), seeds are verified rather than
  assumed, cold starts are legal but loudly noticed, and an upstream miss that
  a warmup seed should have covered blocks the release instead of silently
  shipping a 30-minute build.
* **Positive:** no workflow can poison another's cache family; a labelled PR
  smoke can only write `windows-smoke-*`.
* **Negative:** cache content is invalidated when the runner image, vcpkg
  revision, triplet revision or manifest changes — that is the point, but it
  means every such bump re-pays a cold release once.
* **Negative:** a seed record is only as trustworthy as warmup's last run; a
  manually deleted cache entry older than the record window passes with a
  notice instead of blocking (documented trade-off against fail-fast).
* **Rejected:** an `epoch` in the key (harder to reproduce off-runner),
  keying on compiler hashes for the release family (warmup and release must
  agree bit-for-bit; VS/MSYS2 versions already track `ImageVersion`), and
  automatic `gh cache delete` self-heal (irreversible, needs write permission,
  and races concurrent producers).
