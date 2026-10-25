import type { User } from "./user.js";

/**
 * The vulnerable version of the check in authz.ts, kept so CI can prove the
 * property catches it. vitest swaps it in for authz.ts only when run with
 * VULNERABLE=1 (see vitest.config.ts); nothing imports it directly.
 *
 * It has the two bugs the deny-by-default version fixes: it fails open when
 * the target organization could not be resolved (orgId === ""), and it checks
 * membership of the organization where the admin role is required.
 */
export function canManageOrg(u: User, orgId: string): boolean {
  if (orgId === "") {
    return true;
  }
  if (u.isSuperAdmin) {
    return true;
  }
  return u.orgId === orgId;
}
