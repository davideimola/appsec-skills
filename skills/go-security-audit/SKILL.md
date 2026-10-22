---
name: go-security-audit
description: Security audit of a Go repo or service. Use when the user asks to audit or check the security of Go code, or whether its dependencies or Go version have known vulnerabilities.
license: MIT
metadata:
  author: davideimola
---

Audit the **target repo** (the repo you are running in) and report **findings**. Up to the report, the audit is read-only: you run checks and report, and the target repo's files stay exactly as you found them. The one file you may write by then is the markdown report, and only when the user asks for it. After the report, you change files only to apply the mechanical fixes the user confirms (step 8), and to prove each logic finding with `verify-with-fuzz` and apply the fix the user confirms once its test fails (step 9).

## Findings

A finding is one problem, reported with these four parts and nothing left blank:

- **Severity**, from the table below.
- **Evidence**: what lets someone else check the finding. Quote the tool output it comes from, and give a `file:line` when the tool names one.
- **Hypothesis**: what the finding claims is wrong, in one sentence.
- **Suggested fix or skill**: the change that removes the problem. Label it **mechanical fix** when it only changes a version, a default or a configuration value. A finding about who may do what or which input is trusted is a **logic finding**: label it so, and its suggested skill is `verify-with-fuzz` with the hypothesis to hand it, never a fix, because a logic fix needs a failing test first.

| Severity | When |
|---|---|
| Critical | `go mod verify` reports a module whose content differs from what was downloaded |
| High | A vulnerability that `govulncheck` shows your code calling; a toolchain on a Go minor line that no longer gets security fixes; a confirmed gosec signal that input from outside the program reaches; authorization that grants access when its check cannot be resolved, or checks membership where a role is required; a client-controlled ID or URL crossing a trust boundary unchecked |
| Medium | A toolchain behind the latest patch release of its Go minor line; a gosec signal you confirmed in the code; an HTTP server without timeouts; a request body read without a size limit; a workflow action not pinned to a full commit SHA |

Only what the checks below show becomes a finding. A vulnerability that `govulncheck` finds in a package or module your code does not call is **context**: count it, and leave it out of the findings. A gosec issue is a **signal**: it becomes a finding only once the code at its `file:line` confirms it (step 5).

## Setup answers

`go-security-setup` records what the owner chose to install in `docs/agents/go-security.md`. When the target repo has that file, each answer below is the owner's decision: leave out what the table says, from the findings and from every suggested fix, and name the answer in the report's `Opted out` line. A `yes` or `on` answer, or no answers file, leaves out nothing.

| Answer | Leave out |
|---|---|
| `Security workflow: no` | Any finding or suggested fix saying the repo lacks a security workflow or a `govulncheck` run in CI |
| `Dependabot: no` | Any finding or suggested fix proposing Dependabot, including to keep action pins current |
| `Toolchain check: no` | Step 3: skip it, so no toolchain finding is reported |
| `Security policy: no` | Any finding or suggested fix saying the repo lacks a security policy (`SECURITY.md`) |
| `Fuzzing: off` | Any finding or suggested fix proposing a scheduled fuzz run |

## Scanner sources

Steps 4 and 5 run `govulncheck` and gosec from the source the answers file names under `## Scanner sources`, on its `govulncheck:` and `gosec:` lines: the owner's choice of where each scanner runs, never of which scanner it is. With no answers file, or no line for a scanner, its source is an ephemeral run.

<!-- shared: scanner-sources -->
- **Ephemeral run**, the default: `go run golang.org/x/vuln/cmd/govulncheck@v1.9.0 ./...` and `go run github.com/securego/gosec/v2/cmd/gosec@v2.29.0 -no-fail ./...`, in the module directory. The Go checksum database verifies each version, and nothing is installed. Run exactly these commands, even when the repo has the scanner installed or declares its own tool, so every run uses the same checker.
- **Shell**: `govulncheck ./...` and `gosec -no-fail ./...`, in the module directory, with the binary on the `PATH` at whatever version it is: `go version -m "$(command -v <binary>)"` prints that version on its `mod` line.
- **MCP tool**: a tool an MCP server gives your agent, named by the tool and its server. Call it once per module directory, with its absolute path, not `.` or a path relative to the repo root. It is a source of `govulncheck` only when its results give, for each vulnerability, whether the code calls it, imports its package or only requires its module, the version that fixes it, and the call traces of a called one. It is a source of gosec only when they give each signal's rule, file, line and CWE, whatever the fields are named. A tool that gives less is a different scanner, not a source: osv-scanner, for one, does not say whether the code calls a vulnerability.
<!-- /shared: scanner-sources -->

