# The vulnerable authorization sits behind a build tag

The fixture holds `CanManageOrg` twice in `internal/authz`: the fixed deny-by-default check in `authz.go` (`//go:build !vulnerable`) and a vulnerable one in `authz_vulnerable.go` (`//go:build vulnerable`) that fails open when the organization can't be resolved and checks membership instead of the admin role. Both share the same name, `User` type and tests, so the one property `FuzzCanManageOrg` runs unchanged against either build. `scripts/ci/check-fuzz-catches-vulnerable.sh` requires it to fail with `-tags vulnerable` and pass without.

## Considered Options

- **A second function (`canManageOrgVulnerable`) and a second fuzz target**: rejected. The canonical workflow's weekly run fuzzes every `Fuzz*` target on the default build, so a target that must fail would break this repo's own security run. It would also mean the property is copied, not the same one.
- **A separate vulnerable package or module**: rejected. The property would have to be duplicated or exported, and the two versions would no longer sit side by side.

## Consequences

- The default build (`go vet`, `go test`, `govulncheck`, gosec, the weekly fuzz) sees only the fixed version, so the canonical workflow stays green on the fixture.
- Anything that wants the vulnerable version (CI, `verify-with-fuzz` and audit evals) builds with `-tags vulnerable`.
- A failing fuzz run writes its input under `testdata/fuzz/` in the package, so the check runs on a temporary copy of the fixture and running it locally never leaves files in the repo. The property must find the bug from its seed alone, with no committed corpus entry helping it.
