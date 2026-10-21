# go-security-skills

Agent Skills that bring the practices of the talk "Securing Go for Production" (GoLab 2026) into your Go repo. Everything a skill writes is a canonical asset that this repo's CI tests against a real Go module first, with every action pinned to a full commit SHA.

The skills use the open [Agent Skills](https://agentskills.io) format, so they work with Claude Code, Codex, Copilot, Cursor, Gemini CLI and any other agent that reads `SKILL.md`. You don't call them by name: ask your agent in plain words and it picks the right one.

## Skills

| Skill | What it does | What it touches in your repo |
|---|---|---|
| [`go-security-setup`](skills/go-security-setup/) | Installs Go security CI: module verification, vet, `govulncheck` and tests, on every pull request, every push to the default branch and weekly, with bounded fuzzing of each fuzz target on the weekly run, plus weekly grouped Dependabot updates for Go modules and GitHub Actions. Try "set up Go security CI". | Adds one new workflow file, `.github/workflows/security.yml` (or `go-security.yml` if that name is taken), after showing you the diff. It never edits an existing workflow. Writes `.github/dependabot.yml`, or appends only the missing entries to an existing one without changing its lines. |

`go-security-audit` (find security problems, with evidence) and `verify-with-fuzz` (prove a suspected bug with a failing test) are in progress and will be added to this table when they ship.

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

## How the output is tested

[`.github/workflows/checks.yml`](.github/workflows/checks.yml) validates every skill with the Agent Skills validator, lints every canonical workflow with `actionlint` and `zizmor`, and fails on any action not pinned to a full commit SHA. [`.github/workflows/security.yml`](.github/workflows/security.yml) is byte-identical to the asset `go-security-setup` installs, and runs it against the [fixture](testdata/fixture/) in this repo. [`.github/dependabot.yml`](.github/dependabot.yml) is likewise byte-identical to the Dependabot asset, which CI checks against the Dependabot schema and with `zizmor`.

## Security

To report a vulnerability in the skills, see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
