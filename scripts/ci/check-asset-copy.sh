#!/usr/bin/env bash
# Fails if this repo's copy of a canonical asset differs from the asset by a
# single byte. Each asset carries this repo's values (ADR 0007), so a
# Dependabot bump of a pin must update both files in the same PR.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# asset:copy pairs
pairs=(
  "$workflow_asset:.github/workflows/security.yml"
  "$dependabot_asset:.github/dependabot.yml"
  "$answers_asset:docs/agents/go-security.md"
  "$policy_asset:SECURITY.md"
)

for pair in "${pairs[@]}"; do
  asset=${pair%%:*}
  copy=${pair#*:}
  missing=0
  for f in "$asset" "$copy"; do
    if [ ! -f "$f" ]; then
      fail "missing $f"
      missing=1
    fi
  done
  [ "$missing" -eq 0 ] || continue
  if ! cmp -s "$asset" "$copy"; then
    fail "$copy differs from $asset:"
    diff -u "$asset" "$copy" >&2 || true
    continue
  fi
  echo "$check: $copy is byte-identical to $asset"
done
finish "every copy is byte-identical to its asset"
