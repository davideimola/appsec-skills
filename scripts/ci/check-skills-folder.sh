#!/usr/bin/env bash
# Fails if a skill file (SKILL.md, any case) exists anywhere other than
# skills/<name>/SKILL.md. Installers such as `npx skills` discover SKILL.md in
# many places, so a stray one would ship (ADR 0006).
set -euo pipefail

found=$(git ls-files --cached --others --exclude-standard | grep -iE '(^|/)skill\.md$' || true)
if [ -z "$found" ]; then
  echo "check-skills-folder: no SKILL.md found under skills/" >&2
  exit 1
fi

stray=$(printf '%s\n' "$found" | grep -vE '^skills/[a-z0-9]+(-[a-z0-9]+)*/SKILL\.md$' || true)
if [ -n "$stray" ]; then
  echo "check-skills-folder: skill files outside skills/<name>/SKILL.md:" >&2
  printf '%s\n' "$stray" | sed 's/^/  /' >&2
  exit 1
fi
echo "check-skills-folder: every skill file is at skills/<name>/SKILL.md"
