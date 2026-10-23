#!/usr/bin/env bash
# Proves the go-security-setup answers against the canonical workflow:
#   1. the asset carries the default answer on each answer's line;
#   2. a non-default answer, applied as the skill applies it (one line
#      replaced, nothing else), is still a workflow actionlint and zizmor
#      accept, and the skill's adapted-values table names any fixed line;
#   3. the answers file asset records those defaults, and an ephemeral run as
#      the source of each scanner under "Scanner sources", each of which has a
#      row in the skill's answers file table.
# ZIZMOR overrides the zizmor command (default: pipx run zizmor at the version
# in tools.env).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

asset=$workflow_asset
skill=$setup_skill
zizmor=${ZIZMOR:-pipx run zizmor==$ZIZMOR_VERSION}

mkwork

# answer NAME DEFAULT ALTERNATIVE [fixed]: DEFAULT is the asset's line for this
# answer (exactly once), ALTERNATIVE the line the skill writes for another
# answer. A fixed alternative is one exact line, so SKILL.md must name it.
variants=()
answer() {
  local name=$1 default=$2 alternative=$3 fixed=${4:-}
  local n
  n=$(count_line "$asset" "$default")
  [ "$n" -eq 1 ] || die "$name: expected the line '$default' once in $asset, found $n"
  local value=${alternative#"${alternative%%[![:space:]]*}"}
  [ -z "$fixed" ] || grep -qF -- "\`$value\`" "$skill" || die "$name: $skill does not name the line \`$value\`"
  local out="$work/$name.yml"
  awk -v from="$default" -v to="$alternative" '$0 == from { print to; next } { print }' "$asset" >"$out"
  [ "$(diff "$asset" "$out" | grep -c '^[<>]')" -eq 2 ] || die "$name: the variant changes more than one line"
  variants+=("$out")
  echo "$check: $name defaults to '${default#"${default%%[![:space:]]*}"}', alternative '$value'"
}

answer report-only \
  '        continue-on-error: false' \
  '        continue-on-error: true' fixed
[ "$(yq '.jobs.security.steps[] | select(.name == "govulncheck") | .["continue-on-error"]' "$asset")" = false ] ||
  die "the failure policy line is not on the govulncheck step"
answer schedule \
  '    - cron: "0 6 * * 1"' \
  '    - cron: "30 15 * * 5"'

# Fuzzing off removes the weekly fuzz step, which must be the asset's last
# step: the skill drops the blank line before it and every line after.
fuzz_name='Fuzz each target (weekly)'
[ "$(yq '.jobs.security.steps[-1].name' "$asset")" = "$fuzz_name" ] ||
  die "'$fuzz_name' is not the last step of $asset"
grep -qF -- "\`$fuzz_name\`" "$skill" || die "fuzz-off: $skill does not name the step \`$fuzz_name\`"
start=$(grep -nF -- "- name: $fuzz_name" "$asset" | cut -d: -f1)
[ "$(sed -n "$((start - 1))p" "$asset")" = "" ] || die "fuzz-off: no blank line before '$fuzz_name'"
head -n "$((start - 2))" "$asset" >"$work/fuzz-off.yml"
[ "$(yq '[.jobs.security.steps[] | select((.run // "") | test("-fuzz[= ]"))] | length' "$work/fuzz-off.yml")" -eq 0 ] ||
  die "fuzz-off: the variant still fuzzes"
variants+=("$work/fuzz-off.yml")
echo "$check: fuzz-off removes the step '$fuzz_name'"
answer fuzz-time \
  '          FUZZ_TIME: 1m' \
  '          FUZZ_TIME: 5m'

# The answers file asset records the default answers, so each must describe the
# line the workflow asset carries.
answers=$answers_asset
[ -f "$answers" ] || die "missing $answers"
# value KEY: the text after "- KEY: " on its one line of the answers file.
value() {
  local n
  n=$(grep -c -- "^- $1: " "$answers" || true)
  [ "$n" -eq 1 ] || die "$answers: expected one '- $1:' line, found $n"
  grep -- "^- $1: " "$answers" | sed "s/^- $1: //"
}
expect() {
  [ "$2" = "$3" ] || die "$answers: '$1' is '$2', the workflow asset says '$3'"
}
for key in 'Security workflow' 'Dependabot' 'Toolchain check' 'Security policy'; do
  case "$(value "$key")" in
    yes | yes,* | no) ;;
    *) die "$answers: '$key' must be yes or no" ;;
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
echo "$check: $answers records the defaults the workflow asset carries"

sources=$(awk '/^## Scanner sources/ { inside = 1; next } inside && /^## / { exit } inside && /^- [^:]+: / { sub(/^- /, ""); sub(/: .*/, ""); print }' "$answers")
[ -n "$sources" ] || die "$answers: no keys under '## Scanner sources'"
while IFS= read -r key; do
  [ "$(value "$key")" = 'ephemeral run' ] || die "$answers: the source of '$key' is '$(value "$key")', not the default 'ephemeral run'"
  grep -qF -- "| \`$key\` | \`ephemeral run\` |" "$skill" || die "$skill: the answers file table has no row for \`$key\`"
done <<<"$sources"
echo "$check: $answers records an ephemeral run as the source of $(printf '%s\n' "$sources" | paste -sd ' ' -)"

actionlint "${variants[@]}"
$zizmor --offline "${variants[@]}"
echo "$check: every answer's alternative is a valid workflow"
