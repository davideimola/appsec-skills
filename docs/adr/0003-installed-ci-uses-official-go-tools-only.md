# Installed CI uses official Go tools only

The workflow `go-security-setup` installs uses only official Go tooling: `go mod verify`, `go vet`, `go test`, fuzzing and `golang/govulncheck-action`, plus `actions/checkout` and `actions/setup-go`. Every extra tool in someone else's CI is a dependency they must trust and keep updated. gosec, a third-party SAST tool, is used only inside `go-security-audit`, through `go run github.com/securego/gosec/v2/cmd/gosec@vX.Y.Z`: exact version, verified by the checksum database, never installed and never `@latest`.

## Considered Options

- **golangci-lint with gosec and staticcheck in the installed CI**: rejected for v1. It brings more third-party code and configuration into the user's pipeline.
- **CodeQL**: rejected. It is not Go-specific, and on private repos it requires GitHub Advanced Security.

Superseded in part by ADR 0011: when the owner chooses it, the audit may run gosec from the shell or an MCP tool, and `go-security-setup` calls that tool once to check it. The installed CI is unchanged.
