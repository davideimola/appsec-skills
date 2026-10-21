//go:build !vulnerable

package authz

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
