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
- **Repo conventions**: name the files with the repo's own test suffix (`.spec.ts` where its tests are `*.spec.ts`; the commands below then use that suffix), and run the repo's formatter or linter (biome, eslint, prettier, as its scripts or config name it) on the new files only.

## Commands

From the package directory:

```sh
npx vitest run <dir>/<file>.test.ts
npx vitest run <dir>/<file>.prop.test.ts
```

- **Budget**: fast-check runs `numRuns` random cases, 100 by default; for the user's budget, set `numRuns` in the `fc.assert` options. Never set it to `0`: that skips the kept examples too.
- **Kept input**: a failing run prints `Counterexample: [...]`, already shrunk. Paste it into the property's `examples` list as a literal array: fast-check replays it first on every run, so the regression is caught whatever the random seed. Declare the property's arguments once as a tuple type, `type Example = [...]`, and write `examples: [] as Example[]`, so a kept counterexample type-checks.
- **Crash**: an exception thrown by the code under test, other than the property's own `granted:`, is reported with its input.
- **After a fix**: the two commands above unchanged, then `npx vitest run <dir>`.

## When the decision is not one function

In a real service the decision is often spread out: a guard (middleware, a GraphQL directive, a decorator) checks the role, the handler asks a service who owns what, and then it writes. Test it as a caller meets it:

- **Entry point**: call the handler wrapped with its guards, built the way the app builds it (its schema with directives applied, its router, its wrapper), never the bare handler: the bare handler skips the guard.
- **Services**: fake each service the decision reads with an in-memory world the property generates (which org owns which project, which customers a group holds). The world is test data: `allowed` reads the world, never the code under test or a real service.
- **Granted**: the protected effect reached its sink, the store, backend client or queue the handler writes to, as the fake records it. A refusal is the error the app throws for it; any other error is a crash.
- **Lists**: for a bulk action, generate the list with one relation per item, and ids by index when the rule never reads them. The rule says whether one item it denies refuses the whole request.
- **Unresolved identifiers**: only the ones the rule reads, such as the caller's organization, not a ticket id it never checks.
- **Guarded cases**: a denied case the guard already denies passes on today's code. Keep it: it keeps the guard.

Example 2 below is this shape.

## Example 1: a deny-by-default authorization check and its property

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

// The property's arguments, as a tuple, so kept examples type-check.
type Example = [string, string, Role, string, string, boolean, boolean];

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
      examples: [] as Example[],
    },
  );
});
```

## Example 2: a bulk handler behind a guard, with a faked service

The same shape for a decision spread over a guard, a service and a write. `requireAdmin` is the guard; `archiveProjects` asks the directory which organization owns each project and archives the list. The rule: an admin archives only projects their own organization owns, a caller with no organization or one unknown or foreign project refuses the whole request.

The guard and the services the handler receives:

<!-- fixture: src/authz/projects-service.ts -->
```ts
import type { Caller } from "./project.js";

/** The service that knows which organization owns a project. */
export interface Directory {
  /** The owning organization's id, or undefined for an unknown project. */
  projectOrg(projectId: string): Promise<string | undefined>;
}

/** Where archived projects end up: the effect the check protects. */
export interface Store {
  archive(projectIds: string[]): Promise<void>;
}

/** What every handler receives. caller is undefined for an anonymous request. */
export interface Ctx {
  caller: Caller | undefined;
  directory: Directory;
  store: Store;
}

export class Forbidden extends Error {}

type Handler<A extends unknown[]> = (ctx: Ctx, ...args: A) => Promise<void>;

/** The guard in front of admin-only handlers: the role check lives here, not in the handler. */
export function requireAdmin<A extends unknown[]>(handler: Handler<A>): Handler<A> {
  return async (ctx, ...args) => {
    if (ctx.caller?.role !== "admin") {
      throw new Forbidden("admin required");
    }
    return handler(ctx, ...args);
  };
}
```

### The fixed handler

<!-- fixture: src/authz/archive.ts -->
```ts
import { type Ctx, Forbidden, requireAdmin } from "./projects-service.js";

/**
 * Archives projects in bulk, behind the admin guard.
 *
 * The rule: an admin may archive only projects their own organization owns,
 * as the directory says. A caller with no organization, or one unknown or
 * foreign project in the list, refuses the whole request: a bulk write is
 * never applied to the allowed part only.
 */
export const archiveProjects = requireAdmin(async (ctx: Ctx, projectIds: string[]) => {
  const orgId = ctx.caller?.orgId ?? "";
  if (orgId === "") {
    throw new Forbidden("no organization");
  }
  for (const id of projectIds) {
    if ((await ctx.directory.projectOrg(id)) !== orgId) {
      throw new Forbidden(`project ${id} is not in ${orgId}`);
    }
  }
  await ctx.store.archive(projectIds);
});
```

### The bug the property must catch

It asks the directory and discards the answer, so an admin archives any organization's projects. This is the bug of a real resolver that called its scoping helper and ignored the result. The guard still denies a member or an anonymous request, which is why those named cases pass on it.

<!-- fixture: src/authz/archive.vulnerable.ts -->
```ts
import type { Ctx } from "./projects-service.js";
import { requireAdmin } from "./projects-service.js";

