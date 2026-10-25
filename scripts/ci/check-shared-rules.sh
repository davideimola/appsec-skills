#!/usr/bin/env bash
# Fails if a rule that several skills state has drifted between them. Each
# skill installs on its own, so each keeps its own copy, and this check keeps
# the copies identical:
#   - each block between `<!-- shared: <name> -->` and `<!-- /shared: <name> -->`
#     appears once in every skill that states it, the same line for line once
#     the marker's indentation is removed (the audit nests it in a numbered
#     step): toolchain in appsec-ci and appsec-audit, scanner-sources in
#     appsec-setup, appsec-ci and appsec-audit;
#   - the module discovery bullet (`- Go modules: ...`) is the same line in
#     appsec-setup, appsec-ci and appsec-audit.
# Changing a shared rule means changing it in every skill in the same PR.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

# holders NAME: the skills that state the shared block NAME.
holders() {
  case $1 in
    toolchain) echo "$ci_skill $audit_skill" ;;
    scanner-sources) echo "$setup_skill $ci_skill $audit_skill" ;;
  esac
}
module_holders=("$setup_skill" "$ci_skill" "$audit_skill")

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

for name in toolchain scanner-sources; do
  first=
  for s in $(holders "$name"); do
    out="$work/$(basename "$(dirname "$s")").$name"
    extract "$s" "$name" >"$out" || { fail "$s: expected one closed '<!-- shared: $name -->' block"; continue; }
    [ -s "$out" ] || { fail "$s: the shared $name block is empty"; continue; }
    if [ -z "$first" ]; then
      first=$s
    elif ! cmp -s "$work/$(basename "$(dirname "$first")").$name" "$out"; then
      fail "the shared $name block differs between $first and $s:"
      diff -u "$work/$(basename "$(dirname "$first")").$name" "$out" >&2 || true
    fi
  done
done

first=
for s in "${module_holders[@]}"; do
  n=$(grep -cE '^ *- Go modules: ' "$s" || true)
  if [ "$n" -ne 1 ]; then
    fail "$s: expected one '- Go modules:' bullet, found $n"
    continue
  fi
  line=$(grep -E '^ *- Go modules: ' "$s" | sed -E 's/^ +//')
  if [ -z "$first" ]; then
    first=$line
  elif [ "$line" != "$first" ]; then
    fail "the '- Go modules:' bullet differs in $s:"
    printf '  %s\n  %s\n' "$first" "$line" >&2
  fi
done

finish "the shared toolchain and scanner-sources rules and module discovery are identical in every skill that states them"
