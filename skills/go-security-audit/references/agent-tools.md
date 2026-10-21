# Running a scanner with your agent's tool

Read this when step 4 or step 5 runs `govulncheck` or gosec with a tool your agent provides, such as one from an MCP server, instead of from the shell.

## Both scanners

- A tool that takes a path needs the module directory's absolute path, not `.` or a path relative to the repo root.
- One call scans one module, as `./...` does from the shell: call it once per module directory.

## govulncheck (step 4)

When the tool returns structured results instead of govulncheck's text, each vulnerability is marked called, imported or required:

- Each called vulnerability is a High finding, as step 4 says for `=== Symbol Results ===`, with its call traces as the example traces.
- The imported and required ones add up to the module's unreachable count.
- A tool error is a scan failure: report it as a check that did not run.

## gosec (step 5)

The tool's structured results give each signal's `rule_id`, `severity`, `file`, `line` and `details.cwe`. Triage each one as step 5 says for an issue line, with `rule_id` as its rule and `file`:`line` as its location.

A tool error with no results is a scan failure: report it as a check that did not run for the module.
