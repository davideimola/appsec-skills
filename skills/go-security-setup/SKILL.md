---
name: go-security-setup
description: Installs Go security CI into a Go repo by adapting a tested canonical workflow (module verification, vet, govulncheck, tests) and Dependabot config (Go modules and GitHub Actions). Use when the user wants security CI, govulncheck or Dependabot set up in a Go repo.
license: MIT
metadata:
  author: davideimola
---

Install the canonical security workflow and Dependabot config into the **target repo**: the repo you are running in.

The workflow is a **canonical asset**: [`assets/security.yml`](assets/security.yml) is tested in the CI of the repo that ships this skill, with every action pinned to a full commit SHA and read-only permissions. Your job is to **copy and adapt** it, never to write or "improve" CI yourself. Every action, SHA, version comment, permission, runner and step stays exactly as in the asset.

The Dependabot config is a canonical asset too: [`assets/dependabot.yml`](assets/dependabot.yml) is schema-validated and audited with zizmor in that same CI, which also runs it. Every entry, schedule, cooldown and group stays exactly as in the asset.

## Adapted values

These are the only lines you change. The assets ship with the values of the repo that tests them.

| Value | In the asset | Set it to |
|---|---|---|
| Default branch | `on.push.branches: [main]` | the target repo's default branch |
| Module directories | `jobs.security.strategy.matrix.module: [testdata/fixture]` | one entry per Go module, as a path from the repo root (`.` for the root module) |
| Dependabot module directories | `assets/dependabot.yml`: the `gomod` entry's `directories: [/testdata/fixture]` | one entry per Go module, as `/` plus its path (`/` for the root module) |

## Steps

1. **Read the target repo.**
   - Default branch: `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`, or `git symbolic-ref --short refs/remotes/origin/HEAD` without the `origin/` prefix. If neither answers, ask the user.
   - Go modules: `git ls-files '*go.mod'`, skipping any path with a `vendor/` or `testdata/` segment. Each module directory is the file's directory, `.` for a root `go.mod`.
   - Install path: `.github/workflows/security.yml`. If that file already exists, use `.github/workflows/go-security.yml`. If both exist, stop and tell the user: you never edit an existing workflow.

   Done when you have the default branch, at least one module directory, and a free install path. With no `go.mod`, stop and tell the user this skill is for Go repos.

2. **Adapt the asset.** Copy `assets/security.yml` byte for byte, then replace only the adapted values above. Keep the block-list style of the asset (one `- item` per line).

   Done when a diff between the asset and your adapted file shows changes only on the default-branch and module lines.

3. **Show and confirm.** Show the user the full file you will write, its path, and the diff against the asset from step 2. Ask for confirmation.

   Done when the user has confirmed. If they ask for any change outside the adapted values, explain that the rest of the workflow is the tested asset and leave it as it is.

4. **Write and check.** Write the file to the install path. Then, in each module directory, run `go mod verify`, `go vet ./...` and `go test ./...`, and run `govulncheck ./...` from the shell or with the tool your agent provides.

   Done when the file is written and you have reported, per module, which of those commands passed and which failed. A failure here is what the workflow will also report on its first run, so show the output; it does not undo the install.

5. **Adapt or merge the Dependabot config.** Look for `.github/dependabot.yml`, then `.github/dependabot.yaml`.
   - **No config:** copy `assets/dependabot.yml` byte for byte to `.github/dependabot.yml`, then set the `gomod` entry's `directories` to the module directories from step 1 (see the adapted values). Done when a diff against the asset shows changes only on the `directories` lines.
   - **Existing config:** follow [Merging into an existing config](#merging-into-an-existing-config). Done when every module directory and `/` for GitHub Actions is covered, and `git diff` of the file shows only added lines.

6. **Show, confirm and write.** Show the user the Dependabot file and its diff (against the asset for a new config, against the existing file for a merge), and ask for confirmation, as in step 3. Then write it. If nothing was missing, tell the user the existing config already covers both ecosystems and write nothing.

   Done when the user has confirmed and the file is written, or you have reported that nothing was missing.

## Merging into an existing config

The existing config belongs to the target repo: every line in it, including its comments, schedules, labels, groups and cooldowns, stays byte for byte as it is. You only append entries to the end of its `updates:` list. Only entries without a `target-branch` count as covering a directory.

- **Go modules.** A module directory is covered when an existing `gomod` entry's `directory`, or one of its `directories` (globs included), matches `/` plus the module path. For the module directories left uncovered, append the asset's `gomod` entry with `directories` set to only those.
- **GitHub Actions.** Covered when an existing `github-actions` entry has `directory: /` or lists `/` in `directories`. If not, append the asset's `github-actions` entry as it is.
- **Indentation.** Re-indent an appended entry to the indentation of the existing `- package-ecosystem` items, so it stays in the same list. Change no other character of it.

## What the workflow does

On every pull request and every push to the default branch, for each module: check out the code without persisting credentials, install the Go version from that module's `go.mod`, verify modules, vet, run `govulncheck` with that same Go version, and run the tests (which also run fuzz seed corpora). It uses only `actions/checkout`, `actions/setup-go`, `golang/govulncheck-action` and the `go` command.

## What the Dependabot config does

Once a week, Dependabot opens one grouped pull request per module directory for its Go modules, and one for the pinned GitHub Actions, and waits 7 days after a release before proposing it (security updates are not delayed).
