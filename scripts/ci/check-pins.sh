#!/usr/bin/env bash
# Fails if anything CI runs is not pinned:
#   1. every `uses:` in this repo's workflows and in a canonical asset is pinned
#      to a full commit SHA; local actions (./path) and digest-pinned Docker
#      images (docker://...@sha256:...) are the only exceptions;
#   2. the CI tools that are neither Go modules of the fixture nor actions (yq,
#      zizmor, actionlint, skills-ref, check-jsonschema) are pinned once, in
#      tools.env, to exact versions, and no script or checks.yml step writes
#      one of those versions itself.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

files=()
while IFS= read -r f; do
  files+=("$f")
done < <(find .github/workflows skills -type f \( -name '*.yml' -o -name '*.yaml' \) \
  \( -path '.github/workflows/*' -o -path 'skills/*/assets/*' \) 2>/dev/null | sort)
[ ${#files[@]} -gt 0 ] || die "no workflow or asset files found"

for f in "${files[@]}"; do
  while IFS= read -r line; do
    lineno=${line%%:*}
    ref=$(printf '%s' "${line#*:}" | sed -E "s/^[[:space:]]*(-[[:space:]]*)?uses:[[:space:]]*//; s/[[:space:]]+#.*\$//; s/^[\"']//; s/[\"']\$//")
    case "$ref" in
      ./*) continue ;;
      docker://*@sha256:*) continue ;;
    esac
    printf '%s' "$ref" | grep -Eq '^[^@[:space:]]+@[0-9a-f]{40}$' ||
      fail "$f:$lineno: not pinned to a full commit SHA: $ref"
  done < <(grep -nE '^[[:space:]]*(-[[:space:]]*)?uses:' "$f" || true)
done

env=scripts/ci/tools.env
while IFS= read -r line; do
  case "$line" in '' | '#'*) continue ;; esac
  name=${line%%=*}
  version=${line#*=}
  if ! printf '%s' "$line" | grep -Eq '^[A-Z_]+_VERSION=v?[0-9]+\.[0-9]+\.[0-9]+$'; then
    fail "$env: not NAME_VERSION=<exact X.Y.Z version>: $line"
    continue
  fi
  pattern="(^|[^0-9.])${version//./\\.}([^0-9]|\$)"
  if grep -nE -- "$pattern" .github/workflows/checks.yml scripts/ci/*.sh >&2; then
    fail "$name's version $version is written above instead of read from $env"
  fi
done <"$env"
for name in YQ_VERSION ZIZMOR_VERSION ACTIONLINT_VERSION SKILLS_REF_VERSION CHECK_JSONSCHEMA_VERSION; do
  grep -q "^$name=" "$env" || fail "$env does not pin $name"
done

finish "every uses: is pinned to a full commit SHA (${#files[@]} files), and every CI tool to an exact version in $env"
