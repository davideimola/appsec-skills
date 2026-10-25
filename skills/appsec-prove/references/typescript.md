# TypeScript: fast-check

Where the tests go, what they are called, the commands and the budget for a check in TypeScript or JavaScript, then the proven example to copy.

## Files and names

- **Test runner**: the repo's own. The commands and the example use vitest; with jest, run `npx jest` instead and drop the `vitest` import (`test`, `describe`, `expect` are globals). Never add a runner the repo does not have.
- **Property library**: `fast-check`. When the repo lacks it, add it as an exact-version dev dependency with the repo's package manager (`npm i -D -E fast-check`, `pnpm add -D -E fast-check`, `yarn add -D -E fast-check`) and name it in the report: it is the one change outside test files.
- **Named cases**: in `<file>.test.ts` next to the check (append to the existing one when there is one, keeping its tests), a `describe("<func> denies")` group of literal inputs the rule denies, and a `describe("<func> allows")` group with a case for each way in that no existing test covers. A granted denied case fails with `expect.fail` and a `granted:` message.
- **Property**: in `<file>.prop.test.ts`, one `fc.assert(fc.property(...))`. Its inputs are primitive arbitraries (`fc.boolean()`, `fc.string()`, `fc.integer()`, `fc.constantFrom(...)` for a union such as a role), and it throws `granted:` with the inputs.
- **Relations**: fast-check generates at random and is not coverage-guided, so two independent `fc.string()` values are almost never equal and a rule that compares IDs is never exercised on its equal branch. For each relation the rule depends on (same org, same owner), add a `fc.boolean()` that makes one input equal to the other, as `sameOrg` and `isOwner` do in the example. Measured on the fixture: with independent strings, the member-instead-of-admin bug was caught in 1 of 30 runs and the empty-ID bug in 23 of 30; with the two relations, each in 30 of 30.
- **Seed**: none. `examples` starts empty and holds the inputs a failing run finds.
- **Compile check**: the repo's type check (`npx tsc --noEmit`, or its `typecheck` script).

## Commands

From the package directory:

```sh
npx vitest run <dir>/<file>.test.ts
npx vitest run <dir>/<file>.prop.test.ts
```

- **Budget**: fast-check runs `numRuns` random cases, 100 by default; for the user's budget, set `numRuns` in the `fc.assert` options. Never set it to `0`: that skips the kept examples too.
- **Kept input**: a failing run prints `Counterexample: [...]`, already shrunk. Paste it into the property's `examples` list as a literal array: fast-check replays it first on every run, so the regression is caught whatever the random seed. A non-empty list of mixed types needs a tuple type matching the property's arguments, for example `examples: [["", "acme", "viewer", "acme", "", false, false]] as [string, string, Role, string, string, boolean, boolean][]`, where the union arbitrary's element is named by its type.
- **Crash**: an exception thrown by the code under test, other than the property's own `granted:`, is reported with its input.
- **After a fix**: the two commands above unchanged, then `npx vitest run <dir>`.

## Example: a deny-by-default authorization check and its property

This is the shape to copy for a hypothesis about who may do what. It is the authorization pair this repo's CI proves: the property below fails on the vulnerable version and passes on the fixed one, and the files are quoted here byte for byte.

The fixed and vulnerable versions sit side by side only so this repo's CI can prove the property; in the target repo, today's code is the only version, and the tests simply go red on it.

The check takes a `Caller` (`id`, `orgId`, `role`: viewer, member or admin) and a `Project` (`orgId`, and `ownerId` once assigned), and answers whether that caller may edit the project.

### The fixed check

Two explicit ways in, the owner and an admin of the project's organization; a deny-all condition, a project with no organization; and no owner way in while the project is unassigned.

<!-- fixture: src/authz/authz.ts -->
```ts
import type { Caller, Project } from "./project.js";

/**
 * Reports whether c may edit p.
 *
 * Two explicit ways in: the project's owner, or an admin of the project's
 * organization. A project with no organization (orgId === "") is denied to
 * everyone, and a project with no owner yet (ownerId === "") has no owner way
 * in. Everything else is denied.
 */
export function canEditProject(c: Caller, p: Project): boolean {
  if (p.orgId === "") {
    return false;
  }
  if (c.role === "admin" && c.orgId === p.orgId) {
    return true;
  }
  return p.ownerId !== "" && c.id === p.ownerId;
}
```

### The bug the property must catch

The vulnerable version has two bugs. On an unassigned project, the owner check matches any caller with no ID, because two empty IDs are equal. And it lets any member of the organization in where the admin role is required. Every case of who gets in still passes on it, which is why a test of who gets in proves nothing here.

<!-- fixture: src/authz/authz.vulnerable.ts -->
```ts
import type { Caller, Project } from "./project.js";

/**
 * The vulnerable version of the check in authz.ts, kept so CI can prove the
 * property catches it. vitest swaps it in for authz.ts only when run with
 * VULNERABLE=1 (see vitest.config.ts); nothing imports it directly.
 *
 * It has the two bugs the deny-by-default version fixes: on a project with no
 * owner yet, the owner check matches any caller with no id ("" === ""), and it
 * lets any non-viewer of the organization in where the admin role is required.
 */
export function canEditProject(c: Caller, p: Project): boolean {
  if (p.orgId === "") {
    return false;
  }
  if (c.role !== "viewer" && c.orgId === p.orgId) {
    return true;
  }
  return c.id === p.ownerId;
}
```

