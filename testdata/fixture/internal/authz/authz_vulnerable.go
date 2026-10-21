//go:build vulnerable

package authz

// CanManageOrg is the vulnerable version of the check in authz.go, kept so
// CI can prove FuzzCanManageOrg catches it. It is built only with
// `-tags vulnerable` and never ships in the default build.
//
// It has the two bugs the deny-by-default version fixes: it fails open when
// the target organization could not be resolved (orgID == ""), and it checks
// membership of the organization where the admin role is required.
func CanManageOrg(u User, orgID string) bool {
	if orgID == "" {
		return true
	}
	if u.IsSuperAdmin {
		return true
	}
	return u.OrgID == orgID
}
