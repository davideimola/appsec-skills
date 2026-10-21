#!/usr/bin/env bash
# Fails if any `uses:` in this repo's workflows or in a canonical asset is not
# pinned to a full commit SHA. Local actions (./path) and digest-pinned Docker
# images (docker://...@sha256:...) are the only exceptions.
set -euo pipefail

files=()
while IFS= read -r f; do
  files+=("$f")
done < <(find .github/workflows skills -type f \( -name '*.yml' -o -name '*.yaml' \) \
  \( -path '.github/workflows/*' -o -path 'skills/*/assets/*' \) 2>/dev/null | sort)
if [ ${#files[@]} -eq 0 ]; then
  echo "check-pins: no workflow or asset files found" >&2
  exit 1
fi

status=0
for f in "${files[@]}"; do
  while IFS= read -r line; do
    lineno=${line%%:*}
    ref=$(printf '%s' "${line#*:}" | sed -E "s/^[[:space:]]*(-[[:space:]]*)?uses:[[:space:]]*//; s/[[:space:]]+#.*\$//; s/^[\"']//; s/[\"']\$//")
    case "$ref" in
      ./*) continue ;;
      docker://*@sha256:*) continue ;;
    esac
    if ! printf '%s' "$ref" | grep -Eq '^[^@[:space:]]+@[0-9a-f]{40}$'; then
      echo "$f:$lineno: not pinned to a full commit SHA: $ref" >&2
      status=1
    fi
  done < <(grep -nE '^[[:space:]]*(-[[:space:]]*)?uses:' "$f" || true)
done

if [ "$status" -eq 0 ]; then
  echo "check-pins: every uses: is pinned to a full commit SHA (${#files[@]} files)"
fi
exit "$status"
