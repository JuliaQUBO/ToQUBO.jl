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

The initial audited source interval is tag `v0.6.1` through main
`b3129618bd489fea9b6d7c83861ee3f9b4d25f77`. Before publication, the merged
release preparation at `a31dbe359294dfb5b4db71423dd384b50e2a94c6` also includes
[#243](https://github.com/JuliaQUBO/ToQUBO.jl/pull/243), allowing
DisjunctiveProgramming 0.7 in tests, and
[#249](https://github.com/JuliaQUBO/ToQUBO.jl/pull/249), correcting the
Dependabot protection/ancestry guard. Neither changes runtime compiler source.
[NEWS.md](../../NEWS.md)
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
DisjunctiveProgramming 0.5/0.6/0.7; tests accept the same range. The release PR changes
only docs self-compat to 0.7 and introduces no production decomposition dependency.

## Archive reservation snapshot: 2026-10-07 preparation

- Existing successor concept DOI: **10.5281/zenodo.21763525**.
- New-version draft: [23226920](https://zenodo.org/deposit/23226920).
- Real reserved version DOI: **10.5281/zenodo.23226920** for **v0.7.0**.
- At this preparation snapshot, the draft is **unpublished**, with no files.
  The inherited v0.6.1 archive was removed from this draft; the published v0.6.1 record was left unchanged.
- At this snapshot, the inherited draft/citation metadata said MIT; the actual
  source `LICENSE` specifies MPL-2.0. This discrepancy was discovered during
  archival verification and must be corrected in the unpublished draft before
  publishing (see below). Creators, package UUID, repository, article DOI and predecessor
  concept DOI **10.5281/zenodo.6387591** are preserved.
- **2026-10-07 is the preparation's planned release date.** If publication occurs
  on another date, synchronize NEWS, CITATION.cff and the draft publication date
  before the release commit is registered. Make any necessary repository-date
  correction in a reviewed metadata commit, then revalidate the citation schema
  and release preflight on the final registration target. The Zenodo
  `publication_date` must match the tagged `CITATION.cff` date.

The version DOI resolves once its matching archive is published. As of this
preparation snapshot, no top-level concept, release tag, GitHub release or Zenodo
publication was created.
Keep the legacy GitHub-Zenodo integration disabled.

## Registration metadata: 2026-10-08

The release date in NEWS and CITATION.cff is **2026-10-08**, verified in
America/New_York and synchronized with the existing unpublished Zenodo draft.
This supersedes the October 7 planned date above. If registration is deferred
to another date, repeat the reviewed synchronization before registration.
The registration target is the merge commit of
[#250](https://github.com/JuliaQUBO/ToQUBO.jl/pull/250) on `main`, after its
main-push checks pass. Record that exact SHA in the release run and invoke
Registrator on that commit, rather than the original release-preparation merge.
If `main` advances again, keep this explicit target or re-audit and record the
additional changes before choosing a later commit.

## Post-tag license metadata correction

The published `v0.7.0` tag remains pinned to
`0d2df215272da8e0e3880ca38c6056091d1a2559`. Its source `LICENSE` specifies
**MPL-2.0**, although its `CITATION.cff` and the inherited Zenodo draft metadata
said MIT. Correct maintained `CITATION.cff` and draft 23226920 to MPL-2.0;
disclose the immutable tagged citation discrepancy in the archive description
and GitHub release notes. This is a metadata correction, not a source relicensing.
Do not retarget the tag, repeat registration, create another Zenodo version, or
change the published v0.6.1 archive as part of this correction.

## Next authorized stages

1. Human review, then separately authorized merge of the draft release PR after
   its current-head checks and applicable review gates pass.
2. Separately invoke the Julia release workflow documented in
   [release.md](release.md). Before registration, complete the date synchronization
   and validation above; if a follow-up metadata commit is needed, use that
   verified green default-branch commit as the registration target. Register with
   release notes that include the breaking default change, observe General and
   TagBot, and verify the tag targets the green release commit. Use a fresh project and fresh
   depot with normal `Pkg.add("ToQUBO")`, import the package, assert version 0.7.0
   and verify `Attributes.MaxPenaltyUpdates` and `Attributes.PrimalFeasibilityCheck`
   and their behavior. A development checkout or explicit-version override does
   not establish normal installation availability.
3. Upload the matching official GitHub source archive to draft 23226920; verify
   version, UUID, license, creators, relationships and archive checksums. Replace
   the temporary preparation description with the official-release archival
   description used for v0.6.1, identifying v0.7.0, before the separately
   authorized Zenodo publication. Verify the concept/version DOI
   resolution, predecessor record, and public archive after publication.
4. Implement downstream acceptance rows 17–20 using the actual released minimum
   ToQUBO version. The standalone serial implementation is pinned at
   `e992e33fad931b4d72821bc54a6ab7e838538206` from
   [QUBODecomposition #4](https://github.com/JuliaQUBO/QUBODecomposition.jl/pull/4).
   Candidate probes remain disposable validation only.
5. Complete remaining documentation, installation and ecosystem delivery gates
   before QUBODecomposition 0.1.0. Coordination issues remain open.
