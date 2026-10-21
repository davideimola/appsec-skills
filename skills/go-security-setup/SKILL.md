---
name: go-security-setup
description: Installs Go security CI into a Go repo by adapting a tested canonical workflow (module verification, vet, govulncheck, tests, weekly fuzzing) and Dependabot config (Go modules and GitHub Actions), bumps an unpatched go.mod toolchain, and adds a SECURITY.md. Use when the user wants security CI, govulncheck, Dependabot or a security policy set up in a Go repo, or wants to change its schedule, fuzzing or failure policy.
license: MIT
metadata:
  author: davideimola
---

Install the canonical security workflow and Dependabot config into the **target repo**, the repo you are running in, check that each module's `go.mod` pins a patched toolchain, and add a security policy if it has none.

The workflow is a **canonical asset**: [`assets/security.yml`](assets/security.yml) is tested in the CI of the repo that ships this skill, with every action pinned to a full commit SHA and read-only permissions. Your job is to **copy and adapt** it, never to write or "improve" CI yourself. Every action, SHA, version comment, permission, runner and step stays exactly as in the asset.

The Dependabot config is a canonical asset too: [`assets/dependabot.yml`](assets/dependabot.yml) is schema-validated and audited with zizmor in that same CI, which also runs it. Every entry, schedule, cooldown and group stays exactly as in the asset. So is the security policy, [`assets/SECURITY.md`](assets/SECURITY.md): see [Security policy](#security-policy).

## Adapted values

These are the only lines you change. The assets ship with the values of the repo that tests them, which are also the default answers to the [questions](#questions).

| Value | In the asset | Set it to |
|---|---|---|
| Default branch | `on.push.branches: [main]` | the target repo's default branch |
| Module directories | `jobs.security.strategy.matrix.module: [testdata/fixture]` | one entry per Go module, as a path from the repo root (`.` for the root module) |
| Weekly schedule | `on.schedule: [cron: "0 6 * * 1"]` (Monday 06:00 UTC) | the answer to question 2, as a once-a-week cron in UTC |
| Weekly fuzzing | the `Fuzz each target (weekly)` step, the asset's last step (on) | when question 3 turned fuzzing off, remove that step: its `- name:` line, every line after it, and the blank line before it |
| Fuzz time per target | `FUZZ_TIME: 1m` in the `Fuzz each target (weekly)` step | the answer to question 3, as a Go duration (`30s`, `5m`) |
| Failure policy | `continue-on-error: false` in the `govulncheck` step (a reachable vulnerability fails the run) | `continue-on-error: true` when question 4 chose to only report |
| Dependabot module directories | `assets/dependabot.yml`: the `gomod` entry's `directories: [/testdata/fixture]` | one entry per Go module, as `/` plus its path (`/` for the root module) |
| govulncheck step | the step named `govulncheck` | kept, or removed whole when an existing workflow already covers govulncheck (see below) and the user chooses to keep that one |

## Existing workflows

The setup only ever writes its own workflow file: a new one, or on a re-run the one the saved answers name. Every other workflow in the target repo stays byte-identical, including ones with problems you notice, such as actions pinned to a tag instead of a SHA: list those problems in your report for the user to fix, and leave the file as it is.

An existing workflow **covers govulncheck** when it runs `govulncheck` (the command or `golang/govulncheck-action`) on pull requests and on a schedule at least once a week, in every module directory. A run scans only the module it runs in, because `./...` stops at a nested `go.mod`: a run at the root does not scan `services/api/go.mod`.

## Toolchain

Standard library fixes ship only as Go toolchain releases, so a module is patched only when the toolchain its `go.mod` selects is the latest patch of a supported Go minor. The installed workflow's `setup-go` and `govulncheck` use that same toolchain.

<!-- shared: toolchain -->
- **Selected toolchain:** the `toolchain` line's version; with no `toolchain` line, the `go` line's version (`go 1.26` selects `go1.26`, older than every `go1.26.x` patch).
- **Supported releases:** `curl -s 'https://go.dev/dl/?mode=json'` lists the supported stable releases, newest first, each with its `version`. A minor is supported when one of them has that minor.

| Status | When | Bump `toolchain` to |
|---|---|---|
| Patched | the selected toolchain is the latest listed patch of its minor | nothing |
| Outdated | its minor is listed with a newer patch | the latest patch of the same minor |
| Unsupported | its minor is not listed | the latest patch of the oldest listed minor that is not older than the `go` line |

A bump changes only the `toolchain` line: replace its version, or, with no `toolchain` line, add `toolchain <version>` after the `go` line with one blank line between them, as `go mod edit -toolchain=<version>` writes it. The `go` line is the module's language version and stays as it is.
<!-- /shared: toolchain -->

## Security policy

The target repo has a security policy when it has `SECURITY.md`, `.github/SECURITY.md` or `docs/SECURITY.md`. An existing policy belongs to the target repo: it stays byte-identical, and its answer is `existing` plus its path. Otherwise copy [`assets/SECURITY.md`](assets/SECURITY.md) byte for byte to `SECURITY.md` at the repo root, then change only these lines.

| Value | In the asset | Set it to |
|---|---|---|
| Reporting line | the line starting `Report vulnerabilities`, with this repo's advisory link | the line for the answer to question 5, below |
| Scope | the `## Scope` section, the asset's last: it describes the repo that ships this skill | removed: its heading, every line after it, and the blank line before it |

The reporting line for each answer, with the parts in `<>` filled in:

- GitHub private vulnerability reporting, with the target repo's `owner/repo` from `gh repo view --json nameWithOwner --jq .nameWithOwner`: `Report vulnerabilities privately through GitHub private vulnerability reporting: [open a draft advisory](https://github.com/<owner>/<repo>/security/advisories/new). Please do not open a public issue.`
- An email address: `Report vulnerabilities privately by email to <address>. Please do not open a public issue.`
- A URL: `Report vulnerabilities privately at <URL>. Please do not open a public issue.`

The link works only once private vulnerability reporting is on: `gh api repos/<owner>/<repo>/private-vulnerability-reporting --jq .enabled` prints `true` when it is. The setup writes files only, so when it prints anything else, tell the user to turn it on in the repo's settings, under Advisories, or with `gh api -X PUT repos/<owner>/<repo>/private-vulnerability-reporting`.

## Questions

Ask the five questions in this order, one per message, and wait for each answer before the next. Open each with its recommended answer, so the user can accept it in one word: the saved answer when the [answers file](#answers-file) exists, otherwise the default below. Action versions, runners and permissions come from the asset and are never a question.

| # | Question | Default | Other answers | Skip it when |
|---|---|---|---|---|
| 1 | What to install: the security workflow, Dependabot, the toolchain check, a security policy | everything | any subset | never |
| 2 | Day and time of the weekly run | Monday 06:00 UTC | any day and time; ask the user's time zone and convert to UTC | the security workflow is not installed |
| 3 | Weekly fuzzing, and how long per fuzz target | on, `1m` | off; another Go duration | the security workflow is not installed |
| 4 | Failure policy for a reachable vulnerability | fail the run | report only: the run shows the vulnerabilities and passes | the security workflow is not installed, or an existing workflow covers govulncheck (step 1), so its `govulncheck` step may go |
| 5 | Where vulnerabilities are reported | GitHub private vulnerability reporting | an email address or a URL | a security policy is not installed, or the repo already has `SECURITY.md`, `.github/SECURITY.md` or `docs/SECURITY.md` |

A skipped question keeps its recommended answer in the answers file, so a later run that needs it offers it again. When question 5 is skipped because a policy exists, its answer is `existing` plus that file's path in backticks.

## Answers file

The answers live in the target repo at `docs/agents/go-security.md`, next to the other agent docs, for people and agents (including `go-security-audit`) to read. It is a canonical asset too: copy [`assets/go-security.md`](assets/go-security.md) byte for byte, then change only the text after `- <Key>: ` on these lines.

| Key | In the asset | Set it to |
|---|---|---|
| `Security workflow` | `yes, ` plus `.github/workflows/security.yml` in backticks | `yes, ` plus the install path in backticks, or `no` |
| `Dependabot` | `yes, ` plus `.github/dependabot.yml` in backticks | `yes, ` plus the Dependabot file in backticks, or `no` |
| `Toolchain check` | `yes` | `yes` or `no` |
| `Security policy` | `yes, ` plus `SECURITY.md` in backticks | `yes, ` plus the policy file in backticks, or `no` |
| `Weekly run` | ``Monday 06:00 UTC, cron `0 6 * * 1` `` | the day and UTC time, then `, cron ` and the cron in backticks |
| `Fuzzing` | `on` | `on` or `off` |
| `Fuzz time per target` | `1m` in backticks | the duration in backticks |
| `Reachable vulnerability` | `fail` | `fail` or `report` |
| `Channel` | `GitHub private vulnerability reporting` | the same, `email ` plus the address, the URL, or `existing` plus the policy file in backticks |

The file belongs to this skill: it never goes into `AGENTS.md` or `CLAUDE.md`, and you never edit either of them.

## Steps

1. **Read the target repo.**
   - Default branch: `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`, or `git symbolic-ref --short refs/remotes/origin/HEAD` without the `origin/` prefix. If neither answers, ask the user.
   - Go modules: `git ls-files '*go.mod'`, skipping any path with a `vendor/` or `testdata/` segment. Each module directory is the file's directory, `.` for a root `go.mod`.
   - Saved answers: read `docs/agents/go-security.md` if it exists.
   - Install path: the workflow the saved answers name under `Security workflow`, when that file exists: it is the one this skill installed, and a re-run updates it. Otherwise `.github/workflows/security.yml`, or `.github/workflows/go-security.yml` if that file already exists. If both exist, stop and tell the user: you never edit an existing workflow.
   - Existing govulncheck: search every file in `.github/workflows/` for `govulncheck`, except the install path on a re-run. For each run, note its `file:line`, its triggers, and the module directories it runs in (its `working-directory`, `work-dir` or matrix; the root when none is set).
   - Toolchain: for each module, its `go` and `toolchain` lines and its status, as in [Toolchain](#toolchain).
   - Security policy: the existing policy file, or none, as in [Security policy](#security-policy).

   Done when you have the default branch, at least one module directory, the saved answers or their absence, an install path, every existing govulncheck run with the modules it scans (or none found), each module's toolchain status, and the existing policy file or its absence. With no `go.mod`, stop and tell the user this skill is for Go repos.

2. **Ask the questions.** Follow [Questions](#questions).

   Done when each of the five questions has an answer or was skipped by its rule. Steps 3 to 5 run only when the security workflow is installed, steps 6 and 7 only when Dependabot is, step 8 only when the toolchain check is, and step 9 only when a security policy is.

3. **Adapt the asset.** Copy `assets/security.yml` byte for byte, then replace only the adapted values above, set from the answers. Keep the block-list style of the asset (one `- item` per line).
   - If an existing workflow covers govulncheck, offer to add only what is missing. Recommend removing the `govulncheck` step (the step is whole, from its `- name:` line to the line before the next step), so the new workflow adds module verification, vet, tests and weekly fuzzing next to the user's own govulncheck. The other choice is to keep the step and run govulncheck twice.
   - If existing govulncheck runs miss some modules, pull requests or the weekly schedule, keep the step, and tell the user what the existing runs do not scan.

   Done when a diff between the asset and your adapted file shows changes only on the lines of the adapted values above.

4. **Show and confirm.** Show the user the existing govulncheck runs you found, the full file you will write, its path, and the diff against the asset from step 3; on a re-run, also the diff against the installed file. Ask for confirmation.

   Done when the user has confirmed. If they ask for any change outside the adapted values, explain that the rest of the workflow is the tested asset and leave it as it is.

5. **Write and check.** Write the file to the install path. Then, in each module directory, run `go mod verify`, `go vet ./...` and `go test ./...`, and run `govulncheck ./...` from the shell or with the tool your agent provides.

   Done when the file is written, `git status --porcelain .github/` lists only that file (new, or modified on a re-run), and you have reported, per module, which of those commands passed and which failed. A failure here is what the workflow will also report on its first run, so show the output; it does not undo the install.

6. **Adapt or merge the Dependabot config.** Look for `.github/dependabot.yml`, then `.github/dependabot.yaml`.
   - **No config:** copy `assets/dependabot.yml` byte for byte to `.github/dependabot.yml`, then set the `gomod` entry's `directories` to the module directories from step 1 (see the adapted values). Done when a diff against the asset shows changes only on the `directories` lines.
   - **Existing config:** follow [Merging into an existing config](#merging-into-an-existing-config). Done when every module directory and `/` for GitHub Actions is covered, and `git diff` of the file shows only added lines.

7. **Show, confirm and write.** Show the user the Dependabot file and its diff (against the asset for a new config, against the existing file for a merge), and ask for confirmation, as in step 4. Then write it. If nothing was missing, tell the user the existing config already covers both ecosystems and write nothing.

   Done when the user has confirmed and the file is written, or you have reported that nothing was missing.

8. **Check the toolchain.** Report each module's selected toolchain and its status from step 1. For each module that is not patched, show the `go.mod` diff of its bump, as in [Toolchain](#toolchain), and ask for confirmation. Then write the change and run `go test ./...` in that module, which also downloads the new toolchain.

   Done when every module's status is reported, and each bump the user confirmed is written, with `git diff <module>/go.mod` showing only the `toolchain` line (and its blank line when added) and the `go test` result reported. A declined bump stays in your report as outdated or unsupported.

9. **Add the security policy.** With an existing policy, tell the user its path and leave it as it is. Otherwise adapt the asset as in [Security policy](#security-policy), show the file and its diff against the asset, and ask for confirmation, as in step 4. Then write it to `SECURITY.md`. For GitHub private vulnerability reporting, also report whether it is on.

   Done when the existing policy is reported and `git status --porcelain` lists none of the policy files, or the user has confirmed and `SECURITY.md` is written, with a diff against the asset showing only the reporting line changed and the `## Scope` section removed.

10. **Save the answers.** Adapt `assets/go-security.md` as in [Answers file](#answers-file), with every answer from step 2 and the paths actually written. Show it, with its diff against the saved file on a re-run, then write it to `docs/agents/go-security.md`, creating `docs/agents/` if needed.

   Done when the file is written and a diff against the asset shows changes only after `- <Key>: ` on the lines in the answers file table.

## Merging into an existing config

The existing config belongs to the target repo: every line in it, including its comments, schedules, labels, groups and cooldowns, stays byte for byte as it is. You only append entries to the end of its `updates:` list. Only entries without a `target-branch` count as covering a directory.

- **Go modules.** A module directory is covered when an existing `gomod` entry's `directory`, or one of its `directories` (globs included), matches `/` plus the module path. For the module directories left uncovered, append the asset's `gomod` entry with `directories` set to only those.
- **GitHub Actions.** Covered when an existing `github-actions` entry has `directory: /` or lists `/` in `directories`. If not, append the asset's `github-actions` entry as it is.
- **Indentation.** Re-indent an appended entry to the indentation of the existing `- package-ecosystem` items, so it stays in the same list. Change no other character of it.

## What the workflow does

On every pull request, every push to the default branch and once a week, for each module: check out the code without persisting credentials, install the Go version from that module's `go.mod`, verify modules, vet, run `govulncheck` with that same Go version (unless the user kept their own), and run the tests (which also run fuzz seed corpora). A reachable vulnerability fails the run, or with the report-only policy is shown and lets the run pass. The weekly run catches advisories published after the last change, and, unless fuzzing is off, it also fuzzes each fuzz target in the module for the fuzz time; on a failure it prints the failing input so the user can commit it as a regression test. Pull request and push runs never fuzz beyond the seed corpora. It uses only `actions/checkout`, `actions/setup-go`, `golang/govulncheck-action` and the `go` command.

## What the Dependabot config does

Once a week, Dependabot opens one grouped pull request per module directory for its Go modules, and one for the pinned GitHub Actions, and waits 7 days after a release before proposing it (security updates are not delayed).
