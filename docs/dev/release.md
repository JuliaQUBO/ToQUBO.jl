# Release Process

Release changes live in this repository first. The checks here cover ToQUBO-specific metadata that can drift during a release. If the process works well, copy or generalize the script and templates for adjacent JuliaQUBO packages.

## Prepare the Release PR

1. Update `Project.toml` to the target version.
2. Move the top `NEWS.md` section from `Unreleased` to `vX.Y.Z - YYYY-MM-DD`.
3. Update `docs/Project.toml` self-compat for `ToQUBO`.
   - For `0.Y.Z`, use `0.Y`.
   - For `0.0.Z`, use `0.0.Z`.
   - For `X.Y.Z` with `X > 0`, use `X`.
4. In Zenodo, create a **new version** from the existing ToQUBO record under
   concept DOI `10.5281/zenodo.21763525`; never create a new top-level record
   for a routine release. Reserve the new version DOI, but leave the deposit
   unpublished until the matching GitHub release exists.
5. Update `CITATION.cff` with the release version, date, and reserved version
   DOI. Keep the concept DOI unchanged. Update `CITATION.bib` and the marked
   citation section shared by `README.md` and `docs/src/index.md`.
6. Validate the Citation File Format schema. CI runs this same check on every
   pull request, so run it locally only to get the answer before pushing:

```sh
cffconvert --validate --infile CITATION.cff
```

7. Run the static release preflight:

```sh
julia --project=. scripts/release_check.jl
```

8. Run the package and documentation checks:

```sh
julia --project=. -e 'import Pkg; Pkg.test()'
julia --project=docs docs/make.jl --skip-deploy
```

9. Open and merge the release PR after CI is green.

The Zenodo deposit is currently managed by the designated maintainer account
`bernalde`. Review the single-manager exception annually and whenever package
maintainership changes; add a backup manager when another active maintainer
volunteers. Use personal Zenodo accounts and scoped API tokens—never share an
account password or commit a token.

## Register

After the release PR is merged, invoke Registrator on the merge commit, not on the pull request. Use the template in `docs/dev/release-notes-template.md`.

The release notes should always include a `Breaking changes` or `Changelog` section. General may label pre-1.0 minor releases as `BREAKING`, and AutoMerge requires one of those words in the release notes when that label is present.

```sh
gh api repos/JuliaQUBO/ToQUBO.jl/commits/<merge-sha>/comments -f body="$(cat docs/dev/release-notes-template.md)"
```

Watch the General registry PR:

```sh
gh pr checks <general-pr-number> --repo JuliaRegistries/General --watch
gh pr view <general-pr-number> --repo JuliaRegistries/General --json state,mergedAt,mergeCommit,url
```

If AutoMerge fails because release notes are missing the breaking-change wording, re-invoke Registrator on the same merge commit with corrected release notes.

## Verify TagBot

After the General PR merges, wait for TagBot and verify the tag and release:

```sh
gh run list --workflow TagBot.yml --limit 10
git ls-remote --tags origin vX.Y.Z
gh release view vX.Y.Z
```

## Publish and Verify Zenodo

After the GitHub release exists, upload its official source archive to the
reserved Zenodo version. Confirm the tag, package UUID
`9a412ddf-83fa-43b6-9748-7843c851aa65`, MIT license, creators, repository URL,
and release relationship before publishing the deposit.

The concept DOI is the evergreen software identifier. The DOI assigned to the
new Zenodo version identifies only that exact archive. The historical concept
DOI `10.5281/zenodo.6387591` covers releases through `v0.1.6`; preserve it as
predecessor provenance, but do not publish new releases under it.

Archiving is manual, so the legacy GitHub-Zenodo integration must stay switched
off for this repository. The repository still carries the `release` webhook that
integration installed. If the corresponding Zenodo-side toggle is ever
re-enabled, tagging a release auto-deposits a new version under the historical
concept DOI and the package ends up with two live concept records. Before
tagging, confirm the repository is off in the Zenodo GitHub settings, and after
publishing confirm that `10.5281/zenodo.6387591` still resolves to the `v0.1.6`
record rather than the new release.

After publishing:

1. Add the exact version DOI to the GitHub release notes.
2. Confirm both DOI links resolve (Zenodo may need a short indexing delay):

   ```sh
   curl --fail --location --output /dev/null https://doi.org/<version-doi>
   curl --fail --location --output /dev/null https://doi.org/10.5281/zenodo.21763525
   ```

3. Download the Zenodo archive and the official GitHub release archive, compare
   their SHA-256 checksums, and inspect the archived `Project.toml` to confirm
   that its version matches the tag.
4. Confirm the public Zenodo metadata relates the repository, exact GitHub
   release, historical concept DOI, and QUBO.jl article
   (`10.1080/10556788.2026.2702926`) as documented.

## Verify Pkg.add

Use a fresh depot and project so the check does not reuse a local development path:

```sh
tmp="$(mktemp -d)"
mkdir -p "$tmp/depot" "$tmp/proj"
JULIA_DEPOT_PATH="$tmp/depot" julia --startup-file=no --project="$tmp/proj" -e 'using Pkg; Pkg.add("ToQUBO"); deps = Pkg.dependencies(); versions = [(pkg.name, pkg.version) for pkg in values(deps) if pkg.name == "ToQUBO"]; @show versions'
```
