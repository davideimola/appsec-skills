# Compatible with Argus, never dependent on it

The skills are written tool-neutral ("run govulncheck from the shell or with the tool your agent provides"), so they work with any agent. Argus is presented as one option: in Toolbox mode it is an MCP server that exposes installed scanners (govulncheck, gosec) and skills, with no LLM provider. It appears in a README section and once, as an example, in `go-security-audit`. Argus's `authz-audit` skill stays in Argus: it is language-agnostic and built on Argus-only tools (`add_finding`, `run_sast`).

## Consequences

- The Argus release that ships the Tool Catalog and Toolbox mode is the maintainer's job before the talk, so it does not gate this repo. The Argus mentions are tested against Argus built from main: the skills in `~/.argus/skills/`, read through an MCP client.

Superseded in part by ADR 0011: the skills no longer pick between the shell and the agent's tool; the owner chooses each scanner's source in the setup, and Argus is an example of an MCP tool source.
