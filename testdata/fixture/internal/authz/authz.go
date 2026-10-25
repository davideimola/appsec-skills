//go:build !vulnerable

package authz

// CanEditProject reports whether c may edit p.
//
// Two explicit ways in: the project's owner, or an admin of the project's
// organization. A project with no organization (OrgID == "") is denied to
// everyone, and a project with no owner yet (OwnerID == "") has no owner way
// in. Everything else is denied.
func CanEditProject(c Caller, p Project) bool {
	if p.OrgID == "" {
		return false
	}
	if c.Role == RoleAdmin && c.OrgID == p.OrgID {
		return true
	}
	return p.OwnerID != "" && c.ID == p.OwnerID
}
