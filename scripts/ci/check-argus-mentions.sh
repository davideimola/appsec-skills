#!/usr/bin/env bash
# Fails unless Argus is presented the way ADRs 0004 and 0011 decide: a README
# section on running the scanners through an MCP server, with Argus in Toolbox
# mode as its example, one mention in appsec-audit (as an example of an
# MCP tool source, next to the tool-neutral wording), and no mention in any
# other skill. The skills stay usable with any agent; Argus is one option.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

readme=README.md
heading='## Running the scanners through an MCP server'
if ! grep -qxF "$heading" "$readme"; then
  fail "$readme: no section '$heading'"
else
  section=$(awk -v h="$heading" '$0 == h { inside = 1; print; next } inside && /^## / { exit } inside' "$readme")
  for phrase in 'Argus' 'Toolbox mode' 'MCP server' 'govulncheck' 'gosec' 'LLM provider' 'appsec-setup'; do
    printf '%s\n' "$section" | grep -qF "$phrase" || fail "$readme: the MCP server section does not mention: $phrase"
  done
  # The setup offers both scanners' Argus tools as MCP tool sources.
  for tool in run_govulncheck run_gosec; do
    printf '%s\n' "$section" | grep -qF "\`$tool\`" || fail "$readme: the MCP server section does not name \`$tool\`"
  done
fi
if grep -E '^## ' "$readme" | grep -v -xF "$heading" | grep -qF 'Argus'; then
  fail "$readme: a section heading other than '$heading' names Argus"
fi

audit=$audit_skill
count=$( (grep -o 'Argus' "$audit" || true) | wc -l | tr -d ' ')
if [ "$count" -ne 1 ]; then
  fail "$audit: names Argus $count times, expected exactly once"
else
  line=$(grep 'Argus' "$audit")
  printf '%s\n' "$line" | grep -qF 'the tool your agent provides' ||
    fail "$audit: the Argus mention is not on the tool-neutral line (\"the tool your agent provides\")"
  printf '%s\n' "$line" | grep -qF 'Toolbox mode' || fail "$audit: the Argus mention does not say Toolbox mode"
fi

# The audit's references (its tool-branch notes among them) stay tool-neutral.
for f in "$(dirname "$audit")"/references/*; do
  if grep -qF 'Argus' "$f"; then
    fail "$f: names Argus; only the audit's Scanner sources line does"
  fi
done

for skill in skills/*/; do
  [ "${skill}SKILL.md" = "$audit" ] && continue
  if grep -rqF 'Argus' "$skill"; then
    fail "${skill}: names Argus; only appsec-audit does, once"
  fi
done

finish "README names Argus in its MCP server section and only appsec-audit names Argus, once"
