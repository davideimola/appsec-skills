# Running a scanner from an MCP tool

Read this when step 4 or step 5 runs `govulncheck` or gosec from an MCP tool source: it maps the tool's results to what those steps read in the text output.

## govulncheck (step 4)

The tool's results say whether the code calls each vulnerability, imports its package or only requires its module:

- Each called vulnerability is a High finding, as step 4 says for `=== Symbol Results ===`, with its call traces as the example traces and its fixed version as `Fixed in`.
- The imported and required ones add up to the module's unreachable count.
- A tool error is a scan failure: report it as a check that did not run.

## gosec (step 5)

The tool's results give each signal's rule, file, line and CWE. Triage each one as step 5 says for an issue line, with that rule and `file`:`line` as its location; any severity the tool gives is gosec's, not the finding's.

A tool error with no results is a scan failure: report it as a check that did not run for the module.
