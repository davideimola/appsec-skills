# Running a scanner from an MCP tool

Read this when step 4 or step 5 runs `govulncheck` or gosec from an MCP tool source. Pass each call the module directory's absolute path, once per module, as the Scanner sources section says.

## govulncheck (step 4)

The tool's results mark each vulnerability called, imported or required:

- Each called vulnerability is a High finding, as step 4 says for `=== Symbol Results ===`, with its call traces as the example traces.
- The imported and required ones add up to the module's unreachable count.
- A tool error is a scan failure: report it as a check that did not run.

## gosec (step 5)

The tool's structured results give each signal's `rule_id`, `severity`, `file`, `line` and `details.cwe`. Triage each one as step 5 says for an issue line, with `rule_id` as its rule and `file`:`line` as its location.

A tool error with no results is a scan failure: report it as a check that did not run for the module.
