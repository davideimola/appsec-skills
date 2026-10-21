# Design session, 2026-10-21

A grilling session on what this repo should be, starting from the brief of the talk it ships with ("Securing Go for Production", GoLab 2026, 3 November 2026). It turned the repo from a `gonew` code template into a repo of Agent Skills for Go security. This file is the decision log of that session: each decision, the options weighed, and why. It is the raw material for the first ADRs and for the blog post.

## Facts gathered during the session

- **Talk promises** (`presentations/securing-go`): `TALK.md` says "add `govulncheck` to your CI this week: one PR, one workflow file (copy it from the talk's template repo)". The "Everything, in one repo" slide shows a tree with `internal/authz`, `internal/httpx`, `skills/` and a `gonew` command. Slides can change.
- **Skills ecosystem:**
  - `npx skills add owner/repo` is vercel-labs/skills (directory: skills.sh). It does not require a repo named `skills`.
  - `<owner>/skills` is the convention for general collections (anthropics, openai, google, mattpocock, trailofbits). Topic-scoped repos use descriptive names (`spf13/go-skills`, `samber/cc-skills-golang`).
  - The Agent Skills spec allows `scripts/`, `references/` and `assets/` next to `SKILL.md`, and has a validator, `skills-ref validate`.
  - mattpocock/skills has no CI that tests skills.
- **Existing Go security skills:**
  - `samber/cc-skills-golang` has `golang-security`, which mentions govulncheck and gosec.
  - `eduardo-sl/go-agent-skills` has `go-security-audit`.
  - None of them tests what its skills produce. A generic audit skill alone would not stand out.
- **Skill discovery in `npx skills add`:** it scans `skills/`, the repo root and about 30 agent directories (`.agents/skills/`, `.claude/skills/`, …) with no early stop. `marketplace.json` only adds paths. There is no ignore file. `metadata.internal: true` hides a skill from a plain `add`.
- **Argus** (`argusappsec/argus`, Apache-2.0):
  - **Skills:** it loads them from its built-ins and from `~/.argus/skills/`, using its own `SKILL.md` parser. It has no `npx skills` support.
  - **`authz-audit`:** language-agnostic and tied to Argus tools (`add_finding`, `run_sast`).
  - **Toolbox mode** (no LLM provider): `/mcp` exposes every scanner installed on the host (including `run_govulncheck` and `run_gosec`) and the skills (`pkg/daemon/session.go`, `buildRegistry`).
  - **Release state:** the Go scanners are on main (#118, 2026-10-15) but not in a release; the latest release is v0.3.0.
- **`/setup-matt-pocock-skills`** writes only `docs/agents/*.md`, `GLOSSARY.md`, `docs/adr/` and an `## Agent skills` block in `CLAUDE.md` or `AGENTS.md`. It does not copy skills into the repo.

## Decisions

### What the repo is

1. **Skills only, no code template.** The product is a set of portable Agent Skills. Go code stays only as a test fixture.
   - *Why:* most of the GoLab audience has existing services. A skill adapts to their repo (monorepos, existing workflows, private modules), while a copied file breaks.
   - *Rejected:* a full `gonew` template; a hybrid of template and skills; an importable library (one more supply chain dependency).
2. **Every file a skill can write already exists in this repo and is verified by CI.**
   - *Why:* a skill that writes CI from scratch invents action versions and SHAs. That would be a generated supply chain bug in a talk about supply chain.
3. **Scope: Go security only**, not a general personal skills collection.
   - *Why:* a talk CTA must point to one clear thing, and a focused repo is easier to find.
4. **Name `davideimola/go-security-skills`**, which follows the convention for topic-scoped repos.
5. **License: MIT**, also declared in each skill's `license` frontmatter field.

### The skills (v1)

6. **`go-security-setup`** (*make it routine*) touches configuration only:
   - **What it installs:** a separate `.github/workflows/security.yml`; merges into `dependabot.yml` (`gomod` and `github-actions`, weekly, grouped); checks that `go.mod` has a patched `toolchain`; adds `SECURITY.md` if missing.
   - **`security.yml` runs:**
     - on every PR and push to main: `go mod verify`, `go vet`, `govulncheck` (the official action with `go-version-file: go.mod`), and `go test ./...` (which also runs the fuzz seed corpora);
     - once a week: the same checks, plus each `Fuzz*` target for about a minute, because new vulnerabilities appear without code changes.
   - **Workflow rules:** `permissions: contents: read`, and every action pinned by SHA.
   - **Questions, one section at a time with the recommended answer first:**
     1. What to install. *Default: everything.*
     2. Day and time of the periodic check. *Default: Monday morning.*
     3. Weekly fuzzing and how long per target. *Default: on, 1 minute.*
     4. What fails CI. *Default: any reachable vulnerability.*
     5. How to report vulnerabilities. *Default: GitHub private vulnerability reporting.*
   - **Never asked:** action versions, runner, permissions. There is only one safe answer.
   - **Answers** are saved to `docs/agents/go-security.md` in the user's repo and reused as defaults on the next run.
   - **Respecting existing config:**
     - it never edits existing workflows, and if `govulncheck` already runs elsewhere it offers to add only what is missing;
     - it merges `dependabot.yml` without touching what is there;
     - it adapts to multiple `go.mod` files, branch names and runners;
     - it always shows the diff and asks before writing;
     - it does not pin other people's actions; the audit reports them instead.
7. **`go-security-audit`** (*analyze → find*) never edits on its own:
   - **Tools:** `govulncheck`, `go mod verify`, a toolchain check, and gosec through `go run github.com/securego/gosec/v2/cmd/gosec@vX.Y.Z` (exact version, verified by the checksum database, never installed, never `@latest`).
   - **Patterns from the talk:** servers without timeouts, bodies without `MaxBytesReader`, fail-open authz, client-controlled IDs and URLs, unpinned actions.
   - **Configuration:** reads `docs/agents/go-security.md`, so what the user chose not to install is not reported.
   - **Output:** in chat, and as a markdown file on request. Each finding has severity, evidence (`file:line` or tool output), hypothesis, and the suggested fix or skill. No SARIF in v1.
   - **No fix without evidence:** logic findings (authz, trust boundaries) go through `verify-with-fuzz` first: failing test, then fix, then passing test. Mechanical fixes (timeouts, body limits, toolchain bump) only need confirmation. HTTP fix guides live in the audit's `references/`.
8. **`verify-with-fuzz`** (*test → verify*) turns a hypothesis into a failing test or fuzz property, which stays in the repo as a regression test. Its reference example is deny-by-default authz.
9. **Tools:** the CI that `go-security-setup` installs uses official Go tools only (plus `checkout`, `setup-go` and `govulncheck-action`). gosec is a SAST signal used only inside the audit. `govulncheck` is SCA with reachability, not SAST.

### How this repo proves it works

10. **Repo CI:**
    - `skills-ref validate` on every skill;
    - `actionlint` and `zizmor` on the canonical workflows;
    - a check that every `uses:` is pinned to a full SHA;
    - the canonical `security.yml` runs on this repo itself, with a check that the copy in `.github/workflows/` and the one in the skill's `assets/` are identical, so Dependabot bumps force a sync;
    - `testdata/fixture/`, a Go module with vulnerable and fixed authz, proving the fuzz property finds the bug, and declaring gosec as a `tool` so Dependabot tracks the version the audit pins;
    - a check that fails if a `SKILL.md` exists outside `skills/`.
    - *Out of v1:* LLM-based evals of skill behaviour.
11. **Layout:**
    - `skills/<name>/` (`SKILL.md`, `assets/`, `references/`), with no categories;
    - `testdata/fixture/`, `.github/workflows/`, `.claude-plugin/marketplace.json`;
    - `README.md`, `LICENSE`, `SECURITY.md`.
    - Development structure (`docs/adr/`, `GLOSSARY.md`, `docs/agents/`, `CLAUDE.md`) comes from `/setup-matt-pocock-skills`. Development skills stay installed at user level, never in the repo.

### Distribution and Argus

12. **Install:** `npx skills add davideimola/go-security-skills`, plus `.claude-plugin/marketplace.json` with `source: "./"` and an explicit list of skills. The slide shows only the `npx` command.
13. **Argus is compatible, not a dependency.** Skills are written tool-neutral. `authz-audit` stays in Argus.
    - Argus is presented as an **MCP server in Toolbox mode** (scanners and skills, no agentic part, no LLM provider needed): a README section, plus one neutral line in the audit ("if an MCP server exposes govulncheck or gosec, for example Argus in Toolbox mode, use it instead of the shell").
    - This is published only after an Argus release with the Tool Catalog and Toolbox mode, and a real test (skills in `~/.argus/skills/`, read by an MCP client).

### Out of v1

14. An ADR skill to distribute (Matt Pocock's skills already cover it).
15. An accepted-risks register (an accepted finding recorded with reason and review date in `docs/agents/go-security.md`). This is the first post-talk item.
16. A separate HTTP hardening skill.

### Around the repo

17. **First ADRs:** skills only; CI-verified assets; official-tools-only CI; Argus compatible, not a dependency; Go security scope.
18. **Blog post:** "how I built it": skills whose output is tested, and why a skill that writes CI without canonical files is a supply chain risk. It is published after the talk; the written version of the talk may become a second post.
19. **Slides:**
    - "Everything, in one repo" shows the three skills (`# analyze, find`, `# make it routine`, `# hypothesis → evidence`), with "Give them to your agent. Everything they write is tested.";
    - the next slide shows `npx skills add davideimola/go-security-skills` and the QR instead of `gonew`;
    - "and with Argus" stays in the notes only if decision 13's test passes.

### Build order (cut from the bottom if time runs out)

1. `go-security-setup` with canonical assets and the verifying CI.
2. README, LICENSE, `SECURITY.md`, install via `npx`.
3. `go-security-audit`.
4. `verify-with-fuzz` and the authz fixture.
5. Argus README section and `marketplace.json`.

The slide shows only the skills that exist. The deadline is 3 November 2026, which also requires an Argus release.
