#!/usr/bin/env bash
# Fails unless each scanner version the audit skill runs from the shell is the
# one the fixture declares, so a Dependabot bump of the fixture's tool must also
# bump the skill. For gosec and govulncheck:
#   1. the fixture's go.mod declares the command as a tool;
#   2. the fixture requires its module as a direct dependency (no `// indirect`):
#      Dependabot's default version updates cover direct dependencies only, and
#      the tool directive alone leaves the requirement indirect;
#   3. every invocation of the command in the skill names an exact vX.Y.Z;
#   4. that version is the fixture's.
# Usage: check-tool-versions.sh [SKILL.md] [fixture go.mod], paths from the
# repo root.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

skill=${1:-$audit_skill}
gomod=${2:-$fixture/go.mod}

# module:command, one per scanner the audit runs with `go run <command>@<v>`.
tools=(
  github.com/securego/gosec/v2:github.com/securego/gosec/v2/cmd/gosec
  golang.org/x/vuln:golang.org/x/vuln/cmd/govulncheck
)

[ -f "$skill" ] || die "missing $skill"
[ -f "$gomod" ] || die "missing $gomod"

json=$(go mod edit -json "$gomod")

tracked=()
for t in "${tools[@]}"; do
  module=${t%%:*}
  cmd=${t#*:}
  name=$(basename "$cmd")

  if ! printf '%s' "$json" | jq -e --arg cmd "$cmd" '(.Tool // []) | any(.Path == $cmd)' >/dev/null; then
    fail "$gomod has no 'tool $cmd' directive"
    continue
  fi
  req=$(printf '%s' "$json" | jq -c --arg m "$module" '[(.Require // [])[] | select(.Path == $m)] | first // empty')
  if [ -z "$req" ]; then
    fail "$gomod does not require $module"
    continue
  fi
  if [ "$(printf '%s' "$req" | jq -r '.Indirect // false')" != false ]; then
    fail "$gomod requires $module as // indirect, so Dependabot does not update it; blank-import $cmd from tools.go and run go mod tidy"
    continue
  fi
  fixture_version=$(printf '%s' "$req" | jq -r '.Version')

  uses=$(grep -oE "$cmd@[^[:space:]\`]*" "$skill" | sort -u || true)
  if [ -z "$uses" ]; then
    fail "$skill never runs $cmd@<version>"
    continue
  fi
  while IFS= read -r use; do
    version=${use#*@}
    if ! printf '%s' "$version" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
      fail "$skill runs $use, not an exact vX.Y.Z version"
    elif [ "$version" != "$fixture_version" ]; then
      fail "$skill runs $use but $gomod requires $module $fixture_version"
    fi
  done <<<"$uses"
  tracked+=("$name $fixture_version")
done

finish "$skill runs $(printf '%s, ' "${tracked[@]}" | sed 's/, $//'), the versions $gomod declares as direct tool dependencies"
