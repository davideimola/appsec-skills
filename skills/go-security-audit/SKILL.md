---
name: go-security-audit
description: Audits the security of a Go repo and reports findings with evidence (reachable vulnerabilities, module verification, toolchain patch level). Use when the user asks to audit or check the security of a Go repo or service, or asks whether its dependencies or Go version have known vulnerabilities.
license: MIT
metadata:
  author: davideimola
---

Audit the **target repo** (the repo you are running in) and report **findings**. The audit is read-only: you run checks and report, and the target repo's files stay exactly as you found them. The one file you may write is the markdown report, and only when the user asks for it.

## Findings

A finding is one problem, reported with these four parts and nothing left blank:

- **Severity**, from the table below.
- **Evidence**: what lets someone else check the finding. Quote the tool output it comes from, and give a `file:line` when the tool names one.
- **Hypothesis**: what the finding claims is wrong, in one sentence.
- **Suggested fix or skill**: the change that removes the problem. Label it **mechanical fix** when it only changes a version or a configuration value.

| Severity | When |
|---|---|
| Critical | `go mod verify` reports a module whose content differs from what was downloaded |
| High | A vulnerability that `govulncheck` shows your code calling; a toolchain on a Go minor line that no longer gets security fixes |
| Medium | A toolchain behind the latest patch release of its Go minor line |

Only what the checks below show becomes a finding. A vulnerability that `govulncheck` finds in a package or module your code does not call is **context**: count it, and leave it out of the findings.

## Steps

1. **Read the target repo.**
   - Go modules: `git ls-files '*go.mod'`, skipping any path with a `vendor/` or `testdata/` segment. Each module directory is the file's directory, `.` for a root `go.mod`.
   - Baseline: record the output of `git status --porcelain`.

   Done when you have at least one module directory and the baseline. With no `go.mod`, stop and tell the user this skill is for Go repos.

2. **Verify modules.** In each module directory, run `go mod verify`.

   Done when every module has a result. `all modules verified` is no finding. Any other output is a Critical finding per module, with that output as its evidence and, as its suggested fix, clearing the module cache entry (`go clean -modcache`) and finding out how the content changed before trusting it again.

3. **Check the toolchain.** In each module's `go.mod`, the Go version builds use is the `toolchain` line, or the `go` line when there is no `toolchain` line (`go 1.26` means `go1.26.0`). Fetch the supported releases from `https://go.dev/dl/?mode=json`: each entry's `version` is the latest patch of a supported minor line.
   - Same minor line listed, same patch: no finding.
   - Same minor line listed, older patch: Medium finding. Suggested fix, a mechanical fix: set `toolchain` to the listed version.
   - Minor line not listed: High finding, the line gets no more security fixes. Suggested fix: move to the oldest listed minor line.

   Done when every module has a result, with the `go.mod` line as evidence for each finding. If the release list cannot be fetched, the check did not run: say so in the report.

4. **Run govulncheck.** In each module directory, run `govulncheck ./...` from the shell or with the tool your agent provides (for example `run_govulncheck` from an MCP server such as Argus in Toolbox mode). When neither has it, run `go run golang.org/x/vuln/cmd/govulncheck@v1.9.0 ./...`, which the Go checksum database verifies and which installs nothing. Exit code 0 means no vulnerability is called and 3 means at least one is; any other exit code means the scan failed, so report its output as a check that did not run. A tool that takes a path needs the module directory's absolute path. When it returns structured results instead of that text, each vulnerability is marked called, imported or required: each called one is a High finding as below, with its call traces as the example traces; the imported and required ones are the unreachable count; and a tool error is a scan failure.
   - Each vulnerability under `=== Symbol Results ===` is a High finding. Evidence: its ID, module, `Found in` and `Fixed in` versions, and its example traces with their `file:line`. Hypothesis: the code at the trace reaches the vulnerable symbol. Suggested fix, a mechanical fix: `go get <module>@<fixed version>` then `go mod tidy`, or for a standard library module, set `toolchain` to a release at or above the fixed version.
   - The closing summary counts the vulnerabilities in packages you import and in modules you require that your code doesn't call. Add the two numbers: that sum is the module's unreachable count.

   Done when every module has its list of called vulnerabilities (possibly empty) and its unreachable count, or a recorded scan failure.

5. **Report.** Write the report in the chat in this shape, with the findings ordered by severity:

   ```
   ## Go security audit

   Checks: go mod verify, toolchain, govulncheck (<modules audited>)
   Findings: <total> (<n> Critical, <n> High, <n> Medium)

   ### 1. [<Severity>] <short title> (<module>)
   - Evidence: <tool output, file:line>
   - Hypothesis: <what is wrong>
   - Suggested fix: <the change, labelled mechanical fix when it is one>

   Context: govulncheck also knows <unreachable count> vulnerabilities in packages and modules this repo requires that its code does not call. They are not findings.
   Not run: <each check that did not run, and why>
   ```

   When the user asks for a markdown report, write the same content to the path they give, and to `go-security-audit-<YYYY-MM-DD>.md` at the repo root when they give none. The report ends the audit: applying a suggested fix is a new request from the user.

   Done when every finding from steps 2 to 4 is in the report with all four parts, the unreachable count is in the context line, and `git status --porcelain` prints the baseline from step 1 (plus the markdown report, if the user asked for one).
