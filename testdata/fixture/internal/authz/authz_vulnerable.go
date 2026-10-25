//go:build vulnerable

package authz

// CanEditProject is the vulnerable version of the check in authz.go, kept so
// CI can prove FuzzCanEditProject catches it. It is built only with
// `-tags vulnerable` and never ships in the default build.
//
// It has the two bugs the deny-by-default version fixes: on a project with no
// owner yet, the owner check matches any caller with no ID ("" == ""), and it
// lets any non-viewer of the organization in where the admin role is required.
func CanEditProject(c Caller, p Project) bool {
	if p.OrgID == "" {
		return false
	}
	if c.Role != RoleViewer && c.OrgID == p.OrgID {
		return true
	}
	return c.ID == p.OwnerID
}
