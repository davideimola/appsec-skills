#!/usr/bin/env bash
# Fails if a rule that appsec-setup and appsec-audit both state has
# drifted between them. Each skill installs on its own, so each keeps its own
# copy, and this check keeps the copies identical:
#   - each block between `<!-- shared: <name> -->` and `<!-- /shared: <name> -->`
#     appears once in both skills, the same line for line once the marker's
#     indentation is removed (the audit nests it in a numbered step);
#   - the module discovery bullet (`- Go modules: ...`) is the same line in both.
# Changing a shared rule means changing it in both skills in the same PR.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

skills=("$setup_skill" "$audit_skill")
blocks=(toolchain scanner-sources)

mkwork

# extract FILE NAME: the block's lines, without the marker's indentation.
extract() {
  awk -v name="$2" '
    $0 ~ "^ *<!-- shared: " name " -->$" {
      n++; match($0, /^ */); indent = RLENGTH; inside = 1; next
    }
    inside && $0 ~ "^ *<!-- /shared: " name " -->$" { inside = 0; next }
    inside { print (substr($0, 1, indent) ~ /^ *$/ ? substr($0, indent + 1) : $0) }
    END { if (n != 1 || inside) exit 1 }
  ' "$1"
}

for name in "${blocks[@]}"; do
  for s in "${skills[@]}"; do
    out="$work/$(basename "$(dirname "$s")").$name"
    extract "$s" "$name" >"$out" || fail "$s: expected one closed '<!-- shared: $name -->' block"
    [ -s "$out" ] || fail "$s: the shared $name block is empty"
  done
  a="$work/$(basename "$(dirname "${skills[0]}")").$name"
  b="$work/$(basename "$(dirname "${skills[1]}")").$name"
  if [ -s "$a" ] && [ -s "$b" ] && ! cmp -s "$a" "$b"; then
    fail "the shared $name block differs between ${skills[0]} and ${skills[1]}:"
    diff -u "$a" "$b" >&2 || true
  fi
done

modules=()
for s in "${skills[@]}"; do
  n=$(grep -cE '^ *- Go modules: ' "$s" || true)
  if [ "$n" -ne 1 ]; then
    fail "$s: expected one '- Go modules:' bullet, found $n"
    continue
  fi
  modules+=("$(grep -E '^ *- Go modules: ' "$s" | sed -E 's/^ +//')")
done
if [ ${#modules[@]} -eq 2 ] && [ "${modules[0]}" != "${modules[1]}" ]; then
  fail "the '- Go modules:' bullet differs between ${skills[0]} and ${skills[1]}:"
  printf '  %s\n' "${modules[@]}" >&2
fi

finish "appsec-setup and appsec-audit state the shared ${blocks[*]} rules and module discovery identically"
