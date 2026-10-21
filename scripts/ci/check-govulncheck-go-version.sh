#!/usr/bin/env bash
# Proves the canonical security workflow scans with the Go toolchain the module
# builds with. setup-go installs the toolchain its go.mod selects (the
# `toolchain` line when there is one), but govulncheck-action runs its own
# setup-go: given the go.mod, that one resolves the `go` line, so a module with
# `go 1.26.0` and `toolchain go1.26.10` would be scanned against go1.26.0 and
# report standard library vulnerabilities its toolchain has fixed. So:
#   1. the job's setup-go step reads the module's go.mod and has an id;
#   2. the govulncheck step comes after it and takes that step's go-version
#      output as go-version-input, and passes no go-version-file of its own.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

asset=$workflow_asset
steps='.jobs.security.steps'

setup_count=$(yq "[$steps[] | select((.uses // \"\") | test(\"^actions/setup-go@\"))] | length" "$asset")
[ "$setup_count" -eq 1 ] || die "$asset must have exactly one actions/setup-go step, found $setup_count"
vuln_count=$(yq "[$steps[] | select((.uses // \"\") | test(\"^golang/govulncheck-action@\"))] | length" "$asset")
[ "$vuln_count" -eq 1 ] || die "$asset must have exactly one golang/govulncheck-action step, found $vuln_count"

setup_index=$(yq "$steps | to_entries | .[] | select((.value.uses // \"\") | test(\"^actions/setup-go@\")) | .key" "$asset")
vuln_index=$(yq "$steps | to_entries | .[] | select((.value.uses // \"\") | test(\"^golang/govulncheck-action@\")) | .key" "$asset")
[ "$setup_index" -lt "$vuln_index" ] || die "the setup-go step must come before the govulncheck step"

setup_id=$(yq "$steps[$setup_index].id // \"\"" "$asset")
[ -n "$setup_id" ] || die "the setup-go step needs an id, so the govulncheck step can read its go-version output"
setup_file=$(yq "$steps[$setup_index].with.go-version-file // \"\"" "$asset")
# shellcheck disable=SC2016 # a literal workflow expression
[ "$setup_file" = '${{ matrix.module }}/go.mod' ] ||
  fail "the setup-go step must read go-version-file: \${{ matrix.module }}/go.mod, got '$setup_file'"
setup_version=$(yq "$steps[$setup_index].with | has(\"go-version\")" "$asset")
[ "$setup_version" = false ] || fail "the setup-go step must not set go-version, which overrides the go.mod"

want="\${{ steps.$setup_id.outputs.go-version }}"
input=$(yq "$steps[$vuln_index].with.go-version-input // \"\"" "$asset")
[ "$input" = "$want" ] ||
  fail "the govulncheck step must set go-version-input: $want, got '$input'"
vuln_file=$(yq "$steps[$vuln_index].with | has(\"go-version-file\")" "$asset")
[ "$vuln_file" = false ] ||
  fail "the govulncheck step must not set go-version-file: its own setup-go would resolve the go line"

finish "govulncheck scans with the Go version the setup-go step installed"
