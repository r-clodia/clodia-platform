# Repository instructions

## Issue tracking

All issues for the Clodia project are centralized in
[`r-clodia/clodia-platform`](https://github.com/r-clodia/clodia-platform/issues).
Use this tracker for every component, including `clodia-cli`, `clodia-logic`,
`clodia-pwa`, `clodia-tools`, and `clodia-web`.

When implementing an issue, make changes in the repository that owns the
affected code, but keep the issue, discussion, status, and cross-repository
coordination in `clodia-platform`. Do not open duplicate issues in component
repositories.

## Development workflow

Never implement features or issues directly on `main`. Create one dedicated
branch for each feature or issue, commit the scoped changes, push the branch,
and open a pull request. Keep unrelated work in separate branches and pull
requests.
