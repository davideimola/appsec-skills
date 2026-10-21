//go:build tools

// Package tools makes the scanners go-security-audit runs from the shell, gosec
// and govulncheck, direct requirements of this module. The tool directives in
// go.mod alone leave them `// indirect`, and Dependabot's default version
// updates skip indirect requirements, so these imports are what let Dependabot
// bump the versions the audit runs.
package tools

import (
	_ "github.com/securego/gosec/v2/cmd/gosec"
	_ "golang.org/x/vuln/cmd/govulncheck"
)
