---
name: appsec-setup
description: Configures appsec-skills for a repo, the first skill to run before the others. Use when the user wants to set up or start using appsec-skills in a repo, or change where the audit gets govulncheck and gosec from. It writes configuration only; security CI is appsec-ci.
license: MIT
metadata:
  author: davideimola
---

Configure the appsec skills for the **target repo**, the repo you are running in: find its ecosystems, ask where the audit gets its scanners from, and save the answers where every appsec skill reads them. Run it once before the other skills, and again to change an answer. It writes two things only, the [answers file](#answers-file) and the [agents block](#agents-block): no CI, no code, no dependency.

## Ecosystems

The target repo's ecosystems decide which questions apply. A skill supports an ecosystem only once it has a pack for it, so record what is there even when no skill covers it yet.

- Go modules: `git ls-files '*go.mod'`, skipping any path with a `vendor/` or `testdata/` segment. Each module directory is the file's directory, `.` for a root `go.mod`.
- TypeScript and JavaScript packages: `git ls-files '*package.json'`, skipping any path with a `node_modules/` or `testdata/` segment. Each package directory is the file's directory, `.` for a root `package.json`.

## Scanner sources

`appsec-audit` runs two scanners on Go modules, `govulncheck` and gosec, and `appsec-ci` runs `govulncheck` once after installing. Questions 1 and 2 choose where each one comes from: its **source**. A source changes where a scanner runs, never which scanner it is.

<!-- shared: scanner-sources -->
- **Ephemeral run**, the default: `go run golang.org/x/vuln/cmd/govulncheck@v1.9.0 ./...` and `go run github.com/securego/gosec/v2/cmd/gosec@v2.29.0 -no-fail ./...`, in the module directory. The Go checksum database verifies each version, and nothing is installed. Run exactly these commands, even when the repo has the scanner installed or declares its own tool, so every run uses the same checker.
- **Shell**: `govulncheck ./...` and `gosec -no-fail ./...`, in the module directory, with the binary on the `PATH` at whatever version it is: `go version -m "$(command -v <binary>)"` prints that version on its `mod` line.
- **MCP tool**: a tool an MCP server gives your agent, named by the tool and its server. Call it once per module directory, with its absolute path, not `.` or a path relative to the repo root. It is a source of `govulncheck` only when its results give, for each vulnerability, whether the code calls it, imports its package or only requires its module, the version that fixes it, and the call traces of a called one. It is a source of gosec only when they give each signal's rule, file, line and CWE, whatever the fields are named. A tool that gives less is a different scanner, not a source: osv-scanner, for one, does not say whether the code calls a vulnerability.
<!-- /shared: scanner-sources -->

Before saving a source other than an ephemeral run, check it, and when the check fails, tell the user why and ask the question again:

- **Shell**: `command -v <binary>` finds it. Show the user the version `go version -m` prints next to the ephemeral run's version above, so they choose knowing which checker the audit will run.
- **MCP tool**: your agent has the tool. Call it once on the first module directory, and check that its results have what the list above requires of that scanner. A tool error or results without it fail the check.

## Questions

Ask the questions in this order, one per message, and wait for each answer before the next. Open each with its recommended answer, so the user can accept it in one word: the saved answer when the answers file has one, otherwise the default below.

| # | Question | Default | Other answers | Skip it when |
|---|---|---|---|---|
| 1 | Where the audit gets `govulncheck` from, as in [Scanner sources](#scanner-sources) | an ephemeral run | the shell; an MCP tool, named by the tool and its server | the repo has no Go module |
| 2 | Where the audit gets gosec from, as in [Scanner sources](#scanner-sources) | an ephemeral run | the shell; an MCP tool, named by the tool and its server | the repo has no Go module |

A question skipped because the repo has no Go module is saved as `not used`, and a later run that finds a Go module asks it; tell the user which questions you skipped and why. The CI platform is not a question yet: GitHub Actions is the only one the appsec skills support.

## Answers file

The answers live in the target repo at `docs/agents/appsec.md`, next to the other agent docs, for people and agents to read. It is a canonical asset: copy [`assets/appsec.md`](assets/appsec.md) byte for byte, then change only the text after `- <Key>: ` on these lines.

| Key | In the asset | Set it to |
|---|---|---|
| `Go` | `testdata/fixture` in backticks | the module directories, each in backticks, separated by `, `, or `none` |
| `TypeScript` | `testdata/fixture-ts` in backticks | the package directories, each in backticks, separated by `, `, or `none` |
| `CI platform` | `GitHub Actions` | `GitHub Actions` |
| `govulncheck` | `ephemeral run` | `ephemeral run`, `shell`, or `MCP tool ` plus the tool in backticks, ` from ` and the server in backticks; `not used` when the repo has no Go module |
| `gosec` | `ephemeral run` | as for `govulncheck` |

## Agents block

So that any agent in the target repo knows the appsec skills are configured and where, the setup adds [`assets/agents-block.md`](assets/agents-block.md), byte for byte, to the repo's agent instructions:

- The file is `AGENTS.md` when it exists, otherwise `CLAUDE.md` when it exists. When neither exists, ask the user which to create. When `CLAUDE.md` only imports `AGENTS.md` (`@AGENTS.md`), the file is `AGENTS.md`.
- The block goes at the end of the file's `## Agent skills` section; with no such section, add `## Agent skills` at the end of the file, then the block. Leave one blank line before each heading you add and after it, as in the asset.
- When the file already holds the block's `### Application security` heading, replace that subsection, up to the next heading of level 3 or less, with the block. Every other line of the file stays byte for byte as it is.

## Steps

1. **Read the target repo.**
   - Ecosystems: the Go module directories and the TypeScript and JavaScript package directories, as in [Ecosystems](#ecosystems).
   - Saved answers: read `docs/agents/appsec.md` if it exists, or else `docs/agents/go-security.md`, the name the skills used as `go-security-skills`, for its `Scanner sources`.
   - Agent instructions: the file the block goes in, as in [Agents block](#agents-block), and whether it already holds the block.

   Done when you have each ecosystem's directories or its absence, the saved answers or their absence, and the agent instructions file or the question of which to create.

2. **Ask the questions.** Follow [Questions](#questions).

   Done when each question has an answer or was skipped by its rule, and the source each chose passed its check in [Scanner sources](#scanner-sources).

3. **Show and confirm.** Adapt `assets/appsec.md` as in [Answers file](#answers-file), with the ecosystems from step 1 and the answers from step 2, without writing anything yet. Show the user the answers file and the agent instructions change, each with its diff (against the asset and the existing file, or against the saved file on a re-run), and ask for confirmation.

   Done when the user has confirmed.

4. **Write.** Write the answers file to `docs/agents/appsec.md`, creating `docs/agents/` if needed, and the agents block as in [Agents block](#agents-block). When the saved answers came from `docs/agents/go-security.md`, leave that file in place: `appsec-ci` replaces it with its own answers file the next time it runs.

   Done when a diff of the answers file against the asset shows changes only after `- <Key>: ` on the lines in the answers file table, `git diff` of the agent instructions file shows only the block added or replaced, and `git status --porcelain -uall` lists nothing else.

5. **Report** what was written, then what to run next: `appsec-ci` to install security CI, `appsec-audit` to audit the repo, and `appsec-prove` to prove a suspected authorization bug. Name only the skills that support one of the repo's ecosystems: today, `appsec-ci` and `appsec-audit` support Go, and `appsec-prove` supports Go and TypeScript.
