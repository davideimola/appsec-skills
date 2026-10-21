package authz

import "testing"

// FuzzCanManageOrg checks the deny-by-default property on inputs nobody
// thought of. The table tests cover the cases we know; this covers the rest.
func FuzzCanManageOrg(f *testing.F) {
	f.Add(false, true, "acme", "acme") // the happy path
	f.Fuzz(func(t *testing.T, super, admin bool, userOrg, org string) {
		u := User{IsSuperAdmin: super, IsOrgAdmin: admin, OrgID: userOrg}
		allowed := org != "" && (super || (admin && userOrg == org))

		if CanManageOrg(u, org) && !allowed {
			t.Fatalf("granted: %+v on %q", u, org)
		}
	})
}
