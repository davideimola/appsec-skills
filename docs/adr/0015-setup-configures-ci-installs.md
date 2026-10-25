# The setup configures; CI is its own skill

`appsec-setup` configures the skills and nothing else: it finds the target repo's ecosystems, asks where the audit gets its scanners from, and writes `docs/agents/appsec.md` and a short "Application security" block in the `## Agent skills` section of `AGENTS.md` (or `CLAUDE.md`). Installing security CI, the old setup's main job, is `appsec-ci`, which writes its own answers to `docs/agents/appsec-ci.md`. `appsec-ci` and `appsec-audit` read the setup's answers and, when there are none, offer once to run `appsec-setup` first; with a no they continue on defaults. `appsec-prove` needs no configuration and never asks.

The old setup did two jobs, so it read as the CI installer rather than the first skill to run, and nothing told an agent the repo used these skills. A setup that only configures takes two questions and changes no CI or code, so it can always run first, the way `setup-matt-pocock-skills` does for Matt Pocock's skills.

## Considered Options

- **One skill in two phases (configure, then optionally install CI)**: rejected. The name and the first questions would still be about CI.
- **One answers file written by both skills**: rejected. A file the setup creates would carry the CI keys' defaults, which say CI is installed when it is not, and the audit would trust them.
- **The other skills refuse to run without the setup**: rejected. A quick audit or a proof should not need configuration first; the offer makes the order clear without blocking.
- **Keep the setup out of `AGENTS.md` and `CLAUDE.md`**: rejected. An agent in the target repo should find where the configuration lives without knowing the skills; the block is canonical, shown as a diff and confirmed.

## Consequences

- The scanner sources block is shared by `appsec-setup`, `appsec-ci` and `appsec-audit`, and the toolchain block by `appsec-ci` and `appsec-audit`; CI keeps every copy identical.
- `docs/agents/go-security.md` from `go-security-skills` is still read by all three for the answers they need, and `appsec-ci` replaces it when it saves its own.
- This repo dogfoods both answers files and the agents block, and CI checks each against its asset.
