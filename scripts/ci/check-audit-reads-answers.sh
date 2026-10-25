#!/usr/bin/env bash
# Fails unless appsec-audit says what it leaves out for every piece the
# appsec-ci answers file can mark `no`. That answers asset is the single list of
# pieces: each `- <Key>: yes...` line under "What to install", plus Fuzzing,
# which can be `off`. The audit's opt-out table names each as `<Key>: no` (or
# `Fuzzing: off`), so a piece added to appsec-ci cannot be silently reported.
# Each scanner under "Scanner sources" of the appsec-setup answers must be read
# by the audit too, as `<key>:`, so a source the setup saves cannot be silently
# ignored.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

answers=$ci_answers_asset
setup_answers=$answers_asset
audit=$audit_skill

[ -f "$answers" ] || fail "missing $answers"
[ -f "$setup_answers" ] || fail "missing $setup_answers"
[ -f "$audit" ] || fail "missing $audit"
[ "$status" -eq 0 ] || exit 1

for f in docs/agents/appsec.md docs/agents/appsec-ci.md; do
  grep -qF "$f" "$audit" || fail "$audit: does not read $f"
done

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

sources=$(awk '/^## Scanner sources/ { inside = 1; next } inside && /^## / { exit } inside && /^- [^:]+: / { sub(/^- /, ""); sub(/: .*/, ""); print }' "$setup_answers")
[ -n "$sources" ] || fail "$setup_answers: no keys under '## Scanner sources'"
while IFS= read -r key; do
  grep -qF -- "\`$key:\`" "$audit" || fail "$audit: does not read the scanner source \`$key:\`"
done <<<"$sources"

finish "$audit leaves out all $checked pieces the appsec-ci answers can opt out of, and reads every scanner source"
