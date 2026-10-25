#!/usr/bin/env bash
# Proves the appsec-setup answers and agents block:
#   1. the answers file asset records an ephemeral run as the source of each
#      scanner under "Scanner sources", and every key it holds has a row in the
#      skill's answers file table;
#   2. the agents block asset sits byte for byte in this repo's AGENTS.md, under
#      its `## Agent skills` section, as the setup writes it in a target repo,
#      and names both answers files.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

skill=$setup_skill
answers=$answers_asset
block=$agents_block_asset

for f in "$skill" "$answers" "$block" AGENTS.md; do
  [ -f "$f" ] || die "missing $f"
done

# value KEY: the text after "- KEY: " on its one line of the answers file.
value() {
  local n
  n=$(grep -c -- "^- $1: " "$answers" || true)
  [ "$n" -eq 1 ] || die "$answers: expected one '- $1:' line, found $n"
  grep -- "^- $1: " "$answers" | sed "s/^- $1: //"
}

keys=$(awk '/^- [^:]+: / { sub(/^- /, ""); sub(/: .*/, ""); print }' "$answers")
while IFS= read -r key; do
  value "$key" >/dev/null
  grep -qF -- "| \`$key\` |" "$skill" || die "$skill: the answers file table has no row for \`$key\`"
done <<<"$keys"

sources=$(awk '/^## Scanner sources/ { inside = 1; next } inside && /^## / { exit } inside && /^- [^:]+: / { sub(/^- /, ""); sub(/: .*/, ""); print }' "$answers")
[ -n "$sources" ] || die "$answers: no keys under '## Scanner sources'"
while IFS= read -r key; do
  [ "$(value "$key")" = 'ephemeral run' ] || die "$answers: the source of '$key' is '$(value "$key")', not the default 'ephemeral run'"
  grep -qF -- "| \`$key\` | \`ephemeral run\` |" "$skill" || die "$skill: the answers file table has no \`ephemeral run\` row for \`$key\`"
done <<<"$sources"
echo "$check: $answers has a table row for every key, and an ephemeral run as the source of $(printf '%s\n' "$sources" | paste -sd ' ' -)"

for f in docs/agents/appsec.md docs/agents/appsec-ci.md; do
  grep -qF -- "\`$f\`" "$block" || die "$block: does not name $f"
done
section=$(awk '/^## Agent skills$/ { inside = 1; next } inside && /^## / { exit } inside { print }' AGENTS.md)
[ -n "$section" ] || die "AGENTS.md: no '## Agent skills' section"
python3 -c 'import sys; sys.exit(0 if open(sys.argv[1]).read() in sys.stdin.read() else 1)' "$block" <<<"$section" \
  || die "AGENTS.md: the '## Agent skills' section does not hold $block byte for byte"
echo "$check: AGENTS.md holds $block in its Agent skills section"
