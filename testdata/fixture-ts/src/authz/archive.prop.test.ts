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
