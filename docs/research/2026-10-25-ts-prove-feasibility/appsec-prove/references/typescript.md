# Reference: TypeScript (vitest + fast-check)

The shape to copy for a hypothesis about who may do what, in a TypeScript repo. It is the authorization pair CI proves: the property below fails on the vulnerable version and passes on the fixed one, and the files are quoted here byte for byte.

The check takes a `User` (`isSuperAdmin`, `isOrgAdmin`, `orgId`) and a target organization ID, and answers whether that user may use the organization's admin-only features.

## Ecosystem facts

- **Test runner**: use the repo's own. The examples use vitest; with jest, drop the `vitest` import (`test`, `describe`, `expect` are globals). Never add a runner the repo does not have.
- **Property library**: `fast-check`. If the repo lacks it, add it as an exact-version dev dependency with the repo's package manager (`npm i -D -E`, `pnpm add -D -E`, `yarn add -D -E`), and say so in the report: it is the one change outside test files.
- **Files**: named cases in `<file>.test.ts` next to the check (the existing one when there is one), the property in `<file>.prop.test.ts`.
- **Commands** (`<runner>` is `npx vitest run` or `npx jest`):

  ```sh
  <runner> <dir>/<file>.test.ts
  <runner> <dir>/<file>.prop.test.ts
  ```

- **Budget**: fast-check runs `numRuns` random cases (100 by default). For the user's budget, set `numRuns` in the `fc.assert` options. Never set it to `0`: that skips the kept examples too.
- **Keeping the failing input**: a failing run prints `Counterexample: [...]`, already shrunk. Paste it, as a literal array, into the property's `examples` list: fast-check replays it first on every run, so the regression is caught whatever the random seed. This is the equivalent of Go's `testdata/fuzz/` file. TypeScript widens a non-empty literal list of mixed types, so type it as a tuple matching the property's arguments, for example `examples: [[false, false, "", "", false]] as [boolean, boolean, string, string, boolean][]`, and run the type check.
- **Generators must produce the relations the rule depends on.** fast-check generates at random and is not coverage-guided: two independent `fc.string()` values are almost never equal, so a rule that compares IDs (same org, same owner) is never exercised on its equal branch. Generate each relation explicitly: a `boolean` that makes one input equal to the other, as `sameOrg` does below. Measured on the fixture: with two independent `fc.string()` org IDs, the membership-instead-of-admin bug was caught in 0 of 30 runs; with `sameOrg`, in 50 of 50.

## The fixed check

<!-- fixture: src/authz/authz.ts -->
```ts
import type { User } from "./user.js";

/**
 * Reports whether u may use admin-only features of orgId.
 *
 * Two explicit ways in: a super admin, or an admin of that same
 * organization. Everything else is denied, including a request whose
 * target organization could not be resolved (orgId === "").
 */
export function canManageOrg(u: User, orgId: string): boolean {
  if (orgId === "") {
    return false;
  }
  if (u.isSuperAdmin) {
    return true;
  }
  return u.isOrgAdmin && u.orgId === orgId;
}
```

## The bug the property must catch

The vulnerable version fails open when the target organization is empty, and checks membership where the admin role is required. Every case of who gets in still passes on it.

<!-- fixture: src/authz/authz.vulnerable.ts -->
```ts
import type { User } from "./user.js";

/**
 * The vulnerable version of the check in authz.ts, kept so CI can prove the
 * property catches it. vitest swaps it in for authz.ts only when run with
 * VULNERABLE=1 (see vitest.config.ts); nothing imports it directly.
 *
 * It has the two bugs the deny-by-default version fixes: it fails open when
 * the target organization could not be resolved (orgId === ""), and it checks
 * membership of the organization where the admin role is required.
 */
export function canManageOrg(u: User, orgId: string): boolean {
  if (orgId === "") {
    return true;
  }
  if (u.isSuperAdmin) {
    return true;
  }
  return u.orgId === orgId;
}
```

## The named cases: who gets in, and who must be denied

<!-- fixture: src/authz/authz.test.ts -->
```ts
import { describe, expect, test } from "vitest";
import { canManageOrg } from "./authz.js";
import type { User } from "./user.js";

describe("canManageOrg allows", () => {
  const superAdmin: User = { isSuperAdmin: true, isOrgAdmin: false, orgId: "" };
  const admin: User = { isSuperAdmin: false, isOrgAdmin: true, orgId: "acme" };

  test("super admin", () => {
    expect(canManageOrg(superAdmin, "acme")).toBe(true);
  });
  test("org admin on their own org", () => {
    expect(canManageOrg(admin, "acme")).toBe(true);
  });
});

// Test who must stay out, not only who gets in.
describe("canManageOrg denies", () => {
  const viewer: User = { isSuperAdmin: false, isOrgAdmin: false, orgId: "acme" };
  const admin: User = { isSuperAdmin: false, isOrgAdmin: true, orgId: "acme" };
  const superAdmin: User = { isSuperAdmin: true, isOrgAdmin: false, orgId: "" };

  test.each([
    { name: "member without admin role", u: viewer, org: "acme" },
    { name: "admin of another org", u: admin, org: "globex" },
    { name: "org not resolved", u: admin, org: "" },
    { name: "super admin, org not resolved", u: superAdmin, org: "" },
  ])("$name", ({ u, org }) => {
    if (canManageOrg(u, org)) {
      expect.fail(`granted: ${JSON.stringify(u)} on ${JSON.stringify(org)}`);
    }
  });
});
```

## The property: inputs nobody thought of

- Its inputs are the decision's inputs as primitive arbitraries (`fc.boolean()`, `fc.string()`, `fc.integer()`, `fc.constantFrom(...)` for a union such as a role), plus one `boolean` per relation the rule depends on.
- `allowed` states the rule's explicit ways in. It is written from the rule, never by calling or copying the code under test.
- It fails only in the deny direction: granted while not allowed, with a `granted:` message.
- `examples` starts empty and holds the counterexamples a failing run finds.

<!-- fixture: src/authz/authz.prop.test.ts -->
```ts
import fc from "fast-check";
import { test } from "vitest";
import { canManageOrg } from "./authz.js";
import type { User } from "./user.js";

// The deny-by-default property on inputs nobody thought of. The table tests
// cover the cases we know; this covers the rest.
//
// fast-check generates at random, unlike Go's coverage-guided fuzzer, so two
// arbitrary strings almost never collide. The rule depends on whether the
// user's org is the target org, so that relation is generated directly:
// sameOrg makes the target the user's own org.
test("canManageOrg grants only what the rule allows", () => {
  fc.assert(
    fc.property(
      fc.boolean(),
      fc.boolean(),
      fc.string(),
      fc.string(),
      fc.boolean(),
      (isSuperAdmin, isOrgAdmin, userOrg, otherOrg, sameOrg) => {
        const u: User = { isSuperAdmin, isOrgAdmin, orgId: userOrg };
        const org = sameOrg ? userOrg : otherOrg;
        const allowed = org !== "" && (isSuperAdmin || (isOrgAdmin && userOrg === org));

        if (canManageOrg(u, org) && !allowed) {
          throw new Error(`granted: ${JSON.stringify(u)} on ${JSON.stringify(org)}`);
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
