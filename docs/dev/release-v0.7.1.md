# ToQUBO v0.7.1 publication handoff

This compatible patch contains the ordinary recompilation fix from [PR #252](https://github.com/JuliaQUBO/ToQUBO.jl/pull/252) and citation/archive license correction from [PR #251](https://github.com/JuliaQUBO/ToQUBO.jl/pull/251). The audited interval is `v0.7.0` (`0d2df215272da8e0e3880ca38c6056091d1a2559`) through main `0f8bd8234cbf188081b5946494abd46a0d34c63a`, followed by this release metadata. No API, default, runtime dependency or compatibility bound changes are introduced. The existing docs self-compat `ToQUBO = "0.7"` stays correct.

Compilation regenerates encodings, slack, quadratization auxiliaries, target coefficients and mappings, and invalidates old child results and feasibility caches. Source data, optimizer settings and persistent/refined penalty attributes survive. Later solves start from refined settings unless the caller explicitly replaces those attributes.

## Publication

Follow [the release process](release.md): validate citation schema, release preflight, package tests and documentation; merge the reviewed preparation only after actual review/CI gates pass; register the exact green default-branch release commit; allow General and TagBot to publish normally; and verify a fresh-project/fresh-depot `Pkg.Registry.update(); Pkg.add("ToQUBO")` resolves 0.7.1 and imports successfully. Synchronize the release date in America/New_York before registration freezes the commit.

The unpublished [new-version draft 23247522](https://zenodo.org/deposit/23247522) reserves **10.5281/zenodo.23247522** under existing concept **10.5281/zenodo.21763525**. Its inherited v0.7.0 archive must be replaced with the official v0.7.1 GitHub release archive before publication. Verify UUID `9a412ddf-83fa-43b6-9748-7843c851aa65`, creators, source/citation/archive MPL-2.0 license, release relationships, date and checksums. Replace preparation wording with the official release description. Verify public files and both DOI redirects, then append the verified version DOI to GitHub release notes. Keep the legacy integration disabled and preserve predecessor concept **10.5281/zenodo.6387591** and earlier published records.

## Downstream adoption

After normal installation, verify at least four ordinary solves of the unchanged weak-penalty binary/slack fixture without caller resets: three compiled bits each time, complete decoding, source objective 11, compiled objective 10.9 and source `INFEASIBLE_POINT`. Also verify public feasibility/refinement behavior and persistence of refined penalties.

The next separately scoped QUBODecomposition adoption PR must:

- Require ToQUBO 0.7.1 as the actual fixed test/example minimum and update the pinned integration CI lane.
- Replace the intentional `@test_broken` and obsolete four-bit assertions with passing fresh-compilation regressions.
- Exercise ordinary repeated solves without the reset workaround, while retaining explicit-reset coverage.
- Update acceptance row 19, usage and example documentation.

The current downstream tripwire is expected to fail when it resolves the fixed release; this is the obsolete expected-failure assertion, not evidence of a new runtime regression. Do not weaken the tests. This release does not change downstream source or complete its adoption. After verified installation, link release/General/regression evidence from ToQUBO #244, QUBODecomposition #1, QUBO #73 and roadmap #76; leave those coordination/MVP issues open.
