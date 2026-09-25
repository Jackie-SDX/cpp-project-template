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
    [ "Packaging / Installation / Release Architecture Forensic Audit", "md_docs_2AUDIT.html", [
      [ "1. Scope and hard-stop conditions", "md_docs_2AUDIT.html#autotoc_md1", null ],
      [ "2. Confidence", "md_docs_2AUDIT.html#autotoc_md2", null ],
      [ "3. Executive finding", "md_docs_2AUDIT.html#autotoc_md3", null ],
      [ "4. Repository inventory", "md_docs_2AUDIT.html#autotoc_md4", [
        [ "Build system", "md_docs_2AUDIT.html#autotoc_md5", null ],
        [ "Packaging resources", "md_docs_2AUDIT.html#autotoc_md6", null ],
        [ "Automation", "md_docs_2AUDIT.html#autotoc_md7", null ],
        [ "Installation/documentation", "md_docs_2AUDIT.html#autotoc_md8", null ],
        [ "Target/install definitions", "md_docs_2AUDIT.html#autotoc_md9", null ]
      ] ],
      [ "5. Current distribution inventory — v0.0.9", "md_docs_2AUDIT.html#autotoc_md10", [
        [ "Windows: 27 artifacts", "md_docs_2AUDIT.html#autotoc_md11", null ],
        [ "Linux: 15 artifacts", "md_docs_2AUDIT.html#autotoc_md12", null ],
        [ "macOS: 12 artifacts", "md_docs_2AUDIT.html#autotoc_md13", null ],
        [ "Source/integrity", "md_docs_2AUDIT.html#autotoc_md14", null ],
        [ "Windows .7z", "md_docs_2AUDIT.html#autotoc_md15", null ]
      ] ],
      [ "6. Current vs target matrix", "md_docs_2AUDIT.html#autotoc_md16", null ],
      [ "7. Windows assessment", "md_docs_2AUDIT.html#autotoc_md17", [
        [ "Windows ZIP — KEEP / HARDEN", "md_docs_2AUDIT.html#autotoc_md18", null ],
        [ "Windows NSIS — KEEP / HARDEN", "md_docs_2AUDIT.html#autotoc_md19", null ],
        [ "Windows WiX/MSI — KEEP / HARDEN", "md_docs_2AUDIT.html#autotoc_md20", null ],
        [ "Windows .7z — REMOVE FROM PUBLISHING / KEEP DISABLED HISTORICAL BLOCK ONLY", "md_docs_2AUDIT.html#autotoc_md21", null ]
      ] ],
      [ "8. macOS assessment", "md_docs_2AUDIT.html#autotoc_md22", [
        [ "macOS ZIP — KEEP / FIX", "md_docs_2AUDIT.html#autotoc_md23", null ],
        [ "macOS DMG — KEEP / FIX", "md_docs_2AUDIT.html#autotoc_md24", null ],
        [ "macOS .app bundle — FIX", "md_docs_2AUDIT.html#autotoc_md25", null ]
      ] ],
      [ "9. Linux assessment", "md_docs_2AUDIT.html#autotoc_md26", [
        [ "DEB — KEEP / FIX", "md_docs_2AUDIT.html#autotoc_md27", null ],
        [ "RPM — KEEP / FIX", "md_docs_2AUDIT.html#autotoc_md28", null ],
        [ "Linux tar.gz — KEEP / HARDEN", "md_docs_2AUDIT.html#autotoc_md29", null ]
      ] ],
      [ "10. Runtime dependency architecture", "md_docs_2AUDIT.html#autotoc_md30", null ],
      [ "11. Cross-platform matrix findings", "md_docs_2AUDIT.html#autotoc_md31", [
        [ "Strength", "md_docs_2AUDIT.html#autotoc_md32", null ],
        [ "Product-profile divergence", "md_docs_2AUDIT.html#autotoc_md33", null ],
        [ "Architecture verification is not uniform", "md_docs_2AUDIT.html#autotoc_md34", null ]
      ] ],
      [ "12. GitHub release pipeline", "md_docs_2AUDIT.html#autotoc_md35", [
        [ "Finding: manifest duplication", "md_docs_2AUDIT.html#autotoc_md36", null ],
        [ "Finding: release asset overwrite", "md_docs_2AUDIT.html#autotoc_md37", null ]
      ] ],
      [ "13. GitLab release pipeline", "md_docs_2AUDIT.html#autotoc_md38", [
        [ "Resulting risk", "md_docs_2AUDIT.html#autotoc_md39", null ],
        [ "Target architecture", "md_docs_2AUDIT.html#autotoc_md40", null ]
      ] ],
      [ "14. Supply-chain and security assessment", "md_docs_2AUDIT.html#autotoc_md41", [
        [ "Positive controls", "md_docs_2AUDIT.html#autotoc_md42", null ],
        [ "Authenticity gap", "md_docs_2AUDIT.html#autotoc_md43", null ],
        [ "Windows", "md_docs_2AUDIT.html#autotoc_md44", null ],
        [ "macOS", "md_docs_2AUDIT.html#autotoc_md45", null ],
        [ "Linux", "md_docs_2AUDIT.html#autotoc_md46", null ],
        [ "SBOM/provenance", "md_docs_2AUDIT.html#autotoc_md47", null ],
        [ "Recommended trust chain", "md_docs_2AUDIT.html#autotoc_md48", null ]
      ] ],
      [ "15. Reproducibility", "md_docs_2AUDIT.html#autotoc_md49", null ],
      [ "16. Documentation findings", "md_docs_2AUDIT.html#autotoc_md50", null ],
      [ "17. Format decisions", "md_docs_2AUDIT.html#autotoc_md51", null ],
      [ "18. Exact future changes proposed", "md_docs_2AUDIT.html#autotoc_md52", [
        [ ".github/workflows/release.yml", "md_docs_2AUDIT.html#autotoc_md53", null ],
        [ ".gitlab/.gitlab-ci.yml", "md_docs_2AUDIT.html#autotoc_md54", null ],
        [ "cmake/cpack_module.cmake", "md_docs_2AUDIT.html#autotoc_md55", null ],
        [ "src/projectwx/src/CMakeLists.txt", "md_docs_2AUDIT.html#autotoc_md56", null ],
        [ "CMakeLists.txt", "md_docs_2AUDIT.html#autotoc_md57", null ],
        [ ".github/workflows/windows-package-smoke.yml", "md_docs_2AUDIT.html#autotoc_md58", null ],
        [ ".github/workflows/windows-arm64-package-smoke.yml", "md_docs_2AUDIT.html#autotoc_md59", null ],
        [ "docs/install.md", "md_docs_2AUDIT.html#autotoc_md60", null ],
        [ "New release manifest/evidence contract", "md_docs_2AUDIT.html#autotoc_md61", null ]
      ] ],
      [ "19. Changes deliberately NOT advised", "md_docs_2AUDIT.html#autotoc_md62", null ],
      [ "20. Open risks", "md_docs_2AUDIT.html#autotoc_md63", null ],
      [ "21. Validation evidence", "md_docs_2AUDIT.html#autotoc_md64", [
        [ "Repository/static validation", "md_docs_2AUDIT.html#autotoc_md65", null ],
        [ "v0.0.9 GitHub validation", "md_docs_2AUDIT.html#autotoc_md66", null ],
        [ "Round 2 artifact-level validation", "md_docs_2AUDIT.html#autotoc_md67", [
          [ "Linux representative artifact", "md_docs_2AUDIT.html#autotoc_md68", null ],
          [ "Windows representative artifact", "md_docs_2AUDIT.html#autotoc_md69", null ],
          [ "macOS representative artifact", "md_docs_2AUDIT.html#autotoc_md70", null ],
          [ "What Round 2 still does not prove", "md_docs_2AUDIT.html#autotoc_md71", null ]
        ] ]
      ] ],
      [ "21A. Round 3 — complete tracked-snapshot verification", "md_docs_2AUDIT.html#autotoc_md72", [
        [ "Exact repository snapshot", "md_docs_2AUDIT.html#autotoc_md73", null ],
        [ "Round 3 source-level findings", "md_docs_2AUDIT.html#autotoc_md74", [
          [ "Critical: GitHub release version resolution occurs too late", "md_docs_2AUDIT.html#autotoc_md75", null ],
          [ "High: Windows release cache gate is keyed to the wrong repository identity", "md_docs_2AUDIT.html#autotoc_md76", null ],
          [ "Medium: stale release-workflow inventory comment", "md_docs_2AUDIT.html#autotoc_md77", null ],
          [ "Medium: package metadata identity is duplicated in source configuration", "md_docs_2AUDIT.html#autotoc_md78", null ],
          [ "Confirmed macOS architecture gap", "md_docs_2AUDIT.html#autotoc_md79", null ]
        ] ],
        [ "Round 3 unchanged conclusions", "md_docs_2AUDIT.html#autotoc_md80", null ]
      ] ],
      [ "22. Required future artifact validation", "md_docs_2AUDIT.html#autotoc_md81", [
        [ "Windows", "md_docs_2AUDIT.html#autotoc_md82", null ],
        [ "macOS", "md_docs_2AUDIT.html#autotoc_md83", null ],
        [ "Linux DEB", "md_docs_2AUDIT.html#autotoc_md84", null ],
        [ "Linux RPM", "md_docs_2AUDIT.html#autotoc_md85", null ],
        [ "Standalone archives", "md_docs_2AUDIT.html#autotoc_md86", null ]
      ] ],
      [ "23. Recommended release trust model", "md_docs_2AUDIT.html#autotoc_md87", null ],
      [ "24. Enterprise-readiness decision", "md_docs_2AUDIT.html#autotoc_md88", [
        [ "Current classification", "md_docs_2AUDIT.html#autotoc_md89", null ],
        [ "Target classification", "md_docs_2AUDIT.html#autotoc_md90", null ]
      ] ],
      [ "25. Evidence URLs", "md_docs_2AUDIT.html#autotoc_md91", [
        [ "Project", "md_docs_2AUDIT.html#autotoc_md92", null ],
        [ "Release evidence", "md_docs_2AUDIT.html#autotoc_md93", null ],
        [ "CMake / CPack", "md_docs_2AUDIT.html#autotoc_md94", null ],
        [ "Windows", "md_docs_2AUDIT.html#autotoc_md95", null ],
        [ "Apple", "md_docs_2AUDIT.html#autotoc_md96", null ],
        [ "Linux", "md_docs_2AUDIT.html#autotoc_md97", null ],
        [ "Provenance / reproducibility", "md_docs_2AUDIT.html#autotoc_md98", null ]
      ] ],
      [ "26. Final audit statement", "md_docs_2AUDIT.html#autotoc_md99", null ]
    ] ],
    [ "C++ Project Template — Engineering Documentation", "md_docs_2PROJECT__DOCUMENTATION.html", [
      [ "1. Executive Summary", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md102", null ],
      [ "2. Repository Lineage and Fork Graph", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md104", null ],
      [ "3. The Original Repo: <span class=\"tt\">MangaD/cpp-project-template</span>", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md106", [
        [ "3.1 Purpose", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md107", null ],
        [ "3.2 What it contained (82 files)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md108", null ],
        [ "3.3 Engineering characteristics of the original", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md109", null ],
        [ "3.4 Known limitations of the original", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md110", null ]
      ] ],
      [ "4. The Intermediate Fork: <span class=\"tt\">NaylaCruz/cpp-project-template</span>", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md112", [
        [ "4.1 What NaylaCruz's pass introduced (the durable core)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md113", null ],
        [ "4.2 Releases produced by this fork", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md114", null ],
        [ "4.3 Trade-offs visible from history", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md115", null ]
      ] ],
      [ "5. The Current Fork: <span class=\"tt\">Jackie-SDX/cpp-project-template</span>", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md117", [
        [ "5.1 State on <span class=\"tt\">main</span> (<span class=\"tt\">96240c0</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md118", null ],
        [ "5.2 Changes owned by the current fork (relative to NaylaCruz <span class=\"tt\">522bc3a</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md119", null ]
      ] ],
      [ "6. Comparative Deep-Dive: Original vs Current", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md121", [
        [ "6.1 File inventory delta (original <span class=\"tt\">71cae18</span> → current <span class=\"tt\">96240c0</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md122", null ],
        [ "6.2 Source-level changes worth calling out", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md123", null ],
        [ "6.3 Workflow inventory: original vs current", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md124", null ],
        [ "6.4 Release asset delta (MangaD <span class=\"tt\">v0.0.1</span> → current <span class=\"tt\">v0.0.4</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md125", null ],
        [ "6.5 Archive-format policy (decision record, 2026-09-23)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md126", null ]
      ] ],
      [ "7. Decisions Taken (with the alternatives considered)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md128", [
        [ "7.1 D1 — Absorb the divergent GitHub/GitLab copies into one repo", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md129", null ],
        [ "7.2 D2 — Strict separation of release workflows (<span class=\"tt\">ADR 005</span> + <span class=\"tt\">ci.yml</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md130", null ],
        [ "7.3 D3 — Release inventory manifests must never leak into uploads", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md131", null ],
        [ "7.4 D4 — Remove Android/NDK entirely", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md132", null ],
        [ "7.5 D5 — Deterministic cache keys (<span class=\"tt\">ADR 002</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md133", null ],
        [ "7.6 D6 — Pin third-party actions to commit SHAs (<span class=\"tt\">ADR 003</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md134", null ],
        [ "7.7 D7 — CMakePresets as the single source of build truth (<span class=\"tt\">ADR 001</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md135", null ],
        [ "7.8 D8 — Manual Coverity (<span class=\"tt\">ADR 004</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md136", null ],
        [ "7.9 D9 — Dual package manager, vcpkg default (<span class=\"tt\">PackageManager.cmake</span> + D9 rationale)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md137", null ],
        [ "7.10 D10 — Static vs dynamic CRT on Windows", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md138", null ],
        [ "7.11 D11 — Opt-in CDash instead of upstream submission", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md139", null ],
        [ "7.12 D12 — Single version resolution anchor", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md140", null ],
        [ "7.13 D13 — Windows ARM64 native installers", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md141", null ],
        [ "7.14 D14 — Experimental staging lane", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md142", null ],
        [ "7.15 D15 — OpenCode automations on the repo itself", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md143", null ]
      ] ],
      [ "8. How the Project Works Now (Operational View)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md145", [
        [ "8.1 Build system", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md146", null ],
        [ "8.2 GitHub Actions (11 workflows)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md147", null ],
        [ "8.3 Release flow (what happens on a <span class=\"tt\">v*</span> tag push)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md148", null ],
        [ "8.4 GitLab pipeline", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md149", null ]
      ] ],
      [ "9. Known Issues and Residuals (honest inventory)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md151", null ],
      [ "10. Future Work (candidates)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md153", null ],
      [ "11. Compiler &amp; Architecture Q&amp;A (2026-09-23)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md155", [
        [ "11.1 Q: What is the difference between \"CLANG\" and \"LLVM\" in the matrix?", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md156", null ],
        [ "11.2 Q: Are the architecture names the best? (i686, x86_64, arm64)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md157", null ],
        [ "11.3 Q: Are there benefits to compiling across all these compiler variants?", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md158", null ]
      ] ],
      [ "12. Merge Notes: GitHub Copy + GitLab Copy", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md160", [
        [ "12.1 Summary of decisions", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md161", null ],
        [ "12.2 Static vs. dynamic CRT on Windows", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md162", null ],
        [ "12.3 <span class=\"tt\">cmake/cpack_module.cmake</span>", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md163", null ],
        [ "12.4 Carried over from GitLab as-is", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md164", null ],
        [ "12.5 Pre-existing items intentionally not changed", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md165", null ]
      ] ],
      [ "13. Release Archive Policy — Session Record (2026-09-23)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md167", [
        [ "13.1 Objective", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md168", null ],
        [ "13.2 New policy (current, <span class=\"tt\">v0.0.9</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md169", null ],
        [ "13.3 Inventory math", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md170", null ],
        [ "13.4 Bugs and observations found during inspection", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md171", null ],
        [ "13.5 Files changed", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md172", null ],
        [ "13.6 Validation", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md173", null ],
        [ "13.7 Residual follow-ups (carried over from <span class=\"tt\">BUGS.txt</span>)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md174", null ],
        [ "13.8 Team / evidence note", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md175", null ]
      ] ],
      [ "14. Verification Ledger (evidence cited in this document)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md177", null ],
      [ "15. References", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md179", null ],
      [ "16. CI cache and release publication repair (2026-09-25)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md181", [
        [ "16.1 What was reported", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md182", null ],
        [ "16.2 Root causes and evidence", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md183", null ],
        [ "16.3 Changes made", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md184", null ],
        [ "16.4 Operator action: cache budget", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md185", null ],
        [ "16.5 Release re-cut procedure", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md186", null ],
        [ "16.6 Results", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md187", null ],
        [ "16.7 Validation performed", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md188", null ],
        [ "16.8 Residual risks and honest limits", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md189", null ],
        [ "16.9 Evidence ledger", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md190", null ]
      ] ],
      [ "17. Complete dated A→Z record of the distribution-hardening benchmark (2026-09-24 → 2026-09-25)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md192", [
        [ "17.1 Authoritative task, inputs and operating rules", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md193", null ],
        [ "17.2 Dated timeline, A → Z", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md194", null ],
        [ "17.3 What was implemented, item by item", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md195", null ],
        [ "17.4 Bugs encountered and fixes applied", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md196", null ],
        [ "17.5 Decisions taken (and the alternatives rejected)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md197", null ],
        [ "17.6 Validation performed", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md198", null ],
        [ "17.7 Release evidence — <span class=\"tt\">v0.0.10</span>", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md199", null ],
        [ "17.8 Stale-branch cleanup (executed 2026-09-25)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md200", null ],
        [ "17.9 Deferred work, honest limits and closed follow-ups", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md201", null ],
        [ "17.10 Evidence ledger for this section", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md202", null ]
      ] ],
      [ "18. CPP Project Distribution Hardening — Completed (2026-09-25)", "md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md205", null ]
    ] ],
    [ "CPP Project Template — Distribution Hardening Task Plan", "md_docs_2TASKS.html", [
      [ "Definition of done", "md_docs_2TASKS.html#autotoc_md207", null ],
      [ "P0 — Release blockers", "md_docs_2TASKS.html#autotoc_md209", [
        [ "1. Single release identity and version contract", "md_docs_2TASKS.html#autotoc_md210", null ],
        [ "2. Correct product/repository identity", "md_docs_2TASKS.html#autotoc_md211", null ],
        [ "3. One release manifest for GitHub and GitLab", "md_docs_2TASKS.html#autotoc_md212", null ],
        [ "4. Release cache correctness", "md_docs_2TASKS.html#autotoc_md213", null ],
        [ "5. Immutable release publication", "md_docs_2TASKS.html#autotoc_md214", null ],
        [ "6. Release inventory gate", "md_docs_2TASKS.html#autotoc_md215", null ],
        [ "7. Release-critical CI failure semantics", "md_docs_2TASKS.html#autotoc_md216", null ]
      ] ],
      [ "P0 — Windows distribution", "md_docs_2TASKS.html#autotoc_md218", [
        [ "8. Authenticode and trust chain", "md_docs_2TASKS.html#autotoc_md219", null ],
        [ "9. Windows runtime and binary policy", "md_docs_2TASKS.html#autotoc_md220", null ],
        [ "10. NSIS lifecycle", "md_docs_2TASKS.html#autotoc_md221", null ],
        [ "11. WiX MSI lifecycle", "md_docs_2TASKS.html#autotoc_md222", null ]
      ] ],
      [ "P0 — macOS distribution", "md_docs_2TASKS.html#autotoc_md224", [
        [ "12. Real application bundle", "md_docs_2TASKS.html#autotoc_md225", null ],
        [ "13. macOS architecture and runtime closure", "md_docs_2TASKS.html#autotoc_md226", null ],
        [ "14. Developer ID, Hardened Runtime, notarization", "md_docs_2TASKS.html#autotoc_md227", null ],
        [ "15. macOS distribution lifecycle", "md_docs_2TASKS.html#autotoc_md228", null ]
      ] ],
      [ "P0 — Linux DEB/RPM/tar.gz distribution", "md_docs_2TASKS.html#autotoc_md230", [
        [ "16. Debian package correctness", "md_docs_2TASKS.html#autotoc_md231", null ],
        [ "17. RPM package correctness", "md_docs_2TASKS.html#autotoc_md232", null ],
        [ "18. Linux tarball correctness", "md_docs_2TASKS.html#autotoc_md233", null ]
      ] ],
      [ "P0 — Runtime compatibility and platform baselines", "md_docs_2TASKS.html#autotoc_md235", [
        [ "19. Runtime dependency closure", "md_docs_2TASKS.html#autotoc_md236", null ],
        [ "20. Binary-hardening checks", "md_docs_2TASKS.html#autotoc_md237", null ]
      ] ],
      [ "P1 — Artifact validation and QA", "md_docs_2TASKS.html#autotoc_md239", [
        [ "21. Artifact structural validation", "md_docs_2TASKS.html#autotoc_md240", null ],
        [ "22. Product-profile parity", "md_docs_2TASKS.html#autotoc_md241", null ],
        [ "23. Full release-matrix QA", "md_docs_2TASKS.html#autotoc_md242", null ]
      ] ],
      [ "P1 — Reproducible builds", "md_docs_2TASKS.html#autotoc_md244", [
        [ "24. Deterministic build inputs", "md_docs_2TASKS.html#autotoc_md245", null ],
        [ "25. Rebuild verification", "md_docs_2TASKS.html#autotoc_md246", null ]
      ] ],
      [ "P1 — SBOM, provenance, attestations, and supply-chain controls", "md_docs_2TASKS.html#autotoc_md248", [
        [ "26. Dependency and toolchain integrity", "md_docs_2TASKS.html#autotoc_md249", null ],
        [ "27. SBOM", "md_docs_2TASKS.html#autotoc_md250", null ],
        [ "28. Provenance and attestations", "md_docs_2TASKS.html#autotoc_md251", null ],
        [ "29. Signing-key management", "md_docs_2TASKS.html#autotoc_md252", null ]
      ] ],
      [ "P1 — CI/CD security and governance", "md_docs_2TASKS.html#autotoc_md254", [
        [ "30. GitHub Actions hardening", "md_docs_2TASKS.html#autotoc_md255", null ],
        [ "31. GitLab parity and security", "md_docs_2TASKS.html#autotoc_md256", null ],
        [ "32. Repository governance", "md_docs_2TASKS.html#autotoc_md257", null ]
      ] ],
      [ "P1 — Installer/package lifecycle and user experience", "md_docs_2TASKS.html#autotoc_md259", [
        [ "33. Cross-platform lifecycle matrix", "md_docs_2TASKS.html#autotoc_md260", null ],
        [ "34. Offline and restricted-network behavior", "md_docs_2TASKS.html#autotoc_md261", null ],
        [ "35. Installation hygiene", "md_docs_2TASKS.html#autotoc_md262", null ]
      ] ],
      [ "P1 — Documentation, legal, and support readiness", "md_docs_2TASKS.html#autotoc_md264", [
        [ "36. Distribution documentation", "md_docs_2TASKS.html#autotoc_md265", null ],
        [ "37. License and third-party compliance", "md_docs_2TASKS.html#autotoc_md266", null ],
        [ "38. Security/support policy", "md_docs_2TASKS.html#autotoc_md267", null ],
        [ "39. Release notes and migration", "md_docs_2TASKS.html#autotoc_md268", null ]
      ] ],
      [ "P2 — Operational maturity and long-term maintenance", "md_docs_2TASKS.html#autotoc_md270", [
        [ "40. Release evidence and audit trail", "md_docs_2TASKS.html#autotoc_md271", null ],
        [ "41. Regression and release drills", "md_docs_2TASKS.html#autotoc_md272", null ],
        [ "42. Update and distribution strategy", "md_docs_2TASKS.html#autotoc_md273", null ],
        [ "43. Continuous verification", "md_docs_2TASKS.html#autotoc_md274", null ]
      ] ],
      [ "P1 — Additional cross-cutting controls from the final omission pass", "md_docs_2TASKS.html#autotoc_md275", [
        [ "44. Build isolation and trust boundaries", "md_docs_2TASKS.html#autotoc_md276", null ],
        [ "45. Git/tag/reference integrity", "md_docs_2TASKS.html#autotoc_md277", null ],
        [ "46. Consumer verification toolkit", "md_docs_2TASKS.html#autotoc_md278", null ],
        [ "47. Security testing of the release path", "md_docs_2TASKS.html#autotoc_md279", null ],
        [ "48. Conditional localization/accessibility readiness", "md_docs_2TASKS.html#autotoc_md280", null ],
        [ "49. Security advisory and VEX handling", "md_docs_2TASKS.html#autotoc_md281", null ]
      ] ],
      [ "Release gate — final acceptance checklist", "md_docs_2TASKS.html#autotoc_md283", null ],
      [ "Explicitly out of scope unless separately justified", "md_docs_2TASKS.html#autotoc_md285", null ],
      [ "Research basis", "md_docs_2TASKS.html#autotoc_md287", [
        [ "Research limitations", "md_docs_2TASKS.html#autotoc_md288", null ]
      ] ]
    ] ],
    [ "Development Guide", "md_docs_2development__guide.html", [
      [ "Autoformatting", "md_docs_2development__guide.html#autotoc_md290", null ],
      [ "Static analysis", "md_docs_2development__guide.html#autotoc_md291", null ],
      [ "Testing", "md_docs_2development__guide.html#autotoc_md292", [
        [ "Coverage", "md_docs_2development__guide.html#autotoc_md293", [
          [ "GCC / Clang", "md_docs_2development__guide.html#autotoc_md294", null ],
          [ "MSVC", "md_docs_2development__guide.html#autotoc_md295", null ]
        ] ],
        [ "Dynamic analysis", "md_docs_2development__guide.html#autotoc_md296", [
          [ "Valgrind", "md_docs_2development__guide.html#autotoc_md297", null ],
          [ "Sanitizers", "md_docs_2development__guide.html#autotoc_md298", null ]
        ] ],
        [ "CDash", "md_docs_2development__guide.html#autotoc_md299", null ]
      ] ],
      [ "CMake tips", "md_docs_2development__guide.html#autotoc_md300", null ],
      [ "Doxygen tips", "md_docs_2development__guide.html#autotoc_md301", null ],
      [ "Adding libraries", "md_docs_2development__guide.html#autotoc_md302", null ],
      [ "Windows XP", "md_docs_2development__guide.html#autotoc_md303", null ],
      [ "GitHub Actions tips", "md_docs_2development__guide.html#autotoc_md304", [
        [ "Releases", "md_docs_2development__guide.html#autotoc_md305", null ]
      ] ],
      [ "GitLab tips", "md_docs_2development__guide.html#autotoc_md306", [
        [ "Custom Docker images", "md_docs_2development__guide.html#autotoc_md307", null ]
      ] ],
      [ "Tutorial links", "md_docs_2development__guide.html#autotoc_md308", [
        [ "C++", "md_docs_2development__guide.html#autotoc_md309", null ],
        [ "CMake", "md_docs_2development__guide.html#autotoc_md310", null ],
        [ "Testing", "md_docs_2development__guide.html#autotoc_md311", null ],
        [ "Coverage", "md_docs_2development__guide.html#autotoc_md312", null ],
        [ "Profiling", "md_docs_2development__guide.html#autotoc_md313", null ],
        [ "Debuging", "md_docs_2development__guide.html#autotoc_md314", null ],
        [ "Documentation", "md_docs_2development__guide.html#autotoc_md315", null ],
        [ "Versioning", "md_docs_2development__guide.html#autotoc_md316", null ],
        [ "Licenses", "md_docs_2development__guide.html#autotoc_md317", null ],
        [ "Signing", "md_docs_2development__guide.html#autotoc_md318", null ],
        [ "GitHub", "md_docs_2development__guide.html#autotoc_md319", null ],
        [ "GitLab", "md_docs_2development__guide.html#autotoc_md320", null ],
        [ "Docker", "md_docs_2development__guide.html#autotoc_md321", null ]
      ] ]
    ] ],
    [ "Distribution Hardening — Evidence Ledger", "md_docs_2distribution-hardening-evidence.html", [
      [ "PASS 0 — Reconnaissance (baseline, before any edit)", "md_docs_2distribution-hardening-evidence.html#autotoc_md324", [
        [ "Baseline release contract (live, <span class=\"tt\">v0.0.9</span>)", "md_docs_2distribution-hardening-evidence.html#autotoc_md325", null ],
        [ "Deferred (per issue §7, must not block)", "md_docs_2distribution-hardening-evidence.html#autotoc_md326", null ]
      ] ],
      [ "PASS 1-3 — Implementation and local validation (2026-09-25)", "md_docs_2distribution-hardening-evidence.html#autotoc_md328", [
        [ "Deliverables (new files)", "md_docs_2distribution-hardening-evidence.html#autotoc_md329", null ],
        [ "Validation results (commands → output)", "md_docs_2distribution-hardening-evidence.html#autotoc_md330", null ],
        [ "Still runner/credential-dependent (cannot be claimed green yet)", "md_docs_2distribution-hardening-evidence.html#autotoc_md331", null ]
      ] ],
      [ "PASS 4 — vcpkg binary-cache contract (ADR 006, 2026-09-25)", "md_docs_2distribution-hardening-evidence.html#autotoc_md333", [
        [ "Findings (re-proven from this HEAD before editing)", "md_docs_2distribution-hardening-evidence.html#autotoc_md334", null ],
        [ "Deliverables", "md_docs_2distribution-hardening-evidence.html#autotoc_md335", null ],
        [ "Validation (commands → actual result)", "md_docs_2distribution-hardening-evidence.html#autotoc_md336", null ],
        [ "Live acceptance evidence (target-repo dispatches, 2026-09-25)", "md_docs_2distribution-hardening-evidence.html#autotoc_md337", null ],
        [ "P4-6 (found in run 36126509057, fixed in <span class=\"tt\">1bab366</span>) — USEFUL-4 was host-dependent", "md_docs_2distribution-hardening-evidence.html#autotoc_md338", null ],
        [ "Remaining gaps", "md_docs_2distribution-hardening-evidence.html#autotoc_md339", null ]
      ] ]
    ] ],
    [ "Getting Started", "md_docs_2getting__started.html", null ],
    [ "Installation Guide", "md_docs_2install.html", [
      [ "Linux", "md_docs_2install.html#autotoc_md343", [
        [ "Arch Linux / Manjaro Linux", "md_docs_2install.html#autotoc_md344", null ],
        [ "Debian / Linux Mint / Ubuntu", "md_docs_2install.html#autotoc_md345", null ],
        [ "RedHat / Fedora / CentOS", "md_docs_2install.html#autotoc_md346", null ]
      ] ],
      [ "Windows", "md_docs_2install.html#autotoc_md347", [
        [ "MSVC", "md_docs_2install.html#autotoc_md348", null ],
        [ "MinGW", "md_docs_2install.html#autotoc_md349", null ],
        [ "Dependencies", "md_docs_2install.html#autotoc_md350", [
          [ "wxWidgets (manual install not recommended, prefer vcpkg)", "md_docs_2install.html#autotoc_md351", null ],
          [ "Google Test (manual install not recommended, prefer vcpkg)", "md_docs_2install.html#autotoc_md352", null ],
          [ "vcpkg (recommended)", "md_docs_2install.html#autotoc_md353", null ]
        ] ]
      ] ],
      [ "macOS", "md_docs_2install.html#autotoc_md354", null ],
      [ "Compile", "md_docs_2install.html#autotoc_md355", [
        [ "Linux &amp; Mac", "md_docs_2install.html#autotoc_md356", null ],
        [ "Windows", "md_docs_2install.html#autotoc_md357", null ]
      ] ],
      [ "Package", "md_docs_2install.html#autotoc_md358", [
        [ "Archive", "md_docs_2install.html#autotoc_md359", null ],
        [ "Windows", "md_docs_2install.html#autotoc_md360", [
          [ "NSIS", "md_docs_2install.html#autotoc_md361", null ],
          [ "WiX", "md_docs_2install.html#autotoc_md362", null ]
        ] ],
        [ "Ubuntu", "md_docs_2install.html#autotoc_md363", [
          [ "DEB", "md_docs_2install.html#autotoc_md364", null ],
          [ "RPM", "md_docs_2install.html#autotoc_md365", null ]
        ] ],
        [ "MacOS", "md_docs_2install.html#autotoc_md366", [
          [ "DMG", "md_docs_2install.html#autotoc_md367", null ],
          [ "ProductBuild", "md_docs_2install.html#autotoc_md368", null ]
        ] ]
      ] ],
      [ "Documentation", "md_docs_2install.html#autotoc_md369", null ]
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
"md_docs_2PROJECT__DOCUMENTATION.html#autotoc_md138"
];

var SYNCONMSG = 'click to disable panel synchronization';
var SYNCOFFMSG = 'click to enable panel synchronization';
var LISTOFALLMEMBERS = 'List of all members';