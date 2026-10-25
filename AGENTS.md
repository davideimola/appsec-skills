# appsec-skills

Agent Skills for application security, one pack per ecosystem; Go is the only pack today (ADR 0012). The design and its rationale are in `docs/design/2026-10-21-design-session.md`.

## Commits and pull requests

PR titles and commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `ci:`, `chore:`, …). PRs are squash-merged, so the PR title becomes the commit on `main` and the changelog entry.

## Agent skills

### Issue tracker

Issues live in GitHub Issues for davideimola/appsec-skills, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
