---
name: appsec-prove
description: Verifies a security hypothesis about code by writing named test cases and a property over generated inputs that fail on today's code and stay as regression tests. Use when the user suspects an authorization or trust bug (who may do what, which input is trusted) and wants it proven with a failing test, or when an audit needs evidence for a logic finding.
license: MIT
metadata:
  author: davideimola
---

Turn a **hypothesis** into **evidence**: tests in the **target repo** (the repo you are running in) that go red on today's code when the hypothesis holds. You write tests only. The code under test stays exactly as you found it, and the tests stay in the repo as regression tests whatever the result.

The test checks who must be denied, not only who gets in. A fail-open bug passes every test of who gets in.

## Ecosystem

Read the reference for the language of the check before step 2. It holds the proven example to copy, where the files go, the commands, the budget and how a failing input is kept:

| Language | Reference |
|---|---|
| Go | [references/go.md](references/go.md) (native fuzzing) |
| TypeScript, JavaScript | [references/typescript.md](references/typescript.md) (fast-check) |

For another language, say there is no reference for it yet and stop: no proven shape means no evidence you can vouch for.

## Steps

1. **Pin the hypothesis to a check.**
   - Find the function that makes the decision the hypothesis is about, with its `file:line`.
   - Write down the rule it must enforce as its explicit ways in (for example: a super admin, or an admin of that same organization). Take the rule from the function's doc comment, the user or the hypothesis. When they disagree or none states it, ask the user.
   - Write down the rule's **deny-all conditions** separately: anything the rule says denies everyone, whatever the way in (for example: a target with no organization is denied to everyone). Add each one to **every** way in, not only to the way in it reads closest to. A deny-all condition left out of one way in makes the tests accept an incomplete fix.
   - List the **relations** the rule depends on: inputs that must be equal for a way in to apply (the caller's org and the target's org, the caller's ID and the owner's ID).
   - Restate the hypothesis as a named case: a literal input and the answer the rule requires, deny.
   - Baseline: record the output of `git status --porcelain`.

   Done when you have the function, its `file:line`, the rule as a list of explicit ways in each carrying every deny-all condition, its relations, the named case and the baseline.

2. **Write the named cases.** Next to the check, in the file the reference names (append to the existing test file when there is one, keeping its tests), add a group of cases the rule denies. It holds the named case and its neighbours: each identifier of the target **and of the caller** that could be unresolved (empty ID, zero value), one case each, since two unresolved IDs compare equal, the missing role, another tenant, and, for each deny-all condition, a case that meets **each** way in otherwise (for example: the owner, and an admin of the same org, on a target with no organization). When no test checks the explicit ways in, add a group with one literal case per way in. Every expected answer comes from the rule, never from running the code. A denied case that is granted fails with a `granted:` message and the input.

   Done when the denied group has the named case, a case per unresolvable identifier of the target and the caller, a case per deny-all condition and way in, and, for each way in, a case that misses exactly one of its conditions; each way in has an allowed case or an existing test; and the file compiles or type-checks.

3. **Write the property.** In the file the reference names, add a property over generated inputs:
   - Its inputs are the decision's inputs as primitives, plus whatever the reference says the generator needs to reach each relation from step 1.
   - `allowed` states the rule's ways in from step 1, written from the rule, never by calling or copying the code under test.
   - It fails only when the check grants what is not allowed, with a `granted:` message and the inputs.
   - Seeds follow the reference: Go starts from one allowed case (`f.Add`); fast-check needs none, and its `examples` start empty.

   Done when every relation from step 1 is reachable by the generator, `allowed` carries every deny-all condition on every way in, `allowed` calls nothing from the code under test, the only failure is the `granted:` one, and the file compiles or type-checks.

4. **Run it** with the reference's commands. Use the user's budget when they give one. Check every `granted:` input against the rule by hand: the rule must deny it. If the rule allows it, the oracle is wrong; fix `allowed` and run again. Then read the result for the hypothesis:
   - **Reproduced**: the named case fails, or a `granted:` input is an instance of the hypothesis.
   - **Not reproduced**: the named case passes, and no `granted:` input is an instance of the hypothesis.

   Every other `granted:` input is a different bug the rule also forbids: report it under **Also found**. The property stops at its first failure, so it may find one of these before the hypothesis; the named case decides the result. A build error or a failure in the test code itself: fix the test and run again. A crash inside the code under test: report it with its input under Also found.

   Keep each failing input the way the reference says, so the regression is caught on every run without relying on chance.

   Done when the result is Reproduced or Not reproduced, with the commands and the output lines that show it.

5. **Report** in the chat, in this shape:

   ```
   ## appsec-prove: <hypothesis>

   Result: Reproduced | Not reproduced
   Check: <func> (<file:line>), rule: <the explicit ways in>
   Evidence: <the failing test and its `granted:` line with the input>, or <the named case passing, the commands run, the budget>
   Also found: <each other `granted:` input and the rule it breaks>, or none
   Tests kept: <files>, run with <the commands>
   ```

   Done when every field is filled, and `git status --porcelain` shows the baseline plus only the test files and kept inputs you wrote (and any dependency the reference allows you to add, named in the report).

## After a fix

When a fix to the check lands, run the step 4 commands unchanged. The fix is verified when they pass, kept inputs included. When one fails, report the input that is still granted: the fix is incomplete. The tests stay either way.
