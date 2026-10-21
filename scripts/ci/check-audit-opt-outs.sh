#!/usr/bin/env bash
# Fails unless go-security-audit says what it leaves out for every piece the
# setup answers file can mark `no`. The answers asset is the single list of
# pieces: each `- <Key>: yes...` line under "What to install", plus Fuzzing,
# which can be `off`. The audit's opt-out table names each as `<Key>: no` (or
# `Fuzzing: off`), so a piece added to the setup cannot be silently reported.
set -euo pipefail

answers=skills/go-security-setup/assets/go-security.md
audit=skills/go-security-audit/SKILL.md

status=0
fail() {
  echo "check-audit-opt-outs: $*" >&2
  status=1
}

[ -f "$answers" ] || fail "missing $answers"
[ -f "$audit" ] || fail "missing $audit"
[ "$status" -eq 0 ] || exit 1

grep -qF 'docs/agents/go-security.md' "$audit" || fail "$audit: does not read docs/agents/go-security.md"

keys=$(awk '/^## What to install/ { inside = 1; next } inside && /^## / { exit } inside && /^- [^:]+: / { sub(/^- /, ""); sub(/: .*/, ""); print }' "$answers")
[ -n "$keys" ] || fail "$answers: no keys under '## What to install'"

checked=0
while IFS= read -r key; do
  grep -qF -- "| \`$key: no\` |" "$audit" || fail "$audit: the opt-out table has no row for \`$key: no\`"
  checked=$((checked + 1))
done <<<"$keys"

grep -q -- '^- Fuzzing: ' "$answers" || fail "$answers: no Fuzzing line"
grep -qF -- '| `Fuzzing: off` |' "$audit" || fail "$audit: the opt-out table has no row for \`Fuzzing: off\`"
checked=$((checked + 1))

if [ "$status" -eq 0 ]; then
  echo "check-audit-opt-outs: $audit leaves out all $checked pieces the setup answers can opt out of"
fi
exit "$status"
