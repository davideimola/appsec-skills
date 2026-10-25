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
