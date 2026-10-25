package authz

import "testing"

var roles = []Role{RoleViewer, RoleMember, RoleAdmin}

// FuzzCanEditProject checks the deny-by-default property on inputs nobody
// thought of. The table tests cover the cases we know; this covers the rest.
func FuzzCanEditProject(f *testing.F) {
	f.Add("u1", "acme", uint8(0), "acme", "u1") // the owner: the happy path
	f.Fuzz(func(t *testing.T, callerID, callerOrg string, role uint8, projectOrg, ownerID string) {
		c := Caller{ID: callerID, OrgID: callerOrg, Role: roles[int(role)%len(roles)]}
		p := Project{ID: "p", OrgID: projectOrg, OwnerID: ownerID}
		allowed := projectOrg != "" &&
			((c.Role == RoleAdmin && callerOrg == projectOrg) || (ownerID != "" && callerID == ownerID))

		if CanEditProject(c, p) && !allowed {
			t.Fatalf("granted: %+v on %+v", c, p)
		}
	})
}
