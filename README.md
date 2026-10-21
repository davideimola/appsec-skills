# go-security-skills

Agent Skills that bring the practices of the talk "Securing Go for Production" (GoLab 2026) into your Go repo. Everything a skill writes is a canonical asset that this repo's CI tests against a real Go module first, with every action pinned to a full commit SHA.

The skills use the open [Agent Skills](https://agentskills.io) format, so they work with Claude Code, Codex, Copilot, Cursor, Gemini CLI and any other agent that reads `SKILL.md`. You don't call them by name: ask your agent in plain words and it picks the right one.

## Skills

| Skill | What it does | What it touches in your repo |
|---|---|---|
| [`go-security-setup`](skills/go-security-setup/) | Installs Go security CI: module verification, vet, `govulncheck` and tests, on every pull request, every push to the default branch and weekly, with bounded fuzzing of each fuzz target on the weekly run, plus weekly grouped Dependabot updates for Go modules and GitHub Actions. It checks that each `go.mod` pins a patched Go toolchain, and adds a security policy with the reporting channel you choose. Try "set up Go security CI". | Adds one new workflow file, `.github/workflows/security.yml` (or `go-security.yml` if that name is taken), after showing you the diff. It never edits an existing workflow. Writes `.github/dependabot.yml`, or appends only the missing entries to an existing one without changing its lines. Changes only the `toolchain` line of a `go.mod` whose toolchain is unpatched, after you confirm the bump. Adds `SECURITY.md` when the repo has no security policy, and leaves an existing one as it is. Saves your answers (what to install, schedule, fuzzing, failure policy, reporting channel) to `docs/agents/go-security.md`, and never edits `AGENTS.md` or `CLAUDE.md`. |
| [`go-security-audit`](skills/go-security-audit/) | Finds security problems and reports each as a finding with severity, evidence and a suggested fix: vulnerabilities your code actually calls (`govulncheck`), module verification, an outdated Go toolchain, gosec static analysis triaged against the code, HTTP servers without timeouts or body limits, authorization that fails open, client-controlled IDs and URLs crossing a trust boundary, and workflow actions not pinned to a commit SHA. It respects your setup answers: a piece you chose not to install is not reported. Try "check the security of my Go service". | Nothing while it audits: it reads and reports, and writes a markdown report only when you ask for one. Afterwards it shows the mechanical fixes (a timeout, a body limit, a toolchain or dependency bump, an action pin) as a diff, and applies only the ones you confirm. For a logic finding it has `verify-with-fuzz` write a failing test first, then shows the fix as a diff, applies it only when you confirm, and keeps the test. |
| [`verify-with-fuzz`](skills/verify-with-fuzz/) | Proves or rules out a suspected logic bug, such as an admin of another org managing yours: it writes test cases of who must be denied and a fuzz property over inputs nobody thought of, runs them on today's code, and tells you whether the bug reproduced. Try "prove whether an admin of another org can manage this org". | Adds test files next to the code it checks (`*_test.go`, `*_fuzz_test.go`) and the fuzzer's failing inputs under `testdata/fuzz/`, which stay as regression tests. It never changes the code under test. |

## Install

With any agent, using the [`skills`](https://github.com/vercel-labs/skills) CLI:

```sh
npx skills add davideimola/go-security-skills
```

As a Claude Code plugin:

```sh
claude plugin marketplace add davideimola/go-security-skills
claude plugin install go-security-skills@go-security-skills
```

Or copy a single folder from [`skills/`](skills/) into your agent's skills folder: each skill is self-contained.

Each release is listed on the [releases page](https://github.com/davideimola/go-security-skills/releases) and in the changelog; the Claude Code plugin updates only when a new release is cut.

## Using the skills with Argus

The skills run the scanners from the shell, or with the tools your agent provides. [Argus](https://github.com/argusappsec/argus) in Toolbox mode is one way to provide them: an MCP server that runs the scanners installed on its host (`run_govulncheck` for `govulncheck`, `run_gosec` for gosec) and serves your skills to any MCP client, with no LLM provider needed. Your agent does the reasoning; Argus runs the tools.

Put the skills in Argus's user skills folder, restart the daemon, and connect your agent to Argus's `/mcp` endpoint:

```sh
cp -R skills/* ~/.argus/skills/
```

Your agent then lists and reads the skills through Argus (`list_skills`, `read_skill`, or its prompt menu), and the audit uses Argus's `run_govulncheck` and `run_gosec` tools when they are available. Argus scans code on the machine it runs on, so run it where your code is checked out, with `govulncheck` and gosec installed there. Argus is optional: without it the skills work the same from the shell.

## How the output is tested

[`.github/workflows/checks.yml`](.github/workflows/checks.yml) validates every skill with the Agent Skills validator, lints every canonical workflow with `actionlint` and `zizmor`, and fails on any action not pinned to a full commit SHA. [`.github/workflows/security.yml`](.github/workflows/security.yml) is byte-identical to the asset `go-security-setup` installs, and runs it against the [fixture](testdata/fixture/) in this repo. [`.github/dependabot.yml`](.github/dependabot.yml) is likewise byte-identical to the Dependabot asset, which CI checks against the Dependabot schema and with `zizmor`. The deny-by-default authorization example that `verify-with-fuzz` copies is quoted byte for byte from the fixture, where CI proves its fuzz property fails on a fail-open version and passes on the fixed one. CI also runs the loop the audit follows for a logic finding: the commands `verify-with-fuzz` runs fail before the fix, keep the fuzzer's failing input, and pass unchanged after it. This repo's [SECURITY.md](SECURITY.md) is byte-identical to the security policy asset, and CI checks that the setup names the reporting line of every channel it can write. [`docs/agents/go-security.md`](docs/agents/go-security.md) is this repo's copy of the setup answers asset; CI checks that its defaults describe the workflow asset, and that every other answer the setup can apply still passes `actionlint` and `zizmor`.

## Security

To report a vulnerability in the skills, see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
