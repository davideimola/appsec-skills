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
. "$(dirname "$0")/lib.sh"

pkg=./internal/authz
target='^FuzzCanManageOrg$'
fail_budget=${FUZZ_FAIL_BUDGET:-60s}
pass_budget=${FUZZ_PASS_BUDGET:-10s}

copy_fixture

# Both builds must compile and vet clean, so a failure below is a test
# failure, never a build error.
go vet "$pkg" || die "go vet failed on the fixed build"
go vet -tags vulnerable "$pkg" || die "go vet failed on the vulnerable build"

# Vulnerable build: the property must find the bug.
out="$work/vulnerable-fuzz.log"
if go test -tags vulnerable -run '^$' -fuzz "$target" -fuzztime "$fail_budget" "$pkg" >"$out" 2>&1; then
  die "FuzzCanManageOrg passed on the vulnerable build; the property misses the bug" "$out"
fi
grep -q -- '--- FAIL: FuzzCanManageOrg' "$out" && grep -q 'granted:' "$out" \
  || die "FuzzCanManageOrg did not fail with the property's message on the vulnerable build" "$out"
echo "$check: FuzzCanManageOrg fails on the vulnerable build:"
grep -E 'granted:|Failing input written to' "$out" | sed 's/^/  /'

# Vulnerable build: the who-gets-in tests alone pass, the who-must-be-denied
# tests catch it.
out="$work/vulnerable-allows.log"
go test -tags vulnerable -run '^TestCanManageOrgAllows$' "$pkg" >"$out" 2>&1 \
  || die "TestCanManageOrgAllows failed on the vulnerable build; it should only check who gets in" "$out"
out="$work/vulnerable-denies.log"
if go test -tags vulnerable -run '^TestCanManageOrgDenies$' "$pkg" >"$out" 2>&1; then
  die "TestCanManageOrgDenies passed on the vulnerable build; it must check who is denied" "$out"
fi
grep -q -- '--- FAIL: TestCanManageOrgDenies' "$out" \
  || die "TestCanManageOrgDenies did not fail as a test on the vulnerable build" "$out"
echo "$check: TestCanManageOrgDenies fails on the vulnerable build, TestCanManageOrgAllows passes"

# Fixed build: every test and a bounded fuzz run pass.
out="$work/fixed.log"
go test "$pkg" >"$out" 2>&1 || die "tests failed on the fixed build" "$out"
out="$work/fixed-fuzz.log"
go test -run '^$' -fuzz "$target" -fuzztime "$pass_budget" "$pkg" >"$out" 2>&1 \
  || die "FuzzCanManageOrg failed on the fixed build" "$out"
echo "$check: FuzzCanManageOrg passes on the fixed build ($pass_budget)"
