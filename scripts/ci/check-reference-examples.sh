#!/usr/bin/env bash
# Fails if a skill's reference example differs from the fixture code CI proves.
#
# A reference file under skills/<name>/references/ quotes fixture files as
# code blocks, each right after a marker line naming the file:
#
#   <!-- fixture: internal/authz/authz_fuzz_test.go -->
#   ```go
#   ...the file, byte for byte...
#   ```
#
# Each quoted block must equal testdata/fixture/<path>, so the example an agent
# copies is the one check-fuzz-catches-vulnerable.sh runs. Every reference file
# listed in `required` must quote at least one fixture file.
set -euo pipefail

fixture=testdata/fixture
required=(
  skills/go-security-audit/references/http-limits.md
  skills/verify-with-fuzz/references/deny-by-default-authz.md
)

status=0
fail() {
  echo "check-reference-examples: $*" >&2
  status=1
}

for ref in "${required[@]}"; do
  [ -f "$ref" ] || fail "missing $ref"
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

checked=0
shopt -s nullglob
for ref in skills/*/references/*.md; do
  # Split the reference into one file per quoted block, named by its index, and
  # list "<index> <fixture path>" pairs.
  out="$work/$(echo "$ref" | tr '/' '_')"
  mkdir -p "$out"
  awk -v out="$out" '
    match($0, /^<!-- fixture: [^ ]+ -->$/) {
      path = substr($0, 15, length($0) - 18)
      getline fence
      if (fence != "```go") { print "BADFENCE " path; next }
      n++; file = out "/" n; printf "" > file
      print n " " path
      while ((getline line) > 0 && line != "```") print line >> file
      close(file)
    }
  ' "$ref" >"$out/index"

  quoted=0
  while read -r n path; do
    if [ "$n" = BADFENCE ]; then
      fail "$ref: the marker for $path is not followed by a \`\`\`go block"
      continue
    fi
    quoted=$((quoted + 1))
    src="$fixture/$path"
    if [ ! -f "$src" ]; then
      fail "$ref: quotes $path, which is not a fixture file"
    elif ! cmp -s "$src" "$out/$n"; then
      fail "$ref: the block for $path differs from $src:"
      diff -u "$src" "$out/$n" >&2 || true
    fi
  done <"$out/index"

  for r in "${required[@]}"; do
    if [ "$r" = "$ref" ] && [ "$quoted" -eq 0 ]; then
      fail "$ref: quotes no fixture file"
    fi
  done
  checked=$((checked + quoted))
done

if [ "$status" -eq 0 ]; then
  echo "check-reference-examples: $checked quoted fixture files match $fixture"
fi
exit "$status"
