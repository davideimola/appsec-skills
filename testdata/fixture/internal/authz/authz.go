// Package authz decides who may do what. Every check denies by default:
// access is granted only by an explicit rule, never by falling through.
package authz

// User is the authenticated caller.
type User struct {
	IsSuperAdmin bool
	IsOrgAdmin   bool
	OrgID        string
}

// CanManageOrg reports whether u may use admin-only features of orgID.
//
// Two explicit ways in: a super admin, or an admin of that same
// organization. Everything else is denied, including a request whose
// target organization could not be resolved (orgID == "").
func CanManageOrg(u User, orgID string) bool {
	if orgID == "" {
		return false
	}
	if u.IsSuperAdmin {
		return true
	}
	return u.IsOrgAdmin && u.OrgID == orgID
}
