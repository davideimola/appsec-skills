#!/usr/bin/env bash
# Fails if this repo's copy of a canonical asset differs from the asset by a
# single byte. Each asset carries this repo's values (ADR 0007), so a
# Dependabot bump of a pin must update both files in the same PR.
set -euo pipefail

# asset:copy pairs
pairs=(
  skills/go-security-setup/assets/security.yml:.github/workflows/security.yml
  skills/go-security-setup/assets/dependabot.yml:.github/dependabot.yml
  skills/go-security-setup/assets/go-security.md:docs/agents/go-security.md
)

status=0
for pair in "${pairs[@]}"; do
  asset=${pair%%:*}
  copy=${pair#*:}
  missing=0
  for f in "$asset" "$copy"; do
    if [ ! -f "$f" ]; then
      echo "check-asset-copy: missing $f" >&2
      missing=1
    fi
  done
  if [ "$missing" -eq 1 ]; then
    status=1
    continue
  fi
  if ! cmp -s "$asset" "$copy"; then
    echo "check-asset-copy: $copy differs from $asset:" >&2
    diff -u "$asset" "$copy" >&2 || true
    status=1
    continue
  fi
  echo "check-asset-copy: $copy is byte-identical to $asset"
done
exit "$status"
