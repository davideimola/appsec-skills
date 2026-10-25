// Package authz decides who may do what. Every check denies by default:
// access is granted only by an explicit rule, never by falling through.
//
// authz.go holds the deny-by-default checks. authz_vulnerable.go holds a
// vulnerable version of the same checks, built only with `-tags vulnerable`,
// so CI can prove the fuzz property finds the bugs it fixes.
package authz

// Role is what a caller may do inside their organization.
type Role string

const (
	RoleViewer Role = "viewer"
	RoleMember Role = "member"
	RoleAdmin  Role = "admin"
)

// Caller is the authenticated caller. ID is "" when the request carries no
// user, such as a service token.
type Caller struct {
	ID    string
	OrgID string
	Role  Role
}

// Project belongs to an organization and, once assigned, to an owner.
type Project struct {
	ID      string
	OrgID   string
	OwnerID string // "" while the project is unassigned
}