/**
 * The vulnerable version of the handler in archive.ts, kept so CI can prove
 * the property catches it. vitest swaps it in for archive.ts only when run
 * with VULNERABLE=1 (see vitest.config.ts); nothing imports it directly.
 *
 * It asks the directory who owns each project and then discards the answer,
 * so an admin archives any organization's projects, and a caller with no
 * organization is never refused.
 */
export const archiveProjects = requireAdmin(async (ctx: Ctx, projectIds: string[]) => {
  await Promise.all(projectIds.map((id) => ctx.directory.projectOrg(id)));
  await ctx.store.archive(projectIds);
});
```

### The named cases

The directory is faked with a fixed world, and "granted" is what reached the store.

<!-- fixture: src/authz/archive.test.ts -->
```ts
import { describe, expect, test } from "vitest";
import { archiveProjects } from "./archive.js";
import type { Caller } from "./project.js";
import { type Ctx, Forbidden } from "./projects-service.js";

// The directory is faked with an in-memory world: which org owns which project.
const owners = new Map<string, string>([
  ["p-acme", "acme"],
  ["p-acme-2", "acme"],
  ["p-globex", "globex"],
]);

/** Runs the guarded handler and returns what reached the store; a Forbidden refusal reaches nothing. */
async function archived(caller: Caller | undefined, projectIds: string[]): Promise<string[]> {
  const stored: string[] = [];
  const ctx: Ctx = {
    caller,
    directory: { projectOrg: async (id) => owners.get(id) },
    store: { archive: async (ids) => void stored.push(...ids) },
  };
  try {
    await archiveProjects(ctx, projectIds);
  } catch (err) {
    if (!(err instanceof Forbidden)) {
      throw err;
    }
  }
  return stored;
}

const admin: Caller = { id: "u1", orgId: "acme", role: "admin" };

describe("archiveProjects allows", () => {
  test("admin archiving their org's projects", async () => {
    expect(await archived(admin, ["p-acme", "p-acme-2"])).toEqual(["p-acme", "p-acme-2"]);
  });
});

// Test who must stay out, not only who gets in. A guard already denies some of
// these on today's code; they stay, so the guard stays.
describe("archiveProjects denies", () => {
  test.each<{ name: string; caller: Caller | undefined; ids: string[] }>([
    { name: "admin archiving another org's project", caller: admin, ids: ["p-globex"] },
    { name: "admin mixing their project with another org's", caller: admin, ids: ["p-acme", "p-globex"] },
    { name: "admin archiving an unknown project", caller: admin, ids: ["p-missing"] },
    { name: "admin with no organization", caller: { id: "u2", orgId: "", role: "admin" }, ids: ["p-acme"] },
    { name: "member of the org", caller: { id: "u3", orgId: "acme", role: "member" }, ids: ["p-acme"] },
    { name: "anonymous request", caller: undefined, ids: ["p-acme"] },
  ])("$name", async ({ caller, ids }) => {
    const stored = await archived(caller, ids);
    if (stored.length > 0) {
      expect.fail(`granted: ${JSON.stringify(caller)} archived ${JSON.stringify(stored)}`);
    }
  });
});
```

### The property

The property generates the caller, the role, and one relation per requested project: owned by the caller's organization, by another, or unknown to the directory. The world is built from them, and `allowed` reads the world.

<!-- fixture: src/authz/archive.prop.test.ts -->
```ts
import fc from "fast-check";
import { test } from "vitest";
import { archiveProjects } from "./archive.js";
import type { Caller, Role } from "./project.js";
import { type Ctx, Forbidden } from "./projects-service.js";

// The property's arguments, as a tuple, so kept examples type-check.
type Example = [string, Role, string, ("caller" | "other" | "unknown")[]];

// The deny-by-default property for a bulk handler behind a guard, with the
// directory faked by a world the property generates. Each requested project
// carries its relation to the caller ("caller", "other" or "unknown" owner),
// so the generator reaches every branch the rule depends on; ids are p0, p1…
// because the rule never reads them. "Granted" means the store was reached.
test("archiveProjects archives only what the rule allows", async () => {
  await fc.assert(
    fc.asyncProperty(
      fc.string(),
      fc.constantFrom<Role>("viewer", "member", "admin"),
      fc.string(),
      fc.array(fc.constantFrom("caller" as const, "other" as const, "unknown" as const), { maxLength: 4 }),
      async (callerOrg, role, otherOrg, owned) => {
        const caller: Caller = { id: "u", orgId: callerOrg, role };
        const ids = owned.map((_, i) => `p${i}`);
        const world = new Map<string, string | undefined>(
          owned.map((o, i) => [ids[i], o === "caller" ? callerOrg : o === "other" ? otherOrg : undefined]),
        );
        const allowed = role === "admin" && callerOrg !== "" && ids.every((id) => world.get(id) === callerOrg);

        const stored: string[] = [];
        const ctx: Ctx = {
          caller,
          directory: { projectOrg: async (id) => world.get(id) },
          store: { archive: async (archived) => void stored.push(...archived) },
        };
        try {
          await archiveProjects(ctx, ids);
        } catch (err) {
          if (!(err instanceof Forbidden)) {
            throw err;
          }
        }
        if (stored.length > 0 && !allowed) {
          throw new Error(`granted: ${JSON.stringify(caller)} archived ${JSON.stringify(stored)} of ${JSON.stringify([...world])}`);
        }
      },
    ),
    {
      // Counterexamples found by a failing run, kept as regression cases:
      // fast-check replays them first on every run.
      examples: [] as Example[],
    },
  );
});
```
