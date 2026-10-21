#!/usr/bin/env bash
# Proves the weekly half of the canonical security workflow without waiting for
# the schedule to fire:
#   1. the asset has a weekly schedule trigger;
#   2. every step that fuzzes beyond the seed corpora runs only on that schedule,
#      so pull request and push runs never do;
#   3. the fuzz step itself, run as written, fuzzes every fuzz target in each
#      matrix module and passes on the fixture.
# CHECK_FUZZ_TIME (default 5s) replaces the asset's FUZZ_TIME so the check stays
# fast; everything else is the asset's own step.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

asset=$workflow_asset

cron=$(yq '.on.schedule[0].cron // ""' "$asset")
[ -n "$cron" ] || die "$asset has no on.schedule cron"
dow=$(printf '%s' "$cron" | awk '{print $5}')
case "$dow" in
  [0-7] | [A-Za-z][A-Za-z][A-Za-z]) ;;
  *) die "schedule '$cron' is not once a week (day-of-week field: '$dow')" ;;
esac

fuzz_steps=$(yq '[.jobs[].steps[] | select((.run // "") | test("-fuzz[= ]"))] | length' "$asset")
[ "$fuzz_steps" -ge 1 ] || die "$asset has no step that runs go test -fuzz"
ungated=$(yq '[.jobs[].steps[] | select((.run // "") | test("-fuzz[= ]")) | select(.if != "github.event_name == '\''schedule'\''")] | length' "$asset")
[ "$ungated" -eq 0 ] || die "$ungated fuzz step(s) are not gated on github.event_name == 'schedule'"

step_run=$(yq '.jobs.security.steps[] | select((.run // "") | test("-fuzz[= ]")) | .run' "$asset")
step_shell=$(yq '.jobs.security.steps[] | select((.run // "") | test("-fuzz[= ]")) | .shell // ""' "$asset")
[ "$step_shell" = bash ] || die "the fuzz step must set shell: bash so a failing pipeline fails the step"

mkwork
tmp=$work/fuzz-step.sh
printf '%s\n' "$step_run" >"$tmp"

modules=$(yq '.jobs.security.strategy.matrix.module[]' "$asset")
for module in $modules; do
  echo "$check: running the fuzz step in $module"
  log=$( (cd "$module" && FUZZ_TIME="${CHECK_FUZZ_TIME:-5s}" bash --noprofile --norc -eo pipefail "$tmp") 2>&1) || {
    printf '%s\n' "$log" >&2
    die "the fuzz step failed in $module"
  }
  printf '%s\n' "$log"
  want=$(cd "$module" && go test -list '^Fuzz' ./... | grep -c '^Fuzz' || true)
  got=$(printf '%s\n' "$log" | grep -c '^::group::Fuzz ' || true)
  [ "$want" -ge 1 ] || die "$module has no fuzz target to prove the step on"
  [ "$got" -eq "$want" ] || die "the fuzz step fuzzed $got of $want fuzz targets in $module"
done
echo "$check: weekly schedule set, fuzzing gated on it, and the fuzz step passes"
