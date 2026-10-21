#!/usr/bin/env bash
# Fails unless Argus is presented the way ADR 0004 decides: a README section on
# Argus in Toolbox mode, one mention in go-security-audit (as an example of an
# MCP server, next to the tool-neutral wording), and no mention in any other
# skill. The skills stay usable with any agent; Argus is one option.
set -euo pipefail

status=0
fail() {
  echo "check-argus-mentions: $*" >&2
  status=1
}

readme=README.md
if ! grep -qE '^## .*Argus' "$readme"; then
  fail "$readme: no section heading naming Argus"
else
  section=$(awk '/^## .*Argus/ { inside = 1; print; next } inside && /^## / { exit } inside' "$readme")
  for phrase in 'Toolbox mode' 'MCP server' 'govulncheck' 'gosec' 'LLM provider'; do
    printf '%s\n' "$section" | grep -qF "$phrase" || fail "$readme: Argus section does not mention: $phrase"
  done
fi

audit=skills/go-security-audit/SKILL.md
count=$( (grep -o 'Argus' "$audit" || true) | wc -l | tr -d ' ')
if [ "$count" -ne 1 ]; then
  fail "$audit: names Argus $count times, expected exactly once"
else
  line=$(grep 'Argus' "$audit")
  printf '%s\n' "$line" | grep -qF 'the tool your agent provides' ||
    fail "$audit: the Argus mention is not on the tool-neutral line (\"the tool your agent provides\")"
  printf '%s\n' "$line" | grep -qF 'Toolbox mode' || fail "$audit: the Argus mention does not say Toolbox mode"
fi

for skill in skills/*/; do
  [ "${skill}SKILL.md" = "$audit" ] && continue
  if grep -rqF 'Argus' "$skill"; then
    fail "${skill}: names Argus; only go-security-audit does, once"
  fi
done

if [ "$status" -eq 0 ]; then
  echo "check-argus-mentions: README has the Argus section and only go-security-audit names Argus, once"
fi
exit "$status"
