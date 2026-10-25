# Feasibility: `verify-with-fuzz` beyond Go (TypeScript)

Step 1 of the plan in #20: can the prove loop (named cases and a property that fail on today's code, a kept failing input, the same tests passing after the fix) work in a second ecosystem, with the same ADR 0002 bar?

**Result: yes**, with one TypeScript-specific rule (generators must produce relations) and one method fix that applies to Go too (deny-all conditions).

## What was built

- `testdata/fixture-ts/`: `canManageOrg` in TypeScript, the fixed version and a vulnerable one side by side, with the same named cases and a fast-check property (vitest, fast-check 4.10.2, TypeScript 7.0.2, all pinned in `package-lock.json`). `VULNERABLE=1` makes vitest resolve the vulnerable module, the equivalent of `-tags vulnerable` (ADR 0008).
- `scripts/ci/check-ts-property-catches-vulnerable.sh`, run by the `ts-property` job in `checks.yml`: on the vulnerable version the property fails on 10 of 10 random seeds, the denies cases fail and the allows cases pass; the printed counterexample, kept in `examples`, fails the first run; on the fixed version everything passes, the kept example included.
- A language-neutral draft of `verify-with-fuzz` with a Go and a TypeScript reference, used for the blind runs below. It is not kept in the repo: the TypeScript reference lands in `skills/appsec-prove/` with the TypeScript pack, once CI checks it against the fixture.

## Findings

1. **Keeping the failing input maps cleanly.** fast-check prints a shrunk `Counterexample: [...]`; pasted into the property's `examples`, it is replayed first on every run (`Property failed after 1 tests`), like Go's `testdata/fuzz/` file. Two traps, now in the reference: `numRuns: 0` skips the examples too, and a non-empty mixed-type `examples` list needs a tuple type to type-check.
2. **Generators must produce the relations the rule depends on.** fast-check is random, not coverage-guided. With two independent `fc.string()` org IDs, the membership-instead-of-admin bug alone was caught in **0 of 30** runs; with a mixed pool of fixed IDs, 26 of 30; with a `sameOrg` boolean that makes the target the user's org, **50 of 50** for each bug alone and both together. Go's fuzzer finds string equality on its own, so the Go reference never needed this.
3. **Blind test, first run.** A fresh agent with only the draft skill, on a different check (`canEditProject`: a role union, two relations, three bugs), reproduced the hypothesis and one more bug, and its tests were correct before and after a fix. But its oracle applied "a project with no organization is denied to everyone" to the admin way in only: **an incomplete fix (the owner can still edit an org-less project) passed all its tests, 0 of 20 property runs failed.** This is a method gap, not a TypeScript one; `verify-with-fuzz` has it too.
4. **Fix and blind retest.** The draft now asks for the rule's deny-all conditions separately, carried on every way in, with a denied case per condition and way in, and a case per unresolvable identifier of the target and the caller. A fresh agent on a clean copy found all three bugs; the incomplete fix now fails (2 named cases, and the property on 20 of 20 runs), and the complete fix passes.

## Next

- Finding 3's fix landed in `verify-with-fuzz` (#25), now `appsec-prove`.
- With the TypeScript pack (#20): add the TypeScript reference to `skills/appsec-prove/`, extend `check-reference-examples.sh` to `ts` fences and `testdata/fixture-ts`, and make `check-logic-fix-loop.sh` run the TypeScript commands too.
- The fixture is not in Dependabot or in the weekly security run, because `.github/dependabot.yml` and `security.yml` must stay byte-identical to the Go assets. Deciding how a pack's fixture is kept up to date is part of the split.
