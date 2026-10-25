# Releases are cut by release-please

Superseded by ADR 0013.

This repo's releases are cut by `googleapis/release-please-action` in `.github/workflows/release-please.yml`, from the Conventional Commits that squash merges put on `main`. It keeps a release PR open with the next version and the changelog, and merging that PR tags the release, writes `CHANGELOG.md` and bumps the plugin `version` in `.claude-plugin/marketplace.json`, so Claude Code users receive a new copy only on a release. The first release is `1.0.0`. The workflow is release tooling for this repo's own CI, not a canonical asset: ADR 0003 limits what `go-security-setup` installs in someone else's CI and does not apply here.

It is a third-party action with write access, so its exposure is kept small: it is pinned to a full commit SHA like every other action, the workflow grants nothing at the top level, and its one job gets only `contents: write` and `pull-requests: write`, the least release-please needs to push the release branch, open and label the release PR, and create the tag and release. It runs with `GITHUB_TOKEN`, not a personal access token.

## Considered Options

- **A personal access token or GitHub App token**: rejected for now. CI would run on the release PR, but a long-lived secret with write access is a bigger risk than a release PR that only changes the version and the changelog. Because `GITHUB_TOKEN` events start no workflows, checks do not run on the release PR.
- **Tagging releases by hand**: rejected. The changelog and the plugin version would drift from the commits.
- **No plugin `version`**: rejected. Users would then get every commit on `main`, not releases.

## Consequences

- PR titles must follow Conventional Commits: only `feat`, `fix`, `perf` and `revert` reach the changelog and trigger a release, and a `!` or `BREAKING CHANGE` footer makes it a major one.
- The repo setting "Allow GitHub Actions to create and approve pull requests" must be on, or `GITHUB_TOKEN` cannot open the release PR.
- Do not edit `version` in `.claude-plugin/marketplace.json` or `.release-please-manifest.json` by hand; release-please owns both.
