#!/usr/bin/env bash
# Fails if a skill file (SKILL.md, any case) exists anywhere other than
# skills/<name>/SKILL.md. Installers such as `npx skills` discover SKILL.md in
# many places, so a stray one would ship (ADR 0006).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

found=$(git ls-files --cached --others --exclude-standard | grep -iE '(^|/)skill\.md$' || true)
[ -n "$found" ] || die "no SKILL.md found under skills/"

stray=$(printf '%s\n' "$found" | grep -vE '^skills/[a-z0-9]+(-[a-z0-9]+)*/SKILL\.md$' || true)
if [ -n "$stray" ]; then
  fail "skill files outside skills/<name>/SKILL.md:"
  printf '%s\n' "$stray" | sed 's/^/  /' >&2
fi
finish "every skill file is at skills/<name>/SKILL.md"