### The named cases: who gets in, and who must be denied

Each case is a literal caller and project with a known answer, written from the rule, never computed the way the code computes it. The deny cases cover each way in missing one condition, the caller with no id on an unassigned project, and the deny-all condition on each way in. On the vulnerable version the allows group passes and the denies group fails.

<!-- fixture: src/authz/authz.test.ts -->
```ts
import { describe, expect, test } from "vitest";
import { canEditProject } from "./authz.js";
import type { Caller, Project } from "./project.js";

const project: Project = { id: "p1", orgId: "acme", ownerId: "u1" };
const unassigned: Project = { id: "p2", orgId: "acme", ownerId: "" };
const orgless: Project = { id: "p3", orgId: "", ownerId: "u1" };

describe("canEditProject allows", () => {
  test.each<{ name: string; c: Caller; p: Project }>([
    { name: "owner", c: { id: "u1", orgId: "acme", role: "viewer" }, p: project },
    { name: "admin of the project's org", c: { id: "u2", orgId: "acme", role: "admin" }, p: project },
    { name: "admin of the org, project unassigned", c: { id: "u2", orgId: "acme", role: "admin" }, p: unassigned },
  ])("$name", ({ c, p }) => {
    if (!canEditProject(c, p)) {
      expect.fail(`denied: ${JSON.stringify(c)} on ${JSON.stringify(p)}`);
    }
  });
});

// Test who must stay out, not only who gets in.
describe("canEditProject denies", () => {
  test.each<{ name: string; c: Caller; p: Project }>([
    { name: "member of the org, not the owner", c: { id: "u3", orgId: "acme", role: "member" }, p: project },
    { name: "viewer of the org, not the owner", c: { id: "u3", orgId: "acme", role: "viewer" }, p: project },
    { name: "admin of another org", c: { id: "u4", orgId: "globex", role: "admin" }, p: project },
    { name: "caller with no id, project unassigned", c: { id: "", orgId: "acme", role: "viewer" }, p: unassigned },
    { name: "owner, project with no org", c: { id: "u1", orgId: "", role: "viewer" }, p: orgless },
    { name: "admin with no org, project with no org", c: { id: "u2", orgId: "", role: "admin" }, p: orgless },
  ])("$name", ({ c, p }) => {
    if (canEditProject(c, p)) {
      expect.fail(`granted: ${JSON.stringify(c)} on ${JSON.stringify(p)}`);
    }
  });
});
```

### The property: inputs nobody thought of

- Its inputs are the check's inputs as primitive arbitraries, the role from `fc.constantFrom`, plus `sameOrg` and `isOwner`, the two relations the rule depends on.
- `allowed` states the rule's explicit ways in, each carrying the deny-all condition (a project with no organization), the same rule the doc comment of the fixed check states. It is written from the rule, never by calling or copying the code under test.
- It fails only in the deny direction: granted while not allowed.
- On the vulnerable version it fails on every seed CI tries, and the counterexample it prints, kept in `examples`, fails the very first run.

<!-- fixture: src/authz/authz.prop.test.ts -->
```ts
import fc from "fast-check";
import { test } from "vitest";
import { canEditProject } from "./authz.js";
import type { Caller, Project, Role } from "./project.js";

// The deny-by-default property on inputs nobody thought of. The table tests
// cover the cases we know; this covers the rest.
//
// fast-check generates at random, unlike Go's coverage-guided fuzzer, so two
// arbitrary strings almost never collide. The rule depends on two relations,
// the caller's org against the project's and the caller's id against the
// owner's, so each is generated directly: sameOrg and isOwner make them equal.
test("canEditProject grants only what the rule allows", () => {
  fc.assert(
    fc.property(
      fc.string(),
      fc.string(),
      fc.constantFrom<Role>("viewer", "member", "admin"),
      fc.string(),
      fc.string(),
      fc.boolean(),
      fc.boolean(),
      (callerId, callerOrg, role, projectOrg, ownerId, sameOrg, isOwner) => {
        const c: Caller = { id: isOwner ? ownerId : callerId, orgId: sameOrg ? projectOrg : callerOrg, role };
        const p: Project = { id: "p", orgId: projectOrg, ownerId };
        const allowed =
          p.orgId !== "" && ((c.role === "admin" && c.orgId === p.orgId) || (p.ownerId !== "" && c.id === p.ownerId));

        if (canEditProject(c, p) && !allowed) {
          throw new Error(`granted: ${JSON.stringify(c)} on ${JSON.stringify(p)}`);
        }
      },
    ),
    {
      // Counterexamples found by a failing run, kept as regression cases:
      // fast-check replays them first on every run.
      examples: [],
    },
  );
});
```
