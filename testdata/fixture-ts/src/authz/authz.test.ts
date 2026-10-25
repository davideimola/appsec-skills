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
