# No releases until the skills have users

This supersedes ADR 0010. The repo cuts no versioned releases for now: no release-please, no tags, no changelog, and no plugin `version` in `.claude-plugin/marketplace.json`. Without a `version`, Claude Code users track the commits on `main`, and `npx skills add` already installs `main`. Versioned releases start once the skills have users who need a stable line, and the first one is chosen then.

`1.0.0` was tagged on 2026-10-21 and nobody, the author included, used it before the rename to `appsec-skills` (ADR 0012). Cutting `2.0.0` for that rename would have announced a breaking change to no one, and a version history that starts with two majors in a week tells future users nothing. The `v1.0.0` tag, its GitHub release and `CHANGELOG.md` are removed; the commits stay in history.

## Considered Options

- **Keep release-please and cut `2.0.0`**: rejected. A major version for a rename with no users is noise.
- **Keep release-please and stay on `1.x`, calling the rename a feature**: rejected. Installed skills do change name, so a `1.1.0` would misstate it.
- **Keep the `v1.0.0` tag as history**: rejected. The next release would be forced to `1.0.1` or `2.0.0` for a line nobody used.

## Consequences

- Every merge to `main` reaches users who installed the plugin, so `main` must stay releasable: CI is the gate, as it already is.
- PR titles keep following Conventional Commits, so release-please can start from them later.
- To start releasing, bring back the setup ADR 0010 describes (workflow, config, manifest, plugin `version`) with the first version set explicitly.
