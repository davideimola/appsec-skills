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
