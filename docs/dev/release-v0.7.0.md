# ToQUBO v0.7.0 publication handoff

This is release preparation for the downstream integration coordinated in
[ToQUBO #244](https://github.com/JuliaQUBO/ToQUBO.jl/issues/244).
The release-preparation PR must receive human review and an authorized merge.
Preparation does not establish package-server availability or complete #244.

## Version and release delta

The last released version is **0.6.1**. This candidate is **0.7.0**, rather than
0.6.2, because source feasibility checking is enabled by default: violating
samples that previously inherited `FEASIBLE_POINT` from the unconstrained child
now report `INFEASIBLE_POINT`. Set `Attributes.PrimalFeasibilityCheck()` to
`false` and re-optimize for the old status behavior. The penalized meaning of
`MOI.ObjectiveValue` is unchanged. Refinement remains disabled by default.
This follows the repository's pre-1.0 minor-version precedent for changed defaults
(v0.5.0) and dependency compatibility (v0.6.0).

The audited source interval is tag `v0.6.1` through main
`b3129618bd489fea9b6d7c83861ee3f9b4d25f77`. [NEWS.md](../../NEWS.md)
records the complete user-visible delta, including:

- [#228](https://github.com/JuliaQUBO/ToQUBO.jl/pull/228): source-feasibility
  status checks, source objective values, and optional cached reports;
- [#231](https://github.com/JuliaQUBO/ToQUBO.jl/pull/231): static penalty policies;
- [#232](https://github.com/JuliaQUBO/ToQUBO.jl/pull/232): finite value-set encoding;
- [#234](https://github.com/JuliaQUBO/ToQUBO.jl/pull/234) and
  [#235](https://github.com/JuliaQUBO/ToQUBO.jl/pull/235): iterative refinement,
  multiplicative updates and augmented-Lagrangian/subgradient updates;
- [#242](https://github.com/JuliaQUBO/ToQUBO.jl/pull/242): exact integral residual
  normalization across Julia versions;
- article/citation provenance, manual successor archiving, dependency maintenance,
  and guarded Dependabot/documentation automation.

The Julia floor stays **1.10**; QUBOTools **0.16** and
PseudoBooleanOptimization **0.2.6 or 0.3** remain supported. Explicit stdlib
bounds do not raise that Julia floor. Documentation accepts
DisjunctiveProgramming 0.5/0.6/0.7; tests retain 0.5/0.6. The release PR changes
only docs self-compat to 0.7 and introduces no production decomposition dependency.

## Unpublished archive reservation

- Existing successor concept DOI: **10.5281/zenodo.21763525**.
- New-version draft: [23226920](https://zenodo.org/deposit/23226920).
- Real reserved version DOI: **10.5281/zenodo.23226920** for **v0.7.0**.
- Draft remains **unpublished**, with no files. The inherited v0.6.1 archive was
  removed from this draft; the published v0.6.1 record was left unchanged.
- MIT license, creators, package UUID, repository, article DOI and predecessor
  concept DOI **10.5281/zenodo.6387591** are preserved.
- **2026-10-07 is the preparation's planned release date.** If publication occurs
  on another date, synchronize NEWS, CITATION.cff and the draft publication date
  before publication. Revalidate the citation schema and release preflight.

The reserved DOI may not resolve until publication. No top-level concept,
release tag, GitHub release or Zenodo publication was created by preparation.
Keep the legacy GitHub-Zenodo integration disabled.

## Next authorized stages

1. Human review, then separately authorized merge of the draft release PR after
   its current-head checks and applicable review gates pass.
2. Separately invoke the Julia release workflow documented in
   [release.md](release.md). Register the verified merge commit with release notes
   that include the breaking default change, observe General and TagBot, and
   verify the tag targets the green release commit. Use a fresh project and fresh
   depot with normal `Pkg.add("ToQUBO")`, import the package, assert version 0.7.0
   and verify `Attributes.MaxPenaltyUpdates` and `Attributes.PrimalFeasibilityCheck`
   and their behavior. A development checkout or explicit-version override does
   not establish normal installation availability.
3. Upload the matching official GitHub source archive to draft 23226920; verify
   version, UUID, license, creators, relationships and archive checksums before
   the separately authorized Zenodo publication. Verify the concept/version DOI
   resolution, predecessor record, and public archive after publication.
4. Implement downstream acceptance rows 17–20 using the actual released minimum
   ToQUBO version. The standalone serial implementation is pinned at
   `e992e33fad931b4d72821bc54a6ab7e838538206` from
   [QUBODecomposition #4](https://github.com/JuliaQUBO/QUBODecomposition.jl/pull/4).
   Candidate probes remain disposable validation only.
5. Complete remaining documentation, installation and ecosystem delivery gates
   before QUBODecomposition 0.1.0. Coordination issues remain open.
