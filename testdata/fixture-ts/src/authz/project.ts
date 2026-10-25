// Package authz decides who may do what. Every check denies by default:
// access is granted only by an explicit rule, never by falling through.
//
// authz.ts holds the deny-by-default checks. authz.vulnerable.ts holds a
// vulnerable version of the same checks, swapped in only when vitest runs
// with VULNERABLE=1, so CI can prove the property finds the bugs it fixes.

/** What a caller may do inside their organization. */
export type Role = "viewer" | "member" | "admin";

/** The authenticated caller. id is "" when the request carries no user, such as a service token. */
export interface Caller {
  id: string;
  orgId: string;
  role: Role;
}

/** A project belongs to an organization and, once assigned, to an owner. */
export interface Project {
  id: string;
  orgId: string;
  /** "" while the project is unassigned. */
  ownerId: string;
}
