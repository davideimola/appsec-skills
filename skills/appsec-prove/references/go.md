# Go: native fuzzing

Where the tests go, what they are called, the commands and the budget for a check in Go, then the proven example to copy.

## Files and names

- **Named cases**: in a `_test.go` file of the check's package, the existing one next to the check or a new `<file>_authz_test.go` when that one is about something else: `Test<Func>Denies`, a table of literal inputs the rule denies, and `Test<Func>Allows` with a case for each way in that no existing test covers.
- **Property**: in `<file>_fuzz_test.go` next to the check, `Fuzz<Func>`. Its arguments are primitives only (`bool`, `string`, `[]byte`, integer and float types), and it builds the function's arguments from them, as the example builds `Caller` and `Project`. It fails with `t.Fatalf("granted: %+v on %q", ...)`.
- **Seed**: one `f.Add`, a case the rule allows. The fuzzer is coverage-guided: it finds empty strings on its own, and equal IDs from the values the seed and the code compare.
- **Compile check**: `go vet ./<pkg>`.

## Commands

From the module directory:

```sh
go test -run '^Test<Func>(Allows|Denies)$' ./<pkg>
go test -run '^$' -fuzz '^Fuzz<Func>$' -fuzztime 60s ./<pkg>
```

- **Budget**: `-fuzztime`; use the user's when they give one.
- **Kept input**: a failing fuzz run writes its input to `<pkg>/testdata/fuzz/Fuzz<Func>/`. Keep that file: plain `go test` replays it on every run, so the regression is caught without fuzzing.
- **Crash**: a panic inside the code under test is reported with its input.
- **After a fix**: the two commands above unchanged, then `go test ./<pkg>`.

## When the decision is not one function

In a real service the decision is often spread out: middleware checks the role, the handler asks a service who owns what, and then it writes. Test it as a caller meets it:

- **Entry point**: build the handler the way the app builds it, with its middleware chain, and serve it with `httptest.NewRecorder` and `httptest.NewRequest`, never the bare handler: the bare handler skips the middleware.
- **Services**: fake each interface the decision reads with an in-memory world built from the fuzz arguments. The world is test data: `allowed` reads the world, never the code under test or a real service. Where you have to guess how the real service behaves, write the guess in a comment next to the fake and report it under Assumptions.
- **Granted**: the protected effect reached its sink, the store, client or queue the handler writes to, as the fake records it.
- **Lists**: fuzz arguments are primitives, so encode one relation per item in a `[]byte`, one byte per item, and cap its length. The rule says whether one item it denies refuses the whole request.
- **Unresolved identifiers**: only the ones the rule reads. **Guarded cases**: a denied case the middleware already denies passes on today's code; keep it.

This shape has no proven Go example yet; the TypeScript reference's Example 2 shows it.

## Example: a deny-by-default authorization check and its property

This is the shape to copy for a hypothesis about who may do what. It is the authorization pair this repo's CI proves: the property below fails on the vulnerable version and passes on the fixed one, and the files are quoted here byte for byte.

The fixed and vulnerable versions sit side by side only so this repo's CI can prove the property; in the target repo, today's code is the only version, and the tests simply go red on it.

The check takes a `Caller` (`ID`, `OrgID`, `Role`: viewer, member or admin) and a `Project` (`OrgID`, and `OwnerID` once assigned), and answers whether that caller may edit the project.

### The fixed check

Two explicit ways in, the owner and an admin of the project's organization; a deny-all condition, a project with no organization; and no owner way in while the project is unassigned.

<!-- fixture: internal/authz/authz.go -->
```go
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
```

### The bug the property must catch

The vulnerable version has two bugs. On an unassigned project, the owner check matches any caller with no ID, because two empty IDs are equal. And it lets any member of the organization in where the admin role is required. Every case of who gets in still passes on it, which is why a test of who gets in proves nothing here.

<!-- fixture: internal/authz/authz_vulnerable.go -->
```go
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
```

### The named cases: who gets in, and who must be denied

Each case is a literal caller and project with a known answer, written from the rule, never computed the way the code computes it. The deny cases cover each way in missing one condition, the caller with no ID on an unassigned project, and the deny-all condition on each way in. On the vulnerable version `TestCanEditProjectAllows` passes and `TestCanEditProjectDenies` fails.

<!-- fixture: internal/authz/authz_test.go -->
```go
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
```

### The property: inputs nobody thought of

- It fuzzes the check's inputs as primitives and builds `Caller` and `Project` from them, because a fuzz target takes only primitive arguments. The role is a `uint8` picked from the three roles, the way to fuzz a closed set.
- `allowed` states the rule's explicit ways in, each carrying the deny-all condition (a project with no organization), the same rule the doc comment of the fixed check states. It is written from the rule, never by calling or copying the code under test.
- It fails only in the deny direction: granted while not allowed. That is the direction a fail-open bug takes.
- Its only seed is the happy path, the owner. The fuzzer finds both bugs on its own, each in about a second: `go test -run '^$' -fuzz '^FuzzCanEditProject$' -fuzztime 60s ./internal/authz` prints `granted:` and the input on the vulnerable version, and passes on the fixed one.

<!-- fixture: internal/authz/authz_fuzz_test.go -->
```go
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
```
