// Package authz decides who may do what. Every check denies by default:
// access is granted only by an explicit rule, never by falling through.
//
// authz.go holds the deny-by-default checks. authz_vulnerable.go holds a
// vulnerable version of the same checks, built only with `-tags vulnerable`,
// so CI can prove the fuzz property finds the bug it fixes.
package authz

// User is the authenticated caller.
type User struct {
	IsSuperAdmin bool
	IsOrgAdmin   bool
	OrgID        string
}
