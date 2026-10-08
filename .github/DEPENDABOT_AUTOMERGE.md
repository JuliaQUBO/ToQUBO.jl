# Dependabot automatic merges

All same-repository Dependabot-authored PRs to `main`, including major and grouped
updates, are eligible when their current head passes the checks below and every
additional reported check has finished successfully (neutral/skipped optional
checks are allowed). Required checks cannot be skipped. Human PRs, drafts,
forks, changed heads, conflicts, and behind branches are left to maintainers.
Identity follows the PR author: maintainer commits on a Dependabot branch are
eligible only after that head passes the same gates.

The workflow checks out trusted `main`, never PR code or artifacts, and uses the
built-in Actions token. It re-reads identity and clean mergeability, verifies
strict branch protection, and squash-merges with `--match-head-commit`, without
admin bypass or a deferred merge request. Existing review/conversation gates
still apply. Errors are isolated per PR and reported after both merge and
publication passes; one failure cannot starve the other PRs.

## Required successful checks

- `Julia 1.10 - ubuntu-latest - x64 - pull_request`
- `Julia 1.10 - windows-latest - x64 - pull_request`
- `Julia 1 - ubuntu-latest - x64 - pull_request`
- `Julia 1 - windows-latest - x64 - pull_request`
- `Dependabot policy`
- `build`

## Branch protection and activation

The existing required CI checks remain unchanged.
The workflow verifies that `main` is protected, strict checking is enabled, and
these contexts remain enforced before merging:

- `Julia 1 - windows-latest - x64 - pull_request`
- `Julia 1 - ubuntu-latest - x64 - pull_request`
- `Julia 1.10 - windows-latest - x64 - pull_request`
- `Julia 1.10 - ubuntu-latest - x64 - pull_request`

Review and merge this draft before activation. When `main` advances, update
existing Dependabot branches with "Update branch" or `@dependabot rebase` and
wait for new CI. The policy runs after configured workflow completions, every
15 minutes, and through manual dispatch. Repository native auto-merge settings
only control manually queued requests; this workflow merges immediately after
verifying all gates.

## Publication and live verification

`GITHUB_TOKEN` merges suppress ordinary push/PR-close workflows. Recent token merges are reconciled for seven days: doccleanup.yml → documentation.yml. Dispatches run trusted `main`, wait for each successful publisher, and use named runs to avoid duplicates. Failed runs stay visible and require a manual rerun. All publishers share a queue across refs; preview cleanup is idempotent and uses a normal fast-forward push.
Main push CI is also suppressed; CI badges and Codecov baselines stay at the last
ordinary main run unless CI is run manually. The up-to-date PR CI remains required.
Tag/release and explicitly requested data/sysimage publishing remain manual;
this policy does not invoke release workflows.

After activation, verify the first real token merge and each dispatched publisher
at its merge SHA and public hosting route. GitHub documents Contents write access
for the [PR merge API](https://docs.github.com/en/rest/pulls/pulls#merge-a-pull-request).
Actions-file updates use the same path; token permissions and completion events
still need live verification. If GitHub rejects such a merge, a maintainer merges
that PR manually; its visible error does not block other PRs. No PAT or new secret
is required. Do not force-push publication history or hide failures to obtain green CI.
