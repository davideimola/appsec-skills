---
name: appsec-prove
description: Verifies a security hypothesis about Go or TypeScript code by writing named test cases and a property over generated inputs that fail on today's code and stay as regression tests. Use when the user suspects an authorization or trust bug in Go or TypeScript code (who may do what, which input is trusted) and wants it proven with a failing test, or when appsec-audit needs evidence for a logic finding.
license: MIT
metadata:
  author: davideimola
---

Turn a **hypothesis** into **evidence**: tests in the **target repo** (the repo you are running in) that go red on today's code when the hypothesis holds. You write tests only. The code under test stays exactly as you found it, and the tests stay in the repo as regression tests whatever the result.

The test checks who must be denied, not only who gets in. A fail-open bug passes every test of who gets in.

## Ecosystem

Each step follows the reference for the language of the check: where the tests go and what they are called, the commands, the budget, how a failing input is kept, and the proven example to copy.

| Language | Reference |
|---|---|
| Go | [references/go.md](references/go.md): native fuzzing |
| TypeScript, JavaScript | [references/typescript.md](references/typescript.md): fast-check |

For any other language, tell the user there is no reference for it yet and stop: without a proven shape, the tests are no evidence you can vouch for.

## Steps

1. **Pin the hypothesis to a check.**
   - Find the function that makes the decision the hypothesis is about, with its `file:line`, and read the reference for its language now.
   - Write down the rule it must enforce as its explicit ways in (for example: the resource's owner, or an admin of its organization). Take the rule from the function's doc comment, the user or the hypothesis. When they disagree or none states it, ask the user.
   - Write down the rule's **deny-all conditions** separately: anything the rule says denies everyone, whatever the way in (for example: a resource with no organization is denied even to its owner). Add each one to **every** way in, not only to the way in it reads closest to. A deny-all condition left out of one way in makes the tests accept an incomplete fix.
   - List the **relations** the rule depends on: inputs that must be equal for a way in to apply (the caller's org and the target's org, the caller's ID and the owner's ID).
   - Restate the hypothesis as a named case: a literal input and the answer the rule requires, deny (for example: a member of `acme` who does not own a project of `acme` must be denied).
   - Baseline: record the output of `git status --porcelain`.

   Done when you have the function, its `file:line`, the rule as a list of explicit ways in each carrying every deny-all condition, its relations, the named case and the baseline.

2. **Write the named cases.** In the file and with the names the reference gives, add a group of literal inputs the rule denies. It holds the named case and its neighbours: each identifier of the target and of the caller that could be unresolved (empty ID, zero value), one case each, since two unresolved IDs compare equal; the missing role; another tenant; and, for each deny-all condition, a case that meets each way in otherwise (for example: the owner, and an admin with no organization, on a resource with no organization). When no test checks the explicit ways in, add a group with one literal case per way in. Every expected answer comes from the rule, never from running the code. A denied case that is granted fails with a `granted:` message and the input.

   Done when the denied group has the named case, a case per unresolvable identifier of the target and the caller, a case per deny-all condition and way in, and, for each way in from step 1, a case that misses exactly one of its conditions (the role, the same tenant); each way in has an allowed case or an existing test; and the reference's compile check passes.

3. **Write the property.** In the file and with the name the reference gives, add a property over generated inputs:
   - Its inputs are the decision's inputs as the primitives the reference allows, and it builds the function's arguments from them, as the reference's example does. Every relation from step 1 must be reachable, in the way the reference says.
   - `allowed` states the rule's ways in from step 1, written from the rule, never by calling or copying the code under test.
   - It fails only when the check grants what is not allowed, with a `granted:` message and the inputs.
   - Its seed is what the reference says. The generator finds the denied cases; the named cases from step 2 already hold the case you know.

   Done when every input is a primitive the reference allows, every relation from step 1 is reachable, `allowed` is step 1's ways in, each carrying every deny-all condition, and calls nothing from the code under test, its only failure is the `granted:` one on a grant `allowed` rejects, its seed follows the reference, and the reference's compile check passes.

4. **Run it** with the reference's two commands, the named cases first, then the property. Use the user's budget when they give one, as the reference says. Check every `granted:` input against the rule by hand: the rule must deny it. If the rule allows it, the oracle is wrong; fix `allowed` and run again. Then read the result for the hypothesis:
   - **Reproduced**: the named case fails, or a `granted:` input is an instance of the hypothesis (the same kind of caller reaching the same kind of target).
   - **Not reproduced**: the named case passes, and no `granted:` input is an instance of the hypothesis.

   Every other `granted:` input is a different bug the rule also forbids: report it under **Also found**, with its input, whatever the result. The property stops at its first failure, so it may find one of these before the hypothesis, and one input can break several conditions at once; the named case decides the result.
   - A build error, or a failure in the test code itself: fix the test and run again.
   - A crash inside the code under test: report it with its input under Also found.

   Keep each failing input the way the reference says, so the regression is caught on every run without relying on chance.

   Done when the result is Reproduced or Not reproduced, with the commands and the output lines that show it.

5. **Report** in the chat, in this shape:

   ```
   ## appsec-prove: <hypothesis>

   Result: Reproduced | Not reproduced
   Check: <func> (<file:line>), rule: <the explicit ways in>
   Evidence: <the failing test and its `granted:` line with the input>, or <the named case passing, the commands run, the budget>
   Also found: <each other `granted:` input and the rule it breaks>, or none
   Tests kept: <files>, run with <the step 4 commands>
   ```

   - Reproduced: the fix is a separate change the user confirms. These tests are its evidence, and they go green once it lands.
   - Not reproduced: say the hypothesis did not reproduce within the budget, so there is no fix to suggest for it. Its tests stay as regression tests of the rule.
   - Also found: each entry is a bug with its evidence already in these tests, fixed the same way as a reproduced one.

   Done when every field is filled, and `git status --porcelain` shows the baseline plus only the test files and kept inputs you wrote, and any dependency the reference lets you add, named in the report.

## After a fix

When a fix to the check lands, by the user or by `appsec-audit` after the user confirms it, run the reference's After a fix commands: the step 4 commands unchanged, then the whole package's tests. The fix is verified when all of them pass, kept inputs included. When one fails, report the input that is still granted: the fix is incomplete. The tests stay either way.
