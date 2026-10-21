#!/usr/bin/env bash
# Fails unless the gosec version the audit skill runs is the one the fixture
# declares, so a Dependabot bump of the fixture's gosec must also bump the skill.
#   1. the fixture's go.mod declares gosec as a tool;
#   2. the fixture requires gosec as a direct dependency (no `// indirect`):
#      Dependabot's default version updates cover direct dependencies only, and
#      the tool directive alone leaves the requirement indirect;
#   3. every gosec invocation in the skill names an exact vX.Y.Z version;
#   4. that version is the fixture's.
# Usage: check-gosec-version.sh [SKILL.md] [fixture go.mod]
set -euo pipefail
. "$(dirname "$0")/lib.sh"

skill=${1:-skills/go-security-audit/SKILL.md}
gomod=${2:-testdata/fixture/go.mod}
module=github.com/securego/gosec/v2
cmd=$module/cmd/gosec

[ -f "$skill" ] || die "missing $skill"
[ -f "$gomod" ] || die "missing $gomod"

json=$(go mod edit -json "$gomod")

printf '%s' "$json" | jq -e --arg cmd "$cmd" '(.Tool // []) | any(.Path == $cmd)' >/dev/null ||
  die "$gomod has no 'tool $cmd' directive"

req=$(printf '%s' "$json" | jq -c --arg m "$module" '[(.Require // [])[] | select(.Path == $m)] | first // empty')
[ -n "$req" ] || die "$gomod does not require $module"
[ "$(printf '%s' "$req" | jq -r '.Indirect // false')" = false ] ||
  die "$gomod requires $module as // indirect, so Dependabot does not update it; blank-import $cmd from a tools.go behind a build tag and run go mod tidy"
fixture_version=$(printf '%s' "$req" | jq -r '.Version')

uses=$(grep -oE "$cmd@[^[:space:]\`]*" "$skill" | sort -u || true)
[ -n "$uses" ] || die "$skill never runs $cmd@<version>"
status=0
while IFS= read -r use; do
  version=${use#*@}
  if ! printf '%s' "$version" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "$check: $skill runs $use, not an exact vX.Y.Z version" >&2
    status=1
  elif [ "$version" != "$fixture_version" ]; then
    echo "$check: $skill runs $use but $gomod requires $module $fixture_version" >&2
    status=1
  fi
done <<<"$uses"
[ "$status" -eq 0 ] || exit 1

echo "$check: $skill runs gosec $fixture_version, the version $gomod declares as a direct tool dependency"
