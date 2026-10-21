//go:build tools

// Package tools makes gosec a direct requirement of this module. The tool
// directive in go.mod alone leaves it `// indirect`, and Dependabot's default
// version updates skip indirect requirements, so this import is what lets
// Dependabot bump the gosec version that go-security-audit runs.
package tools

import _ "github.com/securego/gosec/v2/cmd/gosec"
