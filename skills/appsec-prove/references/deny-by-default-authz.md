# Reference example: a deny-by-default authorization check and its property

This is the shape to copy for a hypothesis about who may do what. It is the authorization pair this repo's CI proves: the property below fails on the vulnerable version and passes on the fixed one, and the files are quoted here byte for byte.

The check takes a `User` (`IsSuperAdmin`, `IsOrgAdmin`, `OrgID`) and a target organization ID, and answers whether that user may use the organization's admin-only features.

## The fixed check

Two explicit ways in, and everything else is denied, including a target that could not be resolved (`orgID == ""`).

<!-- fixture: internal/authz/authz.go -->
```go
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
```

## The bug the property must catch

The vulnerable version fails open when the target organization is empty, and checks membership where the admin role is required. Every case of who gets in still passes on it, which is why a test of who gets in proves nothing here.

<!-- fixture: internal/authz/authz_vulnerable.go -->
```go
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
```

## The named cases: who gets in, and who must be denied

Each case is a literal user and organization with a known answer, written from the rule, never computed the way the code computes it. The deny cases are the hypothesis stated as tests: on the vulnerable version `TestCanManageOrgAllows` passes and `TestCanManageOrgDenies` fails.

<!-- fixture: internal/authz/authz_test.go -->
```go
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
```

## The property: inputs nobody thought of

- It fuzzes the check's inputs as primitives (`bool`, `string`) and builds the `User` from them, because a fuzz target takes only primitive arguments.
- `allowed` states the rule's explicit ways in, the same rule the doc comment of the fixed check states. It is written from the rule, never by calling or copying the code under test.
- It fails only in the deny direction: granted while not allowed. That is the direction a fail-open bug takes.
- Its only seed is the happy path. The fuzzer finds the denied cases on its own, in seconds: `go test -run '^$' -fuzz '^FuzzCanManageOrg$' -fuzztime 60s ./internal/authz` prints `granted:` and the input on the vulnerable version, and passes on the fixed one.

<!-- fixture: internal/authz/authz_fuzz_test.go -->
```go
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
```
