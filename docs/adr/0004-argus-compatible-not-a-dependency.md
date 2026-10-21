# Compatible with Argus, never dependent on it

The skills are written tool-neutral ("run govulncheck from the shell or with the tool your agent provides"), so they work with any agent. Argus is presented as one option: in Toolbox mode it is an MCP server that exposes installed scanners (govulncheck, gosec) and skills, with no LLM provider. It appears in a README section and once, as an example, in `go-security-audit`. Argus's `authz-audit` skill stays in Argus: it is language-agnostic and built on Argus-only tools (`add_finding`, `run_sast`).

## Consequences

- Nothing about Argus is published until an Argus release ships the Tool Catalog and Toolbox mode, and the skills have been tested in `~/.argus/skills/` through an MCP client. Until then, the README mentions only what is on main.
