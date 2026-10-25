#!/usr/bin/env bash
# Proves the TypeScript fixture's deny-by-default property catches real bugs,
# and that a kept counterexample catches the regression on every run.
#
# The fixture's authz module holds two versions of canManageOrg side by side:
# the fixed deny-by-default check (authz.ts) and a vulnerable one
# (authz.vulnerable.ts) that vitest swaps in with VULNERABLE=1, the way
# `-tags vulnerable` swaps the Go fixture's build. This script requires:
#   - on the vulnerable version, the property fails with its own message on
#     every one of $PROPERTY_RUNS random seeds, the cases of who must be denied
#     fail, and the cases of who gets in still pass (they alone would miss it);
#   - the counterexample a failing run prints, pasted into the property's
#     `examples`, fails the vulnerable version on its first run;
#   - on the fixed version, the type check and every test pass, the kept
#     counterexample included.
#
# Everything runs on a temporary copy of the fixture.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

runs=${PROPERTY_RUNS:-10}
dir=src/authz
prop=$dir/authz.prop.test.ts

[ -f "$fixture_ts/package-lock.json" ] || die "missing $fixture_ts/package-lock.json"
mkwork
cp -R "$fixture_ts/." "$work/"
rm -rf "$work/node_modules"
cd "$work"
npm ci --ignore-scripts --no-audit --no-fund >"$work/npm.log" 2>&1 || die "npm ci failed" "$work/npm.log"
npx tsc --noEmit >"$work/tsc.log" 2>&1 || die "type check failed" "$work/tsc.log"
grep -q 'examples: \[\],' "$prop" || die "$prop: examples is not empty; the property must find the bug itself"

# Vulnerable version: the property finds the bug whatever the seed.
for i in $(seq "$runs"); do
  out="$work/vulnerable-prop-$i.log"
  if VULNERABLE=1 npx vitest run "$prop" >"$out" 2>&1; then
    die "the property passed on the vulnerable version (run $i of $runs); it misses the bug" "$out"
  fi
  grep -q 'granted:' "$out" && grep -q '^Counterexample: ' "$out" \
    || die "the property did not fail with its own message on the vulnerable version" "$out"
done
counterexample=$(grep -m1 '^Counterexample: ' "$work/vulnerable-prop-1.log" | sed 's/^Counterexample: //')
echo "$check: the property fails on the vulnerable version on $runs of $runs seeds, e.g. $counterexample"

# Vulnerable version: the who-gets-in cases alone pass, the who-must-be-denied
# cases catch it.
out="$work/vulnerable-allows.log"
VULNERABLE=1 npx vitest run "$dir/authz.test.ts" -t 'canManageOrg allows' >"$out" 2>&1 \
  || die "the allows cases failed on the vulnerable version; they should only check who gets in" "$out"
out="$work/vulnerable-denies.log"
if VULNERABLE=1 npx vitest run "$dir/authz.test.ts" -t 'canManageOrg denies' >"$out" 2>&1; then
  die "the denies cases passed on the vulnerable version; they must check who is denied" "$out"
fi
grep -q 'granted:' "$out" || die "the denies cases did not fail with their own message" "$out"
echo "$check: the denies cases fail on the vulnerable version, the allows cases pass"

# Keep the counterexample, as the reference says, and replay it with a single
# run: the kept example alone must catch the regression.
sed -i.bak "s|examples: \[\],|numRuns: 1, examples: [$counterexample],|" "$prop" && rm "$prop.bak"
grep -qF "examples: [$counterexample]" "$prop" || die "could not keep $counterexample in $prop"
out="$work/kept.log"
if VULNERABLE=1 npx vitest run "$prop" >"$out" 2>&1; then
  die "with $counterexample kept, the property passed on the vulnerable version" "$out"
fi
grep -q 'Property failed after 1 tests' "$out" || die "the kept counterexample was not the failing run" "$out"
echo "$check: the kept counterexample fails the vulnerable version on the first run"

# Fixed version: everything passes, the kept counterexample included.
out="$work/fixed.log"
npx vitest run >"$out" 2>&1 || die "tests failed on the fixed version" "$out"
echo "$check: every test passes on the fixed version, kept counterexample included"
