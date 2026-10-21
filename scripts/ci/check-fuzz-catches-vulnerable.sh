#!/usr/bin/env bash
# Proves the fixture's deny-by-default fuzz property catches real bugs.
#
# The fixture's authz package holds two versions of CanManageOrg side by side:
# the fixed deny-by-default check (default build) and a vulnerable one (build
# tag `vulnerable`) that grants access when the organization can't be resolved
# and checks membership instead of the admin role. This script requires:
#   - on the vulnerable build, FuzzCanManageOrg fails with the property's own
#     message, the table tests of who must be denied fail, and the table tests
#     of who gets in still pass (they alone would miss the bug);
#   - on the fixed build, every test passes and a bounded fuzz run passes.
#
# Everything runs on a temporary copy of the fixture, because a failing fuzz
# run writes its input to testdata/fuzz/ inside the package.
set -euo pipefail

fixture=testdata/fixture
pkg=./internal/authz
target='^FuzzCanManageOrg$'
fail_budget=${FUZZ_FAIL_BUDGET:-60s}
pass_budget=${FUZZ_PASS_BUDGET:-10s}

if [ ! -f "$fixture/go.mod" ]; then
  echo "check-fuzz: missing $fixture/go.mod" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp -R "$fixture/." "$work/"
cd "$work"

fail() {
  echo "check-fuzz: $1" >&2
  if [ -n "${2:-}" ]; then
    sed 's/^/  /' "$2" >&2
  fi
  exit 1
}

# Both builds must compile and vet clean, so a failure below is a test
# failure, never a build error.
go vet "$pkg" || fail "go vet failed on the fixed build"
go vet -tags vulnerable "$pkg" || fail "go vet failed on the vulnerable build"

# Vulnerable build: the property must find the bug.
out="$work/vulnerable-fuzz.log"
if go test -tags vulnerable -run '^$' -fuzz "$target" -fuzztime "$fail_budget" "$pkg" >"$out" 2>&1; then
  fail "FuzzCanManageOrg passed on the vulnerable build; the property misses the bug" "$out"
fi
grep -q -- '--- FAIL: FuzzCanManageOrg' "$out" && grep -q 'granted:' "$out" \
  || fail "FuzzCanManageOrg did not fail with the property's message on the vulnerable build" "$out"
echo "check-fuzz: FuzzCanManageOrg fails on the vulnerable build:"
grep -E 'granted:|Failing input written to' "$out" | sed 's/^/  /'

# Vulnerable build: the who-gets-in tests alone pass, the who-must-be-denied
# tests catch it.
out="$work/vulnerable-allows.log"
go test -tags vulnerable -run '^TestCanManageOrgAllows$' "$pkg" >"$out" 2>&1 \
  || fail "TestCanManageOrgAllows failed on the vulnerable build; it should only check who gets in" "$out"
out="$work/vulnerable-denies.log"
if go test -tags vulnerable -run '^TestCanManageOrgDenies$' "$pkg" >"$out" 2>&1; then
  fail "TestCanManageOrgDenies passed on the vulnerable build; it must check who is denied" "$out"
fi
grep -q -- '--- FAIL: TestCanManageOrgDenies' "$out" \
  || fail "TestCanManageOrgDenies did not fail as a test on the vulnerable build" "$out"
echo "check-fuzz: TestCanManageOrgDenies fails on the vulnerable build, TestCanManageOrgAllows passes"

# Fixed build: every test and a bounded fuzz run pass.
out="$work/fixed.log"
go test "$pkg" >"$out" 2>&1 || fail "tests failed on the fixed build" "$out"
out="$work/fixed-fuzz.log"
go test -run '^$' -fuzz "$target" -fuzztime "$pass_budget" "$pkg" >"$out" 2>&1 \
  || fail "FuzzCanManageOrg failed on the fixed build" "$out"
echo "check-fuzz: FuzzCanManageOrg passes on the fixed build ($pass_budget)"
