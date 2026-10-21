#!/usr/bin/env bash
# Proves the loop go-security-audit runs for a logic finding, on the fixture:
# failing test, then fix, then the same test passing, and the test kept.
#
# It runs the commands verify-with-fuzz's step 4 tells the agent to run, as the
# skill writes them, with <Func> and <pkg> filled in for the fixture's
# CanManageOrg. "Today's code" is the vulnerable build (`-tags vulnerable`);
# "the confirmed fix" is the default build. It requires:
#   - the audit to reach verify-with-fuzz for a logic finding and verify the
#     fix with verify-with-fuzz's "After a fix" section;
#   - before the fix, the named cases and the property fail, and the fuzzer
#     keeps its failing input under testdata/fuzz/;
#   - that kept input fails plain `go test` on the vulnerable build, so the
#     regression is caught without fuzzing;
#   - after the fix, the same commands pass unchanged, then `go test ./<pkg>`
#     passes and still replays the kept input.
#
# Everything runs on a temporary copy of the fixture.
#
# It matches the skills' prose on purpose (step 4's heading and sh block, "After
# a fix"): rewording those lines means updating this check in the same change.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

audit=$audit_skill
verify=$verify_skill
func=CanManageOrg
pkg=internal/authz
pass_budget=${FUZZ_PASS_BUDGET:-}

for f in "$audit" "$verify" "$fixture/go.mod"; do
  [ -f "$f" ] || die "missing $f"
done

grep -qF 'verify-with-fuzz' "$audit" || die "$audit: never reaches verify-with-fuzz"
grep -qF 'After a fix' "$audit" || die "$audit: does not verify a logic fix with verify-with-fuzz's After a fix section"
grep -q '^## After a fix$' "$verify" || die "$verify: no '## After a fix' section"

# The go test lines of the sh block in verify-with-fuzz's step 4.
commands=$(awk '
  /^[0-9]+\. \*\*Run it\.\*\*/ { step = 1; next }
  step && /^[0-9]+\. \*\*/ { exit }
  step && /^ *```sh$/ { block = 1; next }
  block && /^ *```$/ { exit }
  block { sub(/^ +/, ""); print }
' "$verify")
[ "$(grep -c '^go test ' <<<"$commands")" -eq 2 ] \
  || die "$verify: step 4 does not hold exactly two go test commands"
grep -q -- '-fuzz ' <<<"$commands" || die "$verify: step 4 has no fuzz command"
commands=$(sed -e "s|<Func>|$func|g" -e "s|<pkg>|$pkg|g" <<<"$commands")
if [ -n "$pass_budget" ]; then
  commands=$(sed -E "s/-fuzztime [^ ]+/-fuzztime $pass_budget/" <<<"$commands")
fi
named=$(sed -n 1p <<<"$commands")
fuzz=$(sed -n 2p <<<"$commands")

copy_fixture
corpus="$pkg/testdata/fuzz/Fuzz$func"
[ ! -e "$corpus" ] || die "the fixture already commits $corpus; the property must find the bug itself"

# Before the fix: the named cases and the property fail on today's code.
out="$work/before-named.log"
if GOFLAGS=-tags=vulnerable bash -c "$named" >"$out" 2>&1; then
  die "before the fix, '$named' passed" "$out"
fi
grep -q -- "--- FAIL: Test${func}Denies" "$out" || die "before the fix, Test${func}Denies did not fail as a test" "$out"
out="$work/before-fuzz.log"
if GOFLAGS=-tags=vulnerable bash -c "$fuzz" >"$out" 2>&1; then
  die "before the fix, '$fuzz' passed" "$out"
fi
grep -q 'granted:' "$out" || die "before the fix, Fuzz$func did not fail with the property's message" "$out"
kept=$(find "$corpus" -type f 2>/dev/null | head -n 1)
[ -n "$kept" ] || die "the failing fuzz run kept no input under $corpus" "$out"
echo "$check: before the fix, both step 4 commands fail and the fuzzer keeps $kept"

# The kept input catches the regression without fuzzing.
out="$work/regression.log"
if GOFLAGS=-tags=vulnerable go test -run "^Fuzz$func\$" "./$pkg" >"$out" 2>&1; then
  die "plain go test passed on the vulnerable build with $kept kept" "$out"
fi
grep -q 'granted:' "$out" || die "plain go test did not fail on the kept input" "$out"
echo "$check: plain go test replays $kept and fails on the vulnerable build"

# After the fix: the same commands pass unchanged, then the package's tests.
out="$work/after-named.log"
bash -c "$named" >"$out" 2>&1 || die "after the fix, '$named' failed" "$out"
out="$work/after-fuzz.log"
bash -c "$fuzz" >"$out" 2>&1 || die "after the fix, '$fuzz' failed" "$out"
out="$work/after-pkg.log"
go test -v "./$pkg" >"$out" 2>&1 || die "after the fix, go test ./$pkg failed" "$out"
grep -qF -- "--- PASS: Fuzz$func/$(basename "$kept")" "$out" \
  || die "after the fix, go test ./$pkg did not replay $kept" "$out"
[ -f "$kept" ] || die "$kept was removed"
echo "$check: after the fix, the same commands pass, and go test ./$pkg replays $kept"
