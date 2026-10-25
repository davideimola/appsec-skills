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
