// Package authz decides who may do what. Every check denies by default:
// access is granted only by an explicit rule, never by falling through.
//
// authz.ts holds the deny-by-default checks. authz.vulnerable.ts holds a
// vulnerable version of the same checks, swapped in only when vitest runs
// with VULNERABLE=1, so CI can prove the property finds the bug it fixes.

/** The authenticated caller. */
export interface User {
  isSuperAdmin: boolean;
  isOrgAdmin: boolean;
  orgId: string;
}
