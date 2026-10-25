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
