package authz

import "testing"

func TestCanManageOrgAllows(t *testing.T) {
	super := User{IsSuperAdmin: true}
	admin := User{IsOrgAdmin: true, OrgID: "acme"}

	if !CanManageOrg(super, "acme") {
		t.Error("super admin denied")
	}
	if !CanManageOrg(admin, "acme") {
		t.Error("org admin denied on their own org")
	}
}

// Test who must stay out, not only who gets in.
func TestCanManageOrgDenies(t *testing.T) {
	viewer := User{OrgID: "acme"}
	admin := User{IsOrgAdmin: true, OrgID: "acme"}
	super := User{IsSuperAdmin: true}

	cases := []struct {
		name string
		u    User
		org  string
	}{
		{"member without admin role", viewer, "acme"},
		{"admin of another org", admin, "globex"},
		{"org not resolved", admin, ""},
		{"super admin, org not resolved", super, ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if CanManageOrg(c.u, c.org) {
				t.Errorf("granted: %+v on %q", c.u, c.org)
			}
		})
	}
}
