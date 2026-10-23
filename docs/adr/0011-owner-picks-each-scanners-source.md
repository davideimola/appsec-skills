# The owner picks each scanner's source; ephemeral run is the default

`go-security-setup` asks, for `govulncheck` and for gosec, where the audit gets the scanner from: an **ephemeral run** (`go run <module>@<exact version>`), the shell, or an MCP tool. The answer is saved in the setup answers, and `go-security-audit` uses it. With no answer, the scanner runs as an ephemeral run, so every audit that nobody configured runs the same checker, verified by the Go checksum database and installed nowhere. A scanner from the shell is allowed for gosec too, but only when the owner chooses it, and the audit reports the version that ran. This supersedes ADR 0003's "gosec runs only through `go run`" for the audit.

A source changes where a scanner runs, never which scanner it is. An MCP tool is a source of `govulncheck` only when it reports each vulnerability as called, imported or required, because the audit's rule (a called vulnerability is a finding, the rest are context) is defined on that output. A scanner without reachability, such as osv-scanner, is therefore not an SCA source: it would be a different scanner, which belongs to a future pack for another ecosystem, not to this choice (ADR 0005).

## Considered Options

- **A source per capability (SCA, SAST) that any tool can fill**: rejected. osv-scanner, also through Argus's `run_osv_scanner`, gives no called/uncalled split, so the audit would need a second set of rules for SCA without reachability.
- **Keep today's order (shell first, then the agent's tool, then `go run`)**: rejected. Which checker ran depended on what happened to be installed.
- **Never run gosec from the shell**: rejected. An owner may have a reason to run their own gosec; the default keeps the supply chain property for everyone else.
- **A configurable fuzz source**: rejected. Fuzzing is `go test -fuzz`, part of the toolchain, with no version to pin and no MCP equivalent.

## Consequences

- The setup verifies a source before saving it: a shell binary exists (and its version is shown), an MCP tool is available and returns the output the audit needs. An ephemeral run's version lives in the skill, not in the answers, so a release can update it.
- When the chosen source is unavailable during an audit, the audit asks once whether to use an ephemeral run instead, and otherwise reports the check as not run. The `Checks` line always names the source each scanner ran from.
- Argus stays an example of an MCP tool source (ADR 0004).
