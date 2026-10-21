---
name: go-security-setup
description: Installs Go security CI into a Go repo by adapting a tested canonical workflow (module verification, vet, govulncheck, tests). Use when the user wants security CI or govulncheck set up in a Go repo.
license: MIT
metadata:
  author: davideimola
---

Install the canonical security workflow into the **target repo**: the repo you are running in.

The workflow is a **canonical asset**: [`assets/security.yml`](assets/security.yml) is tested in the CI of the repo that ships this skill, with every action pinned to a full commit SHA and read-only permissions. Your job is to **copy and adapt** it, never to write or "improve" CI yourself. Every action, SHA, version comment, permission, runner and step stays exactly as in the asset.

## Adapted values

These are the only lines you change. The asset ships with the values of the repo that tests it.

| Value | In the asset | Set it to |
|---|---|---|
| Default branch | `on.push.branches: [main]` | the target repo's default branch |
| Module directories | `jobs.security.strategy.matrix.module: [testdata/fixture]` | one entry per Go module, as a path from the repo root (`.` for the root module) |

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

## What the workflow does

On every pull request and every push to the default branch, for each module: check out the code without persisting credentials, install the Go version from that module's `go.mod`, verify modules, vet, run `govulncheck` with that same Go version, and run the tests (which also run fuzz seed corpora). It uses only `actions/checkout`, `actions/setup-go`, `golang/govulncheck-action` and the `go` command.
