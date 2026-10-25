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
