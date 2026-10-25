#!/usr/bin/env bash
# Proves the TypeScript fixture's deny-by-default property catches real bugs,
# with the commands appsec-prove's TypeScript reference tells the agent to run.
#
# The fixture's authz module holds two versions of canEditProject side by side:
# the fixed deny-by-default check (authz.ts) and a vulnerable one
# (authz.vulnerable.ts) that vitest swaps in with VULNERABLE=1, the way
# `-tags vulnerable` swaps the Go fixture's build. This script runs the two
# commands under the reference's "## Commands", with <dir> and <file> filled in,
# and requires:
#   - on the vulnerable version, the property command fails with its own
#     message on every one of $PROPERTY_RUNS random seeds, and the named cases
#     command fails in the denies group while the allows group passes (it alone
#     would miss the bugs);
#   - the counterexample a failing run prints, kept in the property's
#     `examples` as the reference says, fails the vulnerable version on its
#     first run;
#   - on the fixed version, the type check passes, both commands pass unchanged,
#     and so does the reference's After a fix command for the whole directory,
#     the kept counterexample included.
#
# Everything runs on a temporary copy of the fixture.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

runs=${PROPERTY_RUNS:-10}
dir=src/authz
file=authz
prop=$dir/$file.prop.test.ts

[ -f "$prove_ts_ref" ] || die "missing $prove_ts_ref"
[ -f "$fixture_ts/package-lock.json" ] || die "missing $fixture_ts/package-lock.json"

commands=$(reference_commands "$prove_ts_ref")
[ "$(grep -c '^npx vitest run ' <<<"$commands")" -eq 2 ] \
  || die "$prove_ts_ref: Commands does not hold exactly two npx vitest run commands"
commands=$(sed -e "s|<dir>|$dir|g" -e "s|<file>|$file|g" <<<"$commands")
named=$(sed -n 1p <<<"$commands")
property=$(sed -n 2p <<<"$commands")
grep -qF "$prop" <<<"$property" || die "$prove_ts_ref: the second command does not run $prop"

mkwork
cp -R "$fixture_ts/." "$work/"
rm -rf "$work/node_modules"
cd "$work"
npm ci --ignore-scripts --no-audit --no-fund >"$work/npm.log" 2>&1 || die "npm ci failed" "$work/npm.log"
npx tsc --noEmit >"$work/tsc.log" 2>&1 || die "type check failed" "$work/tsc.log"
grep -q 'examples: \[\],' "$prop" || die "$prop: examples is not empty; the property must find the bugs itself"

# Vulnerable version: the property finds a bug whatever the seed.
for i in $(seq "$runs"); do
  out="$work/vulnerable-prop-$i.log"
  if VULNERABLE=1 bash -c "$property" >"$out" 2>&1; then
    die "'$property' passed on the vulnerable version (run $i of $runs); the property misses the bugs" "$out"
  fi
  grep -q 'granted:' "$out" && grep -q '^Counterexample: ' "$out" \
    || die "the property did not fail with its own message on the vulnerable version" "$out"
done
counterexample=$(grep -m1 '^Counterexample: ' "$work/vulnerable-prop-1.log" | sed 's/^Counterexample: //')
echo "$check: '$property' fails on the vulnerable version on $runs of $runs seeds, e.g. $counterexample"

# Vulnerable version: the named cases command fails in the denies group only.
out="$work/vulnerable-named.log"
if VULNERABLE=1 bash -c "$named" >"$out" 2>&1; then
  die "'$named' passed on the vulnerable version" "$out"
fi
grep -q 'granted:' "$out" || die "the named cases did not fail with their own message" "$out"
out="$work/vulnerable-allows.log"
VULNERABLE=1 bash -c "$named -t 'canEditProject allows'" >"$out" 2>&1 \
  || die "the allows group failed on the vulnerable version; it should only check who gets in" "$out"
echo "$check: '$named' fails on the vulnerable version in the denies group; the allows group passes"

# Keep the counterexample as the reference says, and replay it with a single
# run: the kept example alone must catch the regression.
sed -i.bak "s|examples: \[\],|numRuns: 1, examples: [$counterexample] as [string, string, Role, string, string, boolean, boolean][],|" "$prop" && rm "$prop.bak"
grep -qF "examples: [$counterexample]" "$prop" || die "could not keep $counterexample in $prop"
npx tsc --noEmit >"$work/tsc-kept.log" 2>&1 || die "type check failed with the kept counterexample" "$work/tsc-kept.log"
out="$work/kept.log"
if VULNERABLE=1 bash -c "$property" >"$out" 2>&1; then
  die "with $counterexample kept, the property passed on the vulnerable version" "$out"
fi
grep -q 'Property failed after 1 tests' "$out" || die "the kept counterexample was not the failing run" "$out"
echo "$check: the kept counterexample fails the vulnerable version on the first run"

# Fixed version: both commands pass unchanged, then the whole directory.
for cmd in "$named" "$property" "npx vitest run $dir"; do
  out="$work/fixed.log"
  bash -c "$cmd" >"$out" 2>&1 || die "'$cmd' failed on the fixed version" "$out"
done
echo "$check: on the fixed version both commands and 'npx vitest run $dir' pass, kept counterexample included"
