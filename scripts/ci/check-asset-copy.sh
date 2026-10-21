#!/usr/bin/env bash
# Fails if this repo's copy of the canonical security workflow differs from the
# asset by a single byte. The asset carries this repo's values (ADR 0007), so a
# Dependabot bump of a pin must update both files in the same PR.
set -euo pipefail

asset=skills/go-security-setup/assets/security.yml
copy=.github/workflows/security.yml

for f in "$asset" "$copy"; do
  if [ ! -f "$f" ]; then
    echo "check-asset-copy: missing $f" >&2
    exit 1
  fi
done

if ! cmp -s "$asset" "$copy"; then
  echo "check-asset-copy: $copy differs from $asset:" >&2
  diff -u "$asset" "$copy" >&2 || true
  exit 1
fi
echo "check-asset-copy: $copy is byte-identical to $asset"
