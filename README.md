# appsec-skills

Application security Agent Skills that set up security CI, audit your code and prove a suspected bug with a failing test before anything is fixed. Everything a skill writes is a canonical asset that this repo's CI tests against a real project first, with every action pinned to a full commit SHA.

The skills are one per purpose; what each ecosystem adds is a **pack**, and a pack ships only once its own fixture runs in CI. **Go** is the pack today, from the talk "Securing Go for Production" (GoLab 2026); **TypeScript** is next.

Formerly `go-security-skills`: the old URL redirects here. The skills are now `appsec-setup` and `appsec-ci` (together formerly `go-security-setup`), `appsec-audit` and `appsec-prove` (formerly `go-security-audit` and `verify-with-fuzz`), and the answers live in `docs/agents/appsec.md` (setup) and `docs/agents/appsec-ci.md` (CI); a `docs/agents/go-security.md` from an earlier version is still read, and `appsec-ci` replaces it on its next run.

The skills use the open [Agent Skills](https://agentskills.io) format, so they work with Claude Code, Codex, Copilot, Cursor, Gemini CLI and any other agent that reads `SKILL.md`. You don't call them by name: ask your agent in plain words and it picks the right one.

## Skills

Start with `appsec-setup`: the other skills read what it saves, and `appsec-ci` and `appsec-audit` offer to run it first when it is missing.

| Skill | What it does | What it touches in your repo |
|---|---|---|
| [`appsec-setup`](skills/appsec-setup/) | **Run it first.** Configures the skills for your repo in a couple of questions: finds its Go modules and TypeScript packages, and asks where the audit gets `govulncheck` and gosec from (an ephemeral `go run`, your shell, or an MCP tool). Try "set up appsec-skills". | Writes only `docs/agents/appsec.md` and a short "Application security" block in the `## Agent skills` section of your `AGENTS.md` (or `CLAUDE.md`), both shown as a diff first. No CI, no code. |
| [`appsec-ci`](skills/appsec-ci/) | Installs Go security CI: module verification, vet, `govulncheck` and tests, on every pull request, every push to the default branch and weekly, with bounded fuzzing of each fuzz target on the weekly run, plus weekly grouped Dependabot updates for Go modules and GitHub Actions. It checks that each `go.mod` pins a patched Go toolchain, and adds a security policy with the reporting channel you choose. Try "set up Go security CI". | Adds one new workflow file, `.github/workflows/security.yml` (or `go-security.yml` if that name is taken), after showing you the diff. It never edits an existing workflow. Writes `.github/dependabot.yml`, or appends only the missing entries to an existing one without changing its lines. Changes only the `toolchain` line of a `go.mod` whose toolchain is unpatched, after you confirm the bump. Adds `SECURITY.md` when the repo has no security policy, and leaves an existing one as it is. Saves your answers (what to install, schedule, fuzzing, failure policy, reporting channel) to `docs/agents/appsec-ci.md`, and never edits `AGENTS.md` or `CLAUDE.md`. |
| [`appsec-audit`](skills/appsec-audit/) | Finds security problems and reports each as a finding with severity, evidence and a suggested fix: vulnerabilities your code actually calls (`govulncheck`), module verification, an outdated Go toolchain, gosec static analysis triaged against the code, HTTP servers without timeouts or body limits, authorization that fails open, client-controlled IDs and URLs crossing a trust boundary, and workflow actions not pinned to a commit SHA. It respects your setup answers: a piece you chose not to install is not reported. Try "check the security of my Go service". | Nothing while it audits: it reads and reports, and writes a markdown report only when you ask for one. Afterwards it shows the mechanical fixes (a timeout, a body limit, a toolchain or dependency bump, an action pin) as a diff, and applies only the ones you confirm. For a logic finding it has `appsec-prove` write a failing test first, then shows the fix as a diff, applies it only when you confirm, and keeps the test. |
| [`appsec-prove`](skills/appsec-prove/) | Proves or rules out a suspected logic bug, such as a member editing a project only its owner or an admin may edit, in Go or TypeScript: it writes test cases of who must be denied and a fuzz property over inputs nobody thought of, runs them on today's code, and tells you whether the bug reproduced. Try "prove whether an admin of another org can manage this org". | Adds test files next to the code it checks (`*_test.go`, `*_fuzz_test.go`) and the fuzzer's failing inputs under `testdata/fuzz/`, which stay as regression tests. It never changes the code under test. |

## Install

With any agent, using the [`skills`](https://github.com/vercel-labs/skills) CLI:

```sh
npx skills add davideimola/appsec-skills
```

As a Claude Code plugin:

```sh
claude plugin marketplace add davideimola/appsec-skills
claude plugin install appsec-skills@appsec-skills
```

Or copy a single folder from [`skills/`](skills/) into your agent's skills folder: each skill is self-contained.

The skills are unversioned while in development: installing gives you `main`, and the Claude Code plugin follows its commits. Versioned releases start once the skills have users (ADR 0013).

## Running the scanners through an MCP server

By default the audit runs `govulncheck` and gosec as ephemeral runs: `go run` at an exact version, which the Go checksum database verifies and which installs nothing. `appsec-setup` also lets you pick, per scanner, the copy on your shell's `PATH`, or a tool an MCP server gives your agent. It checks a tool before saving it: an MCP tool counts as `govulncheck` only when it says, for each vulnerability, whether your code calls it.

[Argus](https://github.com/argusappsec/argus) in Toolbox mode is one such MCP server: it runs the scanners installed on its host (`run_govulncheck` for `govulncheck`, `run_gosec` for gosec) and serves your skills to any MCP client, with no LLM provider needed. Your agent does the reasoning; Argus runs the tools.

Put the skills in Argus's user skills folder, restart the daemon, and connect your agent to Argus's `/mcp` endpoint:

```sh
cp -R skills/* ~/.argus/skills/
```

Your agent then lists and reads the skills through Argus (`list_skills`, `read_skill`, or its prompt menu). Run `appsec-setup` and answer "MCP tool" for each scanner, naming `run_govulncheck` and `run_gosec`. Argus scans code on the machine it runs on, so run it where your code is checked out, with `govulncheck` and gosec installed there. Argus is optional: without it the skills work the same.

## How the output is tested

[`.github/workflows/checks.yml`](.github/workflows/checks.yml) validates every skill with the Agent Skills validator, lints every canonical workflow with `actionlint` and `zizmor`, and fails on any action not pinned to a full commit SHA. [`.github/workflows/security.yml`](.github/workflows/security.yml) is byte-identical to the asset `appsec-ci` installs, and runs it against the [fixture](testdata/fixture/) in this repo. [`.github/dependabot.yml`](.github/dependabot.yml) is likewise byte-identical to the Dependabot asset, which CI checks against the Dependabot schema and with `zizmor`. The deny-by-default authorization examples that `appsec-prove` copies, one per language, are quoted byte for byte from the [Go](testdata/fixture/) and [TypeScript](testdata/fixture-ts/) fixtures, where CI proves each property fails on a vulnerable version and passes on the fixed one. CI also runs the commands each language's reference tells the agent to run: they fail before the fix, keep the failing input (a fuzz corpus file in Go, a fast-check `examples` entry in TypeScript), and pass unchanged after it. This repo's [SECURITY.md](SECURITY.md) is byte-identical to the security policy asset, and CI checks that `appsec-ci` names the reporting line of every channel it can write. [`docs/agents/appsec.md`](docs/agents/appsec.md) and [`docs/agents/appsec-ci.md`](docs/agents/appsec-ci.md) are this repo's copies of the setup and CI answers assets, and this repo's [AGENTS.md](AGENTS.md) holds the block `appsec-setup` writes; CI checks that the setup answers default to an ephemeral run for each scanner, that the CI answers' defaults describe the workflow asset, and that every other answer `appsec-ci` can apply still passes `actionlint` and `zizmor`. The skills that state the scanner sources, the toolchain rule and module discovery keep them in shared blocks, which CI keeps identical.

## Security

To report a vulnerability in the skills, see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
