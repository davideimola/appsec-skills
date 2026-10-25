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
