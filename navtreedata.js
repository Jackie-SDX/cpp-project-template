/*
 @licstart  The following is the entire license notice for the JavaScript code in this file.

 The MIT License (MIT)

 Copyright (C) 1997-2020 by Dimitri van Heesch

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 and associated documentation files (the "Software"), to deal in the Software without restriction,
 including without limitation the rights to use, copy, modify, merge, publish, distribute,
 sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or
 substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 @licend  The above is the entire license notice for the JavaScript code in this file
*/
var NAVTREE =
[
  [ "cpp-project-template", "index.html", [
    [ "C++ Project Template", "index.html", "index" ],
    [ "C++ Project Template — Engineering Documentation", "md_docs_2PROJECT__DOCUMENTATION.html", [
      [ "1. Executive Summary", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md2", null ],
      [ "2. Repository Lineage and Fork Graph", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md4", null ],
      [ "3. The Original Repo: <span class=\"tt\">MangaD/cpp-project-template</span>", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md6", [
        [ "3.1 Purpose", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md7", null ],
        [ "3.2 What it contained (82 files)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md8", null ],
        [ "3.3 Engineering characteristics of the original", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md9", null ],
        [ "3.4 Known limitations of the original", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md10", null ]
      ] ],
      [ "4. The Intermediate Fork: <span class=\"tt\">NaylaCruz/cpp-project-template</span>", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md12", [
        [ "4.1 What NaylaCruz's pass introduced (the durable core)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md13", null ],
        [ "4.2 Releases produced by this fork", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md14", null ],
        [ "4.3 Trade-offs visible from history", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md15", null ]
      ] ],
      [ "5. The Current Fork: <span class=\"tt\">Jackie-SDX/cpp-project-template</span>", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md17", [
        [ "5.1 State on <span class=\"tt\">main</span> (<span class=\"tt\">96240c0</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md18", null ],
        [ "5.2 Changes owned by the current fork (relative to NaylaCruz <span class=\"tt\">522bc3a</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md19", null ]
      ] ],
      [ "6. Comparative Deep-Dive: Original vs Current", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md21", [
        [ "6.1 File inventory delta (original <span class=\"tt\">71cae18</span> → current <span class=\"tt\">96240c0</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md22", null ],
        [ "6.2 Source-level changes worth calling out", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md23", null ],
        [ "6.3 Workflow inventory: original vs current", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md24", null ],
        [ "6.4 Release asset delta (MangaD <span class=\"tt\">v0.0.1</span> → current <span class=\"tt\">v0.0.4</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md25", null ],
        [ "6.5 Archive-format policy (decision record, 2026-09-23)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md26", null ]
      ] ],
      [ "7. Decisions Taken (with the alternatives considered)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md28", [
        [ "7.1 D1 — Absorb the divergent GitHub/GitLab copies into one repo", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md29", null ],
        [ "7.2 D2 — Strict separation of release workflows (<span class=\"tt\">ADR 005</span> + <span class=\"tt\">ci.yml</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md30", null ],
        [ "7.3 D3 — Release inventory manifests must never leak into uploads", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md31", null ],
        [ "7.4 D4 — Remove Android/NDK entirely", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md32", null ],
        [ "7.5 D5 — Deterministic cache keys (<span class=\"tt\">ADR 002</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md33", null ],
        [ "7.6 D6 — Pin third-party actions to commit SHAs (<span class=\"tt\">ADR 003</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md34", null ],
        [ "7.7 D7 — CMakePresets as the single source of build truth (<span class=\"tt\">ADR 001</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md35", null ],
        [ "7.8 D8 — Manual Coverity (<span class=\"tt\">ADR 004</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md36", null ],
        [ "7.9 D9 — Dual package manager, vcpkg default (<span class=\"tt\">PackageManager.cmake</span> + D9 rationale)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md37", null ],
        [ "7.10 D10 — Static vs dynamic CRT on Windows", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md38", null ],
        [ "7.11 D11 — Opt-in CDash instead of upstream submission", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md39", null ],
        [ "7.12 D12 — Single version resolution anchor", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md40", null ],
        [ "7.13 D13 — Windows ARM64 native installers", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md41", null ],
        [ "7.14 D14 — Experimental staging lane", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md42", null ],
        [ "7.15 D15 — OpenCode automations on the repo itself", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md43", null ]
      ] ],
      [ "8. How the Project Works Now (Operational View)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md45", [
        [ "8.1 Build system", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md46", null ],
        [ "8.2 GitHub Actions (11 workflows)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md47", null ],
        [ "8.3 Release flow (what happens on a <span class=\"tt\">v*</span> tag push)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md48", null ],
        [ "8.4 GitLab pipeline", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md49", null ]
      ] ],
      [ "9. Known Issues and Residuals (honest inventory)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md51", null ],
      [ "10. Future Work (candidates)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md53", null ],
      [ "11. Compiler &amp; Architecture Q&amp;A (2026-09-23)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md55", [
        [ "11.1 Q: What is the difference between \"CLANG\" and \"LLVM\" in the matrix?", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md56", null ],
        [ "11.2 Q: Are the architecture names the best? (i686, x86_64, arm64)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md57", null ],
        [ "11.3 Q: Are there benefits to compiling across all these compiler variants?", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md58", null ]
      ] ],
      [ "12. Merge Notes: GitHub Copy + GitLab Copy", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md60", [
        [ "12.1 Summary of decisions", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md61", null ],
        [ "12.2 Static vs. dynamic CRT on Windows", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md62", null ],
        [ "12.3 <span class=\"tt\">cmake/cpack_module.cmake</span>", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md63", null ],
        [ "12.4 Carried over from GitLab as-is", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md64", null ],
        [ "12.5 Pre-existing items intentionally not changed", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md65", null ]
      ] ],
      [ "13. Release Archive Policy — Session Record (2026-09-23)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md67", [
        [ "13.1 Objective", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md68", null ],
        [ "13.2 New policy (current, <span class=\"tt\">v0.0.9</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md69", null ],
        [ "13.3 Inventory math", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md70", null ],
        [ "13.4 Bugs and observations found during inspection", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md71", null ],
        [ "13.5 Files changed", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md72", null ],
        [ "13.6 Validation", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md73", null ],
        [ "13.7 Residual follow-ups (carried over from <span class=\"tt\">BUGS.txt</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md74", null ],
        [ "13.8 Team / evidence note", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md75", null ]
      ] ],
      [ "14. Verification Ledger (evidence cited in this document)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md77", null ],
      [ "15. References", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md79", null ],
      [ "16. CI cache and release publication repair (2026-09-25)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md81", [
        [ "16.1 What was reported", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md82", null ],
        [ "16.2 Root causes and evidence", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md83", null ],
        [ "16.3 Changes made", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md84", null ],
        [ "16.4 Operator action: cache budget", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md85", null ],
        [ "16.5 Release re-cut procedure", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md86", null ],
        [ "16.6 Results", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md87", null ],
        [ "16.7 Validation performed", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md88", null ],
        [ "16.8 Residual risks and honest limits", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md89", null ],
        [ "16.9 Evidence ledger", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md90", null ]
      ] ],
      [ "17. Complete dated A→Z record of the distribution-hardening benchmark (2026-09-24 → 2026-09-25)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md92", [
        [ "17.1 Authoritative task, inputs and operating rules", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md93", null ],
        [ "17.2 Dated timeline, A → Z", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md94", null ],
        [ "17.3 What was implemented, item by item", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md95", null ],
        [ "17.4 Bugs encountered and fixes applied", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md96", null ],
        [ "17.5 Decisions taken (and the alternatives rejected)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md97", null ],
        [ "17.6 Validation performed", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md98", null ],
        [ "17.7 Release evidence — <span class=\"tt\">v0.0.10</span>", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md99", null ],
        [ "17.8 Stale-branch cleanup (executed 2026-09-25)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md100", null ],
        [ "17.9 Deferred work, honest limits and closed follow-ups", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md101", null ],
        [ "17.10 Evidence ledger for this section", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md102", null ]
      ] ],
      [ "18. CPP Project Distribution Hardening — Completed (2026-09-25)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md105", null ],
      [ "19. Conan 2 binary cache reuse across refs — issue #152 (2026-09-27 → 2026-09-28)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md107", [
        [ "19.1 What was reported", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md108", null ],
        [ "19.2 Root causes, with measurements", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md109", null ],
        [ "19.3 The fix — three tiers, one home per key", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md110", null ],
        [ "19.4 Defects found during validation, and their fixes", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md111", null ],
        [ "19.5 Offline validation (every change, before pushing)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md112", null ],
        [ "19.6 Live validation evidence", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md113", null ],
        [ "19.7 Gate 2 pre-flight (vcpkg)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md114", null ],
        [ "19.8 An upstream flake, recorded because it cost two runs", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md115", null ],
        [ "19.9 Release gates", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md116", null ],
        [ "19.10 Residuals and follow-up", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md117", null ]
      ] ],
      [ "20. First-class Conan 2 + vcpkg dual backend — the complete record from the beginning (issue #152, 2026-09-26 → 2026-09-28)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md119", [
        [ "20.1 The contract that was accepted", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md120", null ],
        [ "20.2 Baseline, recorded before any edit (<span class=\"tt\">main</span> @ <span class=\"tt\">46815c1</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md121", null ],
        [ "20.3 What was built (29 commits, 68 files, +5 179 / −138)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md122", null ],
        [ "20.4 Manager selection — the exact user steps", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md123", null ],
        [ "20.5 Isolation guarantees (§6 of the issue, satisfied)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md124", null ],
        [ "20.6 Dependency and supply-chain position", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md125", null ],
        [ "20.7 Binary caching (both managers)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md126", null ],
        [ "20.8 CI changes", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md127", null ],
        [ "20.9 Bring-up: the failure loop, in order", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md128", null ],
        [ "20.10 Commit timeline (all 29 commits, oldest first)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md129", null ],
        [ "20.11 Validation performed", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md130", null ],
        [ "20.12 Release gates", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md131", null ],
        [ "20.13 Bugs, root causes and fixes (consolidated)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md132", null ],
        [ "20.14 Consolidation, cleanup and merge (2026-09-28)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md133", null ],
        [ "20.15 Evidence ledger", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md134", null ],
        [ "20.16 Residual limitations and open items", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md135", null ]
      ] ]
    ] ],
    [ "CPP Project Template — Distribution Hardening Task Plan", "md_docs_2TASKS.html", [
      [ "Definition of done", "md_docs_2TASKS.html#autotoc_md137", null ],
      [ "P0 — Release blockers", "md_docs_2TASKS.html#autotoc_md139", [
        [ "1. Single release identity and version contract", "md_docs_2TASKS.html#autotoc_md140", null ],
        [ "2. Correct product/repository identity", "md_docs_2TASKS.html#autotoc_md141", null ],
        [ "3. One release manifest for GitHub and GitLab", "md_docs_2TASKS.html#autotoc_md142", null ],
        [ "4. Release cache correctness", "md_docs_2TASKS.html#autotoc_md143", null ],
        [ "5. Immutable release publication", "md_docs_2TASKS.html#autotoc_md144", null ],
        [ "6. Release inventory gate", "md_docs_2TASKS.html#autotoc_md145", null ],
        [ "7. Release-critical CI failure semantics", "md_docs_2TASKS.html#autotoc_md146", null ]
      ] ],
      [ "P0 — Windows distribution", "md_docs_2TASKS.html#autotoc_md148", [
        [ "8. Authenticode and trust chain", "md_docs_2TASKS.html#autotoc_md149", null ],
        [ "9. Windows runtime and binary policy", "md_docs_2TASKS.html#autotoc_md150", null ],
        [ "10. NSIS lifecycle", "md_docs_2TASKS.html#autotoc_md151", null ],
        [ "11. WiX MSI lifecycle", "md_docs_2TASKS.html#autotoc_md152", null ]
      ] ],
      [ "P0 — macOS distribution", "md_docs_2TASKS.html#autotoc_md154", [
        [ "12. Real application bundle", "md_docs_2TASKS.html#autotoc_md155", null ],
        [ "13. macOS architecture and runtime closure", "md_docs_2TASKS.html#autotoc_md156", null ],
        [ "14. Developer ID, Hardened Runtime, notarization", "md_docs_2TASKS.html#autotoc_md157", null ],
        [ "15. macOS distribution lifecycle", "md_docs_2TASKS.html#autotoc_md158", null ]
      ] ],
      [ "P0 — Linux DEB/RPM/tar.gz distribution", "md_docs_2TASKS.html#autotoc_md160", [
        [ "16. Debian package correctness", "md_docs_2TASKS.html#autotoc_md161", null ],
        [ "17. RPM package correctness", "md_docs_2TASKS.html#autotoc_md162", null ],
        [ "18. Linux tarball correctness", "md_docs_2TASKS.html#autotoc_md163", null ]
      ] ],
      [ "P0 — Runtime compatibility and platform baselines", "md_docs_2TASKS.html#autotoc_md165", [
        [ "19. Runtime dependency closure", "md_docs_2TASKS.html#autotoc_md166", null ],
        [ "20. Binary-hardening checks", "md_docs_2TASKS.html#autotoc_md167", null ]
      ] ],
      [ "P1 — Artifact validation and QA", "md_docs_2TASKS.html#autotoc_md169", [
        [ "21. Artifact structural validation", "md_docs_2TASKS.html#autotoc_md170", null ],
        [ "22. Product-profile parity", "md_docs_2TASKS.html#autotoc_md171", null ],
        [ "23. Full release-matrix QA", "md_docs_2TASKS.html#autotoc_md172", null ]
      ] ],
      [ "P1 — Reproducible builds", "md_docs_2TASKS.html#autotoc_md174", [
        [ "24. Deterministic build inputs", "md_docs_2TASKS.html#autotoc_md175", null ],
        [ "25. Rebuild verification", "md_docs_2TASKS.html#autotoc_md176", null ]
      ] ],
      [ "P1 — SBOM, provenance, attestations, and supply-chain controls", "md_docs_2TASKS.html#autotoc_md178", [
        [ "26. Dependency and toolchain integrity", "md_docs_2TASKS.html#autotoc_md179", null ],
        [ "27. SBOM", "md_docs_2TASKS.html#autotoc_md180", null ],
        [ "28. Provenance and attestations", "md_docs_2TASKS.html#autotoc_md181", null ],
        [ "29. Signing-key management", "md_docs_2TASKS.html#autotoc_md182", null ]
      ] ],
      [ "P1 — CI/CD security and governance", "md_docs_2TASKS.html#autotoc_md184", [
        [ "30. GitHub Actions hardening", "md_docs_2TASKS.html#autotoc_md185", null ],
        [ "31. GitLab parity and security", "md_docs_2TASKS.html#autotoc_md186", null ],
        [ "32. Repository governance", "md_docs_2TASKS.html#autotoc_md187", null ]
      ] ],
      [ "P1 — Installer/package lifecycle and user experience", "md_docs_2TASKS.html#autotoc_md189", [
        [ "33. Cross-platform lifecycle matrix", "md_docs_2TASKS.html#autotoc_md190", null ],
        [ "34. Offline and restricted-network behavior", "md_docs_2TASKS.html#autotoc_md191", null ],
        [ "35. Installation hygiene", "md_docs_2TASKS.html#autotoc_md192", null ]
      ] ],
      [ "P1 — Documentation, legal, and support readiness", "md_docs_2TASKS.html#autotoc_md194", [
        [ "36. Distribution documentation", "md_docs_2TASKS.html#autotoc_md195", null ],
        [ "37. License and third-party compliance", "md_docs_2TASKS.html#autotoc_md196", null ],
        [ "38. Security/support policy", "md_docs_2TASKS.html#autotoc_md197", null ],
        [ "39. Release notes and migration", "md_docs_2TASKS.html#autotoc_md198", null ]
      ] ],
      [ "P2 — Operational maturity and long-term maintenance", "md_docs_2TASKS.html#autotoc_md200", [
        [ "40. Release evidence and audit trail", "md_docs_2TASKS.html#autotoc_md201", null ],
        [ "41. Regression and release drills", "md_docs_2TASKS.html#autotoc_md202", null ],
        [ "42. Update and distribution strategy", "md_docs_2TASKS.html#autotoc_md203", null ],
        [ "43. Continuous verification", "md_docs_2TASKS.html#autotoc_md204", null ]
      ] ],
      [ "P1 — Additional cross-cutting controls from the final omission pass", "md_docs_2TASKS.html#autotoc_md205", [
        [ "44. Build isolation and trust boundaries", "md_docs_2TASKS.html#autotoc_md206", null ],
        [ "45. Git/tag/reference integrity", "md_docs_2TASKS.html#autotoc_md207", null ],
        [ "46. Consumer verification toolkit", "md_docs_2TASKS.html#autotoc_md208", null ],
        [ "47. Security testing of the release path", "md_docs_2TASKS.html#autotoc_md209", null ],
        [ "48. Conditional localization/accessibility readiness", "md_docs_2TASKS.html#autotoc_md210", null ],
        [ "49. Security advisory and VEX handling", "md_docs_2TASKS.html#autotoc_md211", null ]
      ] ],
      [ "Release gate — final acceptance checklist", "md_docs_2TASKS.html#autotoc_md213", null ],
      [ "Explicitly out of scope unless separately justified", "md_docs_2TASKS.html#autotoc_md215", null ],
      [ "Research basis", "md_docs_2TASKS.html#autotoc_md217", [
        [ "Research limitations", "md_docs_2TASKS.html#autotoc_md218", null ]
      ] ]
    ] ],
    [ "Development Guide", "md_docs_2development__guide.html", [
      [ "Autoformatting", "md_docs_2development__guide.html#autotoc_md220", null ],
      [ "Static analysis", "md_docs_2development__guide.html#autotoc_md221", null ],
      [ "Testing", "md_docs_2development__guide.html#autotoc_md222", [
        [ "Coverage", "md_docs_2development__guide.html#autotoc_md223", [
          [ "GCC / Clang", "md_docs_2development__guide.html#autotoc_md224", null ],
          [ "MSVC", "md_docs_2development__guide.html#autotoc_md225", null ]
        ] ],
        [ "Dynamic analysis", "md_docs_2development__guide.html#autotoc_md226", [
          [ "Valgrind", "md_docs_2development__guide.html#autotoc_md227", null ],
          [ "Sanitizers", "md_docs_2development__guide.html#autotoc_md228", null ]
        ] ],
        [ "CDash", "md_docs_2development__guide.html#autotoc_md229", null ]
      ] ],
      [ "CMake tips", "md_docs_2development__guide.html#autotoc_md230", null ],
      [ "Doxygen tips", "md_docs_2development__guide.html#autotoc_md231", null ],
      [ "Adding libraries", "md_docs_2development__guide.html#autotoc_md232", null ],
      [ "Windows XP", "md_docs_2development__guide.html#autotoc_md233", null ],
      [ "GitHub Actions tips", "md_docs_2development__guide.html#autotoc_md234", [
        [ "Releases", "md_docs_2development__guide.html#autotoc_md235", null ]
      ] ],
      [ "GitLab tips", "md_docs_2development__guide.html#autotoc_md236", [
        [ "Custom Docker images", "md_docs_2development__guide.html#autotoc_md237", null ]
      ] ],
      [ "Tutorial links", "md_docs_2development__guide.html#autotoc_md238", [
        [ "C++", "md_docs_2development__guide.html#autotoc_md239", null ],
        [ "CMake", "md_docs_2development__guide.html#autotoc_md240", null ],
        [ "Testing", "md_docs_2development__guide.html#autotoc_md241", null ],
        [ "Coverage", "md_docs_2development__guide.html#autotoc_md242", null ],
        [ "Profiling", "md_docs_2development__guide.html#autotoc_md243", null ],
        [ "Debuging", "md_docs_2development__guide.html#autotoc_md244", null ],
        [ "Documentation", "md_docs_2development__guide.html#autotoc_md245", null ],
        [ "Versioning", "md_docs_2development__guide.html#autotoc_md246", null ],
        [ "Licenses", "md_docs_2development__guide.html#autotoc_md247", null ],
        [ "Signing", "md_docs_2development__guide.html#autotoc_md248", null ],
        [ "GitHub", "md_docs_2development__guide.html#autotoc_md249", null ],
        [ "GitLab", "md_docs_2development__guide.html#autotoc_md250", null ],
        [ "Docker", "md_docs_2development__guide.html#autotoc_md251", null ]
      ] ]
    ] ],
    [ "Distribution Hardening — Evidence Ledger", "md_docs_2distribution-hardening-evidence.html", [
      [ "PASS 0 — Reconnaissance (baseline, before any edit)", "md_docs_2distribution-hardening-evidence.html#autotoc_md254", [
        [ "Baseline release contract (live, <span class=\"tt\">v0.0.9</span>)", "md_docs_2distribution-hardening-evidence.html#autotoc_md255", null ],
        [ "Deferred (per issue §7, must not block)", "md_docs_2distribution-hardening-evidence.html#autotoc_md256", null ]
      ] ],
      [ "PASS 1-3 — Implementation and local validation (2026-09-25)", "md_docs_2distribution-hardening-evidence.html#autotoc_md258", [
        [ "Deliverables (new files)", "md_docs_2distribution-hardening-evidence.html#autotoc_md259", null ],
        [ "Validation results (commands → output)", "md_docs_2distribution-hardening-evidence.html#autotoc_md260", null ],
        [ "Still runner/credential-dependent (cannot be claimed green yet)", "md_docs_2distribution-hardening-evidence.html#autotoc_md261", null ]
      ] ],
      [ "PASS 4 — vcpkg binary-cache contract (ADR 006, 2026-09-25)", "md_docs_2distribution-hardening-evidence.html#autotoc_md263", [
        [ "Findings (re-proven from this HEAD before editing)", "md_docs_2distribution-hardening-evidence.html#autotoc_md264", null ],
        [ "Deliverables", "md_docs_2distribution-hardening-evidence.html#autotoc_md265", null ],
        [ "Validation (commands → actual result)", "md_docs_2distribution-hardening-evidence.html#autotoc_md266", null ],
        [ "Live acceptance evidence (target-repo dispatches, 2026-09-25)", "md_docs_2distribution-hardening-evidence.html#autotoc_md267", null ],
        [ "P4-6 (found in run 36126509057, fixed in <span class=\"tt\">1bab366</span>) — USEFUL-4 was host-dependent", "md_docs_2distribution-hardening-evidence.html#autotoc_md268", null ],
        [ "Remaining gaps", "md_docs_2distribution-hardening-evidence.html#autotoc_md269", null ]
      ] ]
    ] ],
    [ "Getting Started", "md_docs_2getting__started.html", null ],
    [ "Installation Guide", "md_docs_2install.html", [
      [ "Linux", "md_docs_2install.html#autotoc_md273", [
        [ "Arch Linux / Manjaro Linux", "md_docs_2install.html#autotoc_md274", null ],
        [ "Debian / Linux Mint / Ubuntu", "md_docs_2install.html#autotoc_md275", null ],
        [ "RedHat / Fedora / CentOS", "md_docs_2install.html#autotoc_md276", null ]
      ] ],
      [ "Windows", "md_docs_2install.html#autotoc_md277", [
        [ "MSVC", "md_docs_2install.html#autotoc_md278", null ],
        [ "MinGW", "md_docs_2install.html#autotoc_md279", null ],
        [ "Dependencies", "md_docs_2install.html#autotoc_md280", [
          [ "wxWidgets (manual install not recommended, prefer vcpkg)", "md_docs_2install.html#autotoc_md281", null ],
          [ "Google Test (manual install not recommended, prefer vcpkg)", "md_docs_2install.html#autotoc_md282", null ],
          [ "vcpkg (recommended)", "md_docs_2install.html#autotoc_md283", null ]
        ] ]
      ] ],
      [ "macOS", "md_docs_2install.html#autotoc_md284", null ],
      [ "Package manager selection (vcpkg / Conan 2)", "md_docs_2install.html#autotoc_md285", [
        [ "vcpkg", "md_docs_2install.html#autotoc_md286", null ],
        [ "Conan 2", "md_docs_2install.html#autotoc_md287", null ],
        [ "Choosing the manager in CI", "md_docs_2install.html#autotoc_md288", null ],
        [ "If configure fails", "md_docs_2install.html#autotoc_md289", null ],
        [ "What each CI mode actually provisions", "md_docs_2install.html#autotoc_md290", null ]
      ] ],
      [ "Compile", "md_docs_2install.html#autotoc_md291", [
        [ "Linux &amp; Mac", "md_docs_2install.html#autotoc_md292", null ],
        [ "Windows", "md_docs_2install.html#autotoc_md293", null ]
      ] ],
      [ "Package", "md_docs_2install.html#autotoc_md294", [
        [ "Archive", "md_docs_2install.html#autotoc_md295", null ],
        [ "Windows", "md_docs_2install.html#autotoc_md296", [
          [ "NSIS", "md_docs_2install.html#autotoc_md297", null ],
          [ "WiX", "md_docs_2install.html#autotoc_md298", null ]
        ] ],
        [ "Ubuntu", "md_docs_2install.html#autotoc_md299", [
          [ "DEB", "md_docs_2install.html#autotoc_md300", null ],
          [ "RPM", "md_docs_2install.html#autotoc_md301", null ]
        ] ],
        [ "MacOS", "md_docs_2install.html#autotoc_md302", [
          [ "DMG", "md_docs_2install.html#autotoc_md303", null ],
          [ "ProductBuild", "md_docs_2install.html#autotoc_md304", null ]
        ] ]
      ] ],
      [ "Documentation", "md_docs_2install.html#autotoc_md305", null ]
    ] ],
    [ "Namespaces", "namespaces.html", [
      [ "Namespace List", "namespaces.html", "namespaces_dup" ],
      [ "Namespace Members", "namespacemembers.html", [
        [ "All", "namespacemembers.html", null ],
        [ "Functions", "namespacemembers_func.html", null ],
        [ "Variables", "namespacemembers_vars.html", null ]
      ] ]
    ] ],
    [ "Classes", "annotated.html", [
      [ "Class List", "annotated.html", "annotated_dup" ],
      [ "Class Index", "classes.html", null ],
      [ "Class Hierarchy", "hierarchy.html", "hierarchy" ],
      [ "Class Members", "functions.html", [
        [ "All", "functions.html", null ],
        [ "Functions", "functions_func.html", null ],
        [ "Variables", "functions_vars.html", null ]
      ] ]
    ] ],
    [ "Files", "files.html", [
      [ "File List", "files.html", "files_dup" ],
      [ "File Members", "globals.html", [
        [ "All", "globals.html", null ],
        [ "Functions", "globals_func.html", null ],
        [ "Enumerator", "globals_eval.html", null ]
      ] ]
    ] ]
  ] ]
];

var NAVTREEINDEX =
[
"App_8cpp.html",
"md_docs_2TASKS.html#autotoc_md155"
];

var SYNCONMSG = 'click to disable panel synchronization';
var SYNCOFFMSG = 'click to enable panel synchronization';
var LISTOFALLMEMBERS = 'List of all members';