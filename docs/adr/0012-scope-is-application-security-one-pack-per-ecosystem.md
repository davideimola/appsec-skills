# Scope is application security, one pack per ecosystem

This supersedes ADR 0005. The repo holds application security skills, named `appsec-skills`, and its skills carry an `appsec-` prefix: `appsec-setup`, `appsec-audit`, `appsec-prove`. There is one skill per purpose, never one per ecosystem: a skill reads the ecosystem from the target repo, and what an ecosystem adds (references, canonical assets, a fixture) is its **pack**. Go is the only pack today; the next one is TypeScript.

The method generalizes and the tools do not. The research in `docs/research/2026-10-22-cross-ecosystem-security-tools.md` shows the scanners and pinning differ per ecosystem, while the feasibility run in `docs/research/2026-10-25-ts-prove-feasibility/` shows the prove loop (named cases, a property, a kept failing input, the same tests passing after the fix) holds in TypeScript at the ADR 0002 bar. So the loop, the finding format and the answers file are shared; scanners, assets and test references belong to a pack.

The rename happens before the talk (3 November 2026), not after: changing names costs least before the talk brings installs. GitHub redirects the old repo URL.

## Considered Options

- **Keep `go-security-skills` and add a repo per ecosystem**: rejected. Each repo would repeat CI, release and the shared method, and the method would drift between them.
- **A skill per ecosystem (`go-*`, `ts-*`)**: rejected. The skills would multiply with every pack and repeat the same steps.
- **One Claude Code plugin per pack**: rejected. A pack is folders inside the shared skills, so a pack plugin would hold no skill of its own.
- **Unprefixed names (`security-setup`, `prove-it`)**: rejected. `security-review` is already a Claude Code built-in, and generic names collide with other plugins.
- **Rename after the talk**: rejected. Installs from the talk would land on names about to change.

## Consequences

- A pack exists only with its own fixture and CI (ADR 0002), so packs are added one at a time, and a skill's description names only the ecosystems that have a pack.
- The answers file is `docs/agents/appsec.md`. The setup and the audit still read `docs/agents/go-security.md`, the name the skills used as `go-security-skills`, and the setup replaces it on its next run.
- Installed skills change name: anyone who installed `go-security-skills` re-installs. No release marks it (ADR 0013).
- `go-security.yml`, the setup's fallback workflow name, stays: the workflow it installs is the Go pack's.
- ADRs before this one keep the old names: they record decisions as they were made.
