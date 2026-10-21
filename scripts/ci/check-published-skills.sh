#!/usr/bin/env bash
# Fails if the published skills (the folders under skills/) and the places that
# announce them disagree: the Claude Code marketplace manifest, the README and
# each skill's license. Adding a skill folder means adding it to all of them.
set -euo pipefail

status=0
fail() {
  echo "check-published-skills: $*" >&2
  status=1
}

skills=()
for dir in skills/*/; do
  [ -f "${dir}SKILL.md" ] && skills+=("$(basename "$dir")")
done
if [ ${#skills[@]} -eq 0 ]; then
  echo "check-published-skills: no skill under skills/" >&2
  exit 1
fi

# Marketplace manifest: one plugin with its source at the repo root and an
# explicit skills list that is exactly the published folders.
manifest=.claude-plugin/marketplace.json
if [ ! -f "$manifest" ]; then
  fail "missing $manifest"
else
  sources=$(jq -r '.plugins[].source' "$manifest")
  [ "$sources" = "./" ] || fail "$manifest: expected one plugin with source \"./\", got: $sources"
  listed=$(jq -r '.plugins[].skills[]?' "$manifest" | sort)
  expected=$(printf './skills/%s\n' "${skills[@]}" | sort)
  if [ "$listed" != "$expected" ]; then
    fail "$manifest: skills list differs from the folders under skills/:"
    diff <(echo "$expected") <(echo "$listed") >&2 || true
  fi
fi

# README: the install commands, and a link to every published skill folder and
# to none that does not exist yet.
readme=README.md
if [ ! -f "$readme" ]; then
  fail "missing $readme"
else
  for cmd in 'npx skills add davideimola/go-security-skills' \
    'claude plugin marketplace add davideimola/go-security-skills' \
    'claude plugin install go-security-skills@go-security-skills'; do
    grep -qF "$cmd" "$readme" || fail "$readme: missing install command: $cmd"
  done
  linked=$(grep -oE '\(skills/[a-z0-9-]+/\)' "$readme" | sed -E 's#^\(skills/##; s#/\)$##' | sort -u)
  published=$(printf '%s\n' "${skills[@]}" | sort)
  if [ "$linked" != "$published" ]; then
    fail "$readme: linked skills (skills/<name>/) differ from the folders under skills/:"
    diff <(echo "$published") <(echo "$linked") >&2 || true
  fi
fi

# License: the repo is MIT, and every skill says so in its frontmatter, so a
# single copied skill folder still carries its license.
if ! head -n 1 LICENSE 2>/dev/null | grep -qx 'MIT License'; then
  fail "LICENSE is missing or is not the MIT License"
fi
for s in "${skills[@]}"; do
  frontmatter=$(awk 'NR == 1 && $0 == "---" { inside = 1; next } inside && $0 == "---" { exit } inside' "skills/$s/SKILL.md")
  printf '%s\n' "$frontmatter" | grep -qx 'license: MIT' ||
    fail "skills/$s/SKILL.md: frontmatter does not declare license: MIT"
done

# Security policy: reports go through GitHub private vulnerability reporting.
policy=SECURITY.md
advisories='https://github.com/davideimola/go-security-skills/security/advisories/new'
if [ ! -f "$policy" ]; then
  fail "missing $policy"
elif ! grep -qF "$advisories" "$policy"; then
  fail "$policy: does not point to GitHub private vulnerability reporting ($advisories)"
fi

if [ "$status" -eq 0 ]; then
  echo "check-published-skills: ${#skills[@]} published skills agree with the manifest, README and licenses"
fi
exit "$status"
