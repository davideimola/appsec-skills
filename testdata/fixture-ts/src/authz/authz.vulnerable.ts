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
