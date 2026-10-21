---
name: verify-with-fuzz
description: Verifies a security hypothesis about Go code by writing a fuzz property and named test cases that fail on today's code and stay as regression tests. Use when the user suspects an authorization or trust bug in Go code (who may do what, which input is trusted) and wants it proven with a failing test, or when go-security-audit needs evidence for a logic finding.
license: MIT
metadata:
  author: davideimola
---

Turn a **hypothesis** into **evidence**: tests in the **target repo** (the repo you are running in) that go red on today's code when the hypothesis holds. You write tests only. The code under test stays exactly as you found it, and the tests stay in the repo as regression tests whatever the result.

The test checks who must be denied, not only who gets in. A fail-open bug passes every test of who gets in.

## Steps

1. **Pin the hypothesis to a check.**
   - Find the function that makes the decision the hypothesis is about, with its package and `file:line`.
   - Write down the rule it must enforce as its explicit ways in (for example: a super admin, or an admin of that same organization). Take the rule from the function's doc comment, the user or the hypothesis. When they disagree or none states it, ask the user.
   - Restate the hypothesis as a named case: a literal input and the answer the rule requires, deny (for example: an org admin of `acme` on `globex` must be denied).
   - Baseline: record the output of `git status --porcelain`.

   For a hypothesis about who may do what, read [references/deny-by-default-authz.md](references/deny-by-default-authz.md) now: it is the shape to copy, proven in CI to fail on a fail-open check and pass on the fixed one.

   Done when you have the function, its `file:line`, the rule as a list of explicit ways in, the named case and the baseline.

2. **Write the named cases.** In the package's `_test.go` file (the existing one when there is one), add `Test<Func>Denies`: a table of literal inputs the rule denies. It holds the named case and its neighbours: the target that could not be resolved (empty ID, zero value), the missing role, another tenant. When no test checks the explicit ways in, add `Test<Func>Allows` with one literal case per way in. Every expected answer comes from the rule, never from running the code.

   Done when every way the named case could be denied has a row, and `go vet ./<pkg>` passes.

3. **Write the property.** In `<file>_fuzz_test.go` next to the check, add `Fuzz<Func>`:
   - Its arguments are the decision's inputs as primitives (`bool`, `string`, `[]byte`, integer and float types), and it builds the function's arguments from them, as the reference builds `User`.
   - `allowed` states the rule's ways in from step 1, written from the rule, never by calling or copying the code under test.
   - It fails only when the check grants what is not allowed: `t.Fatalf("granted: %+v on %q", ...)` with the inputs.
   - Its one seed (`f.Add`) is a case the rule allows. The fuzzer finds the denied cases; the named cases from step 2 already hold the case you know.

   Done when `go vet ./<pkg>` passes.

4. **Run it.** From the module directory, run:

   ```sh
   go test -run '^Test<Func>(Allows|Denies)$' ./<pkg>
   go test -run '^$' -fuzz '^Fuzz<Func>$' -fuzztime 60s ./<pkg>
   ```

   Use the user's fuzz budget when they give one. Check every `granted:` input against the rule by hand: the rule must deny it. If the rule allows it, the oracle is wrong; fix `allowed` and run again. Then read the result for the hypothesis:
   - **Reproduced**: the named case fails, or a `granted:` input is an instance of the hypothesis (the same kind of caller reaching the same kind of target).
   - **Not reproduced**: the named case passes, and no `granted:` input is an instance of the hypothesis.

   Every other `granted:` input is a different bug the rule also forbids: report it under **Also found**, with its input, whatever the result. The fuzzer stops at its first failure, so it may find one of these before the hypothesis; the named case decides the result.
   - A build error, or a failure in the test code itself: fix the test and run again.
   - A panic inside the code under test: report it with its input under Also found, as a crash.

   A failing fuzz run writes its input to `<pkg>/testdata/fuzz/Fuzz<Func>/`. Keep that file: plain `go test` replays it on every run, so the regression is caught without fuzzing.

   Done when the result is Reproduced or Not reproduced, with the commands and the output lines that show it.

5. **Report** in the chat, in this shape:

   ```
   ## verify-with-fuzz: <hypothesis>

   Result: Reproduced | Not reproduced
   Check: <func> (<file:line>), rule: <the explicit ways in>
   Evidence: <the failing test and its `granted:` line with the input>, or <the named case passing, the commands run, the fuzz budget>
   Also found: <each other `granted:` input and the rule it breaks>, or none
   Tests kept: <files>, run with <the step 4 commands>
   ```

   - Reproduced: the fix is a separate change the user confirms. These tests are its evidence, and they go green once it lands.
   - Not reproduced: say the hypothesis did not reproduce within the budget, so there is no fix to suggest for it. Its tests stay as regression tests of the rule.
   - Also found: each entry is a bug with its evidence already in these tests, fixed the same way as a reproduced one.

   Done when every field is filled, and `git status --porcelain` shows the baseline plus only the test files and fuzz inputs you wrote.

## After a fix

When a fix to the check lands, by the user or by `go-security-audit` after the user confirms it, run the step 4 commands unchanged, then `go test ./<pkg>`. The fix is verified when all of them pass. When one fails, report the input that is still granted: the fix is incomplete. The tests stay either way.
