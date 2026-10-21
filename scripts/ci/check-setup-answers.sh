#!/usr/bin/env bash
# Proves the go-security-setup answers against the canonical workflow:
#   1. the asset carries the default answer on each answer's line;
#   2. a non-default answer, applied as the skill applies it (one line
#      replaced, nothing else), is still a workflow actionlint and zizmor
#      accept, and the skill's adapted-values table names any fixed line.
# ZIZMOR overrides the zizmor command (default: pipx run zizmor==1.31.1).
set -euo pipefail

asset=skills/go-security-setup/assets/security.yml
skill=skills/go-security-setup/SKILL.md
zizmor=${ZIZMOR:-pipx run zizmor==1.31.1}

fail() {
  echo "check-setup-answers: $*" >&2
  exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# count_line FILE LINE: how many lines of FILE equal LINE exactly.
count_line() {
  awk -v want="$2" '$0 == want { n++ } END { print n + 0 }' "$1"
}

# answer NAME DEFAULT ALTERNATIVE [fixed]: DEFAULT is the asset's line for this
# answer (exactly once), ALTERNATIVE the line the skill writes for another
# answer. A fixed alternative is one exact line, so SKILL.md must name it.
variants=()
answer() {
  local name=$1 default=$2 alternative=$3 fixed=${4:-}
  local n
  n=$(count_line "$asset" "$default")
  [ "$n" -eq 1 ] || fail "$name: expected the line '$default' once in $asset, found $n"
  local value=${alternative#"${alternative%%[![:space:]]*}"}
  [ -z "$fixed" ] || grep -qF -- "\`$value\`" "$skill" || fail "$name: $skill does not name the line \`$value\`"
  local out="$tmp/$name.yml"
  awk -v from="$default" -v to="$alternative" '$0 == from { print to; next } { print }' "$asset" >"$out"
  [ "$(diff "$asset" "$out" | grep -c '^[<>]')" -eq 2 ] || fail "$name: the variant changes more than one line"
  variants+=("$out")
  echo "check-setup-answers: $name defaults to '${default#"${default%%[![:space:]]*}"}', alternative '$value'"
}

yq() { go run github.com/mikefarah/yq/v4@v4.54.1 "$@"; }

answer report-only \
  '        continue-on-error: false' \
  '        continue-on-error: true' fixed
[ "$(yq '.jobs.security.steps[] | select(.name == "govulncheck") | .["continue-on-error"]' "$asset")" = false ] ||
  fail "the failure policy line is not on the govulncheck step"
answer schedule \
  '    - cron: "0 6 * * 1"' \
  '    - cron: "30 15 * * 5"'

# Fuzzing off removes the weekly fuzz step, which must be the asset's last
# step: the skill drops the blank line before it and every line after.
fuzz_name='Fuzz each target (weekly)'
[ "$(yq '.jobs.security.steps[-1].name' "$asset")" = "$fuzz_name" ] ||
  fail "'$fuzz_name' is not the last step of $asset"
grep -qF -- "\`$fuzz_name\`" "$skill" || fail "fuzz-off: $skill does not name the step \`$fuzz_name\`"
start=$(grep -nF -- "- name: $fuzz_name" "$asset" | cut -d: -f1)
[ "$(sed -n "$((start - 1))p" "$asset")" = "" ] || fail "fuzz-off: no blank line before '$fuzz_name'"
head -n "$((start - 2))" "$asset" >"$tmp/fuzz-off.yml"
[ "$(yq '[.jobs.security.steps[] | select((.run // "") | test("-fuzz[= ]"))] | length' "$tmp/fuzz-off.yml")" -eq 0 ] ||
  fail "fuzz-off: the variant still fuzzes"
variants+=("$tmp/fuzz-off.yml")
echo "check-setup-answers: fuzz-off removes the step '$fuzz_name'"
answer fuzz-time \
  '          FUZZ_TIME: 1m' \
  '          FUZZ_TIME: 5m'

# The answers file asset records the default answers, so each must describe the
# line the workflow asset carries.
answers=skills/go-security-setup/assets/go-security.md
[ -f "$answers" ] || fail "missing $answers"
# value KEY: the text after "- KEY: " on its one line of the answers file.
value() {
  local n
  n=$(grep -c -- "^- $1: " "$answers" || true)
  [ "$n" -eq 1 ] || fail "$answers: expected one '- $1:' line, found $n"
  grep -- "^- $1: " "$answers" | sed "s/^- $1: //"
}
expect() {
  [ "$2" = "$3" ] || fail "$answers: '$1' is '$2', the workflow asset says '$3'"
}
for key in 'Security workflow' 'Dependabot' 'Toolchain check' 'Security policy'; do
  case "$(value "$key")" in
    yes | yes,* | no) ;;
    *) fail "$answers: '$key' must be yes or no" ;;
  esac
done
expect 'Security workflow' "$(value 'Security workflow')" 'yes, `.github/workflows/security.yml`'
expect 'Dependabot' "$(value 'Dependabot')" 'yes, `.github/dependabot.yml`'
cron=$(yq '.on.schedule[0].cron' "$asset")
expect 'Weekly run' "$(value 'Weekly run' | sed -E 's/.*cron `([^`]*)`$/\1/')" "$cron"
[ "$cron" = '0 6 * * 1' ] && expect 'Weekly run' "$(value 'Weekly run')" 'Monday 06:00 UTC, cron `0 6 * * 1`'
expect 'Fuzzing' "$(value 'Fuzzing')" on
expect 'Fuzz time per target' "$(value 'Fuzz time per target')" "\`$(yq '.jobs.security.steps[-1].env.FUZZ_TIME' "$asset")\`"
expect 'Reachable vulnerability' "$(value 'Reachable vulnerability')" fail
expect 'Channel' "$(value 'Channel')" 'GitHub private vulnerability reporting'
echo "check-setup-answers: $answers records the defaults the workflow asset carries"

go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.12 "${variants[@]}"
$zizmor --offline "${variants[@]}"
echo "check-setup-answers: every answer's alternative is a valid workflow"