An MCP tool is the tool your agent provides through an MCP server, for example `run_govulncheck` or `run_gosec` from Argus in Toolbox mode. Before running a scanner from one, read [references/mcp-tool-sources.md](references/mcp-tool-sources.md): it says how its results map to the text steps 4 and 5 read.

A source is unavailable when the shell has no such binary, or your agent has no such tool, or the tool's results lack what the list above requires. Then ask once for that scanner: "<the source> is not available. Run <scanner> as an ephemeral run instead? yes or no". With yes, run the ephemeral run. With no, the check did not run for any module: report it under `Not run` with the reason, and that running `go-security-setup` again changes the source. Never run a scanner from a source the answers do not name, other than the ephemeral run the user accepted.

## Steps

1. **Read the target repo.**
   - Go modules: `git ls-files '*go.mod'`, skipping any path with a `vendor/` or `testdata/` segment. Each module directory is the file's directory, `.` for a root `go.mod`.
   - Baseline: record the output of `git status --porcelain`.
   - Setup answers: read `docs/agents/go-security.md` if it exists, and note each answer from the [Setup answers](#setup-answers) table it gives, and each scanner's source from [Scanner sources](#scanner-sources).

   Done when you have at least one module directory, the baseline, the answers that leave something out (or none), and a source for each scanner. With no `go.mod`, stop and tell the user this skill is for Go repos.

2. **Verify modules.** In each module directory, run `go mod verify`.

   Done when every module has a result. `all modules verified` is no finding. Any other output is a Critical finding per module, with that output as its evidence and, as its suggested fix, clearing the module cache entry (`go clean -modcache`) and finding out how the content changed before trusting it again.

3. **Check the toolchain.** Give each module's `go.mod` a status.

   <!-- shared: toolchain -->
   - **Selected toolchain:** the `toolchain` line's version; with no `toolchain` line, the `go` line's version (`go 1.26` selects `go1.26`, older than every `go1.26.x` patch).
   - **Supported releases:** `curl -s 'https://go.dev/dl/?mode=json'` lists the supported stable releases, newest first, each with its `version`. A minor is supported when one of them has that minor.

   | Status | When | Bump `toolchain` to |
   |---|---|---|
   | Patched | the selected toolchain is the latest listed patch of its minor | nothing |
   | Outdated | its minor is listed with a newer patch | the latest patch of the same minor |
   | Unsupported | its minor is not listed | the latest patch of the oldest listed minor that is not older than the `go` line |

   A bump changes only the `toolchain` line: replace its version, or, with no `toolchain` line, add `toolchain <version>` after the `go` line with one blank line between them, as `go mod edit -toolchain=<version>` writes it. The `go` line is the module's language version and stays as it is.
   <!-- /shared: toolchain -->

   Patched is no finding. Outdated is a Medium finding. Unsupported is a High finding: its minor line gets no more security fixes. For both, the suggested fix is a mechanical fix: `go mod edit -toolchain=<version>`, with the version from the table.

   Done when every module has a result, with the `go.mod` line as evidence for each finding, or the step is skipped because of `Toolchain check: no`. If the release list cannot be fetched, the check did not run: say so in the report.

4. **Run govulncheck.** In each module directory, run `govulncheck` from its source, as in [Scanner sources](#scanner-sources). From the shell or as an ephemeral run, exit code 0 means no vulnerability is called and 3 means at least one is; any other exit code means the scan failed, so report its output as a check that did not run.
   - Each vulnerability under `=== Symbol Results ===` is a High finding. Evidence: its ID, module, `Found in` and `Fixed in` versions, and its example traces with their `file:line`. Hypothesis: the code at the trace reaches the vulnerable symbol. Suggested fix, a mechanical fix: `go get <module>@<fixed version>` then `go mod tidy`, or for a standard library module, a toolchain bump (step 3) to a release at or above the fixed version.
   - The closing summary counts the vulnerabilities in packages you import and in modules you require that your code doesn't call. Add the two numbers: that sum is the module's unreachable count.

   Done when every module has its list of called vulnerabilities (possibly empty) and its unreachable count, or a recorded scan failure.

5. **Run gosec.** In each module directory, run gosec from its source, as in [Scanner sources](#scanner-sources). The text output ends with a summary whose `Issues` line counts the signals. A `Golang errors in file` block means gosec could not load that file, so the file was not checked even when `Issues` is 0: report the block as a check that did not run for those files. `export data version` in it means this gosec version cannot read packages built by the module's Go release. Any error that stops the scan means the check did not run for the module.

   Each issue, `[<file>:<line>] - <rule> (CWE-<n>): <message> (Confidence: <level>, Severity: <level>)` followed by the code around that line, is a signal to triage; gosec's own severity is not the finding's. For each one, open the code at that `file:line` and follow the flagged value back to where it comes from:
   - **Confirmed**: the code shows the weakness is real, because a value from outside the program (a request, a file, an environment variable, an argument) reaches the flagged line, or the weakness holds whatever the input (for example a disabled TLS check). It is a finding: High when input from outside the program reaches it, Medium otherwise. Evidence: the gosec issue line, plus the `file:line` where the value enters. Hypothesis: what an attacker or a mistake can do there. Suggested fix: the code change, in one or two sentences.
   - **Dismissed**: the code shows the value cannot carry the risk (a constant, a value already validated on every path to the line, a use that is not security-relevant). Record the rule, the `file:line` and that reason from the code.

   Signals with different rules on the same `file:line` that describe one weakness are one finding that cites each rule.

   Done when every module has its gosec summary, or a recorded scan failure, and every signal is confirmed or dismissed with its reason.

6. **Look for the talk's patterns.** Read the code yourself: no scanner above reports these reliably. In each module, search the Go files outside `_test.go` files, `vendor/` and `testdata/` for the first three patterns; search the repo's workflows for the fourth. A match the surrounding code shows is safe (a limit set in a middleware on every route to it, a check on the caller before the lookup) is no finding. A match on a line where step 5 confirmed a gosec signal is one finding that cites the gosec rule and takes this step's severity and suggested fix or skill.
   - **HTTP limits**: a server without timeouts, or a handler reading a request body with no size limit. When the module uses `net/http`, read [references/http-limits.md](references/http-limits.md) now: it says what to look for, the evidence to give, and the mechanical fix, proven in this repo's CI. Medium.
   - **Fail-open authorization**: a function or middleware that decides whether a caller may act (names like `Can*`, `Authorize*`, `Require*`, `Is*Allowed`, or a role or permission check before a handler). It is a finding when it grants on a path where the decision cannot be resolved (an empty or zero target ID, a lookup error or not-found result, a missing caller, a `default:` branch), or when it compares the caller's membership (`u.OrgID == orgID`, a tenant or team match) where the feature requires a role (its name, doc comment or route says admin or manage). High, logic finding. Evidence: the function's `file:line` and the line that grants. Hypothesis: a concrete caller and target the rule denies and the code grants, such as "a plain member can manage their org" or "a request whose org cannot be resolved is granted".
   - **Client-controlled IDs and URLs**: a value from the request (`r.PathValue`, `r.URL.Query()`, `r.FormValue`, a header, a decoded body field, a router parameter) that crosses a trust boundary. An ID is a finding when it reads or changes a resource with no check on the way that ties the resource to the authenticated caller, and when it is the caller's own identity or role (an `X-User-*` header, a body field) taken without verifying a credential. A URL is a finding when it reaches an outbound request (`http.Get`, `http.NewRequest`, a client's `Do`) without an allow-list of hosts, or reaches `http.Redirect`. High, logic finding. Evidence: the `file:line` where the value enters and the `file:line` where it is used. Hypothesis: the crossing, such as "a caller can read another org's invoices by sending their ID" or "a client can make the server request an internal address".
   - **Unpinned workflow actions**: in each file of `git ls-files '.github/workflows/*.yml' '.github/workflows/*.yaml' '*action.yml' '*action.yaml'`, every `uses:` whose ref after `@` is not a full 40-character commit SHA. Local actions (`./`) and `docker://` images pinned by `@sha256:` digest are pinned. Medium. Evidence: the `file:line` and its `uses:` line. Suggested fix, a mechanical fix: `uses: <owner>/<repo>@<sha> # <ref>`, with the SHA the ref points at now from `git ls-remote https://github.com/<owner>/<repo> <ref>` (for an annotated tag, its `^{}` line), never a SHA from memory.

   Done when every module's Go files have been searched for the first three patterns and every `uses:` line of every workflow file has been checked, with each match recorded as a finding with all four parts or as safe because of a line you can name.

7. **Report.** Write the report in the chat in this shape, with the findings ordered by severity:

   ```
   ## Go security audit

   Checks: go mod verify, toolchain, govulncheck <version run, or unknown> (<source>), gosec <version run, or unknown> (<source>), patterns (<modules audited>)
   Findings: <total> (<n> Critical, <n> High, <n> Medium)

   ### 1. [<Severity>] <short title> (<module>)
   - Evidence: <tool output, file:line>
   - Hypothesis: <what is wrong>
   - Suggested fix or skill: <the change, labelled mechanical fix when it is one>, or logic finding: `verify-with-fuzz` with <the hypothesis>

   Context: govulncheck also knows <unreachable count> vulnerabilities in packages and modules this repo requires that its code does not call. They are not findings.
   Dismissed gosec signals: <n>, each as <rule> <file:line>: <reason from the code>
   Opted out: <each setup answer that left something out, and what it left out>, or none
   Not run: <each check that did not run, and why>
   ```

   When the user asks for a markdown report, write the same content to the path they give, and to `go-security-audit-<YYYY-MM-DD>.md` at the repo root when they give none.

   Done when every finding from steps 2 to 6 is in the report with all four parts, the `Checks` line names the source each scanner ran from, the unreachable count is in the context line, every dismissed gosec signal is listed with its reason, every setup answer from step 1 that left something out is in the `Opted out` line, and `git status --porcelain` prints the baseline from step 1 (plus the markdown report, if the user asked for one).

8. **Apply the confirmed mechanical fixes.** When no finding has a mechanical fix, go to step 9. Otherwise:
   - Prepare every mechanical fix as the finding's suggested fix says, and show each as a unified diff, numbered by its finding.
   - Ask once: "Apply these <n> mechanical fixes? yes, no, or the numbers to apply." Wait for the answer, and apply exactly the fixes it confirms. With no, the files stay at the baseline.
   - In each module you will change, run `go build ./...`, `go vet ./...` and `go test ./...` before applying anything, and record what fails. After applying, run them again, then rerun the check that produced each applied fix's finding (for a pattern, its search at that `file:line`). A fix that makes something fail that passed before, or whose finding is still there, is reverted, and you show the output that failed.
   Done when every mechanical fix is applied with its checks passing, reverted with the output that failed, or declined, and `git status --porcelain` prints the baseline plus only the files of the applied fixes (and the markdown report, if the user asked for one).

9. **Prove, then fix, the logic findings.** When no finding is a logic finding, the audit ends here. Otherwise:
   - Ask once: "Prove these <n> logic findings with `verify-with-fuzz`? It adds tests and changes no code. yes, no, or the numbers to prove." Wait for the answer. A finding it does not confirm stays a hypothesis in the report, and you propose no fix for it.
   - For each confirmed finding, in the report's order, follow `verify-with-fuzz` with the finding's hypothesis, through its report. When `verify-with-fuzz` is not installed, stop: tell the user each logic finding needs it for a failing test, and propose no fix.
   - **Not reproduced**: propose no fix. Its tests stay as regression tests.
   - **Reproduced**, and each entry under **Also found**: only now, with the test failing, prepare the fix to the check. It changes only the decision the tests cover, so the check grants exactly the rule's ways in from `verify-with-fuzz`'s step 1. Show it as a unified diff, with the failing test and its `granted:` line as its evidence, and ask: "Apply this fix to <func>? yes or no." Apply it only on yes; with no, the code stays as it is and the tests stay failing.
   - In the module, run `go build ./...`, `go vet ./...` and `go test ./...` before applying the fix, and record what fails besides the new tests. After applying, run `verify-with-fuzz`'s After a fix section (its step 4 commands unchanged, then `go test ./<pkg>`), then the three commands again. The fix is verified when the After a fix commands pass and nothing fails that passed before. Otherwise revert the fix and show the output that failed, such as the input still granted. The tests stay either way.
   - Tell the user, per logic finding: its result, the fix (applied and verified, reverted with the output that failed, declined, or none proposed), and the test files kept.

   Done when every logic finding is reproduced or not reproduced with `verify-with-fuzz`'s report, or not confirmed for proving; every reproduced one and every Also found entry has its fix applied and verified, reverted with the output that failed, or declined; and `git status --porcelain` prints the baseline plus only the files of the applied mechanical fixes, the test files and `testdata/fuzz/` inputs `verify-with-fuzz` wrote, and the files of the applied logic fixes (and the markdown report, if the user asked for one).
