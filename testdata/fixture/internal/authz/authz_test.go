package authz

import "testing"

func TestCanEditProjectAllows(t *testing.T) {
	project := Project{ID: "p1", OrgID: "acme", OwnerID: "u1"}
	unassigned := Project{ID: "p2", OrgID: "acme"}

	cases := []struct {
		name string
		c    Caller
		p    Project
	}{
		{"owner", Caller{ID: "u1", OrgID: "acme", Role: RoleViewer}, project},
		{"admin of the project's org", Caller{ID: "u2", OrgID: "acme", Role: RoleAdmin}, project},
		{"admin of the org, project unassigned", Caller{ID: "u2", OrgID: "acme", Role: RoleAdmin}, unassigned},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if !CanEditProject(c.c, c.p) {
				t.Errorf("denied: %+v on %+v", c.c, c.p)
			}
		})
	}
}

// Test who must stay out, not only who gets in.
func TestCanEditProjectDenies(t *testing.T) {
	project := Project{ID: "p1", OrgID: "acme", OwnerID: "u1"}
	unassigned := Project{ID: "p2", OrgID: "acme"}
	orgless := Project{ID: "p3", OwnerID: "u1"}

	cases := []struct {
		name string
		c    Caller
		p    Project
	}{
		{"member of the org, not the owner", Caller{ID: "u3", OrgID: "acme", Role: RoleMember}, project},
		{"viewer of the org, not the owner", Caller{ID: "u3", OrgID: "acme", Role: RoleViewer}, project},
		{"admin of another org", Caller{ID: "u4", OrgID: "globex", Role: RoleAdmin}, project},
		{"caller with no ID, project unassigned", Caller{OrgID: "acme", Role: RoleViewer}, unassigned},
		{"owner, project with no org", Caller{ID: "u1", Role: RoleViewer}, orgless},
		{"admin with no org, project with no org", Caller{ID: "u2", Role: RoleAdmin}, orgless},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if CanEditProject(c.c, c.p) {
				t.Errorf("granted: %+v on %+v", c.c, c.p)
			}
		})
	}
}
