#!/usr/bin/env bash
# Proves the appsec-setup security policy asset against the answers:
#   1. the asset's reporting line is the default channel (GitHub private
#      vulnerability reporting) for this repo, exactly once;
#   2. SKILL.md names every reporting line the skill may write instead, each
#      a single line that replaces that one line;
#   3. the repo-specific Scope section is the asset's last section, so a
#      target repo's copy drops it whole and keeps a policy with no scope.
# It matches the skill's prose on purpose (each reporting line, `## Scope`):
# rewording those lines means updating this check in the same change.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

asset=$policy_asset
skill=$setup_skill
answers=$answers_asset

[ -f "$asset" ] || die "missing $asset"

repo=davideimola/appsec-skills
suffix=' Please do not open a public issue.'
pvr_prefix='Report vulnerabilities privately through GitHub private vulnerability reporting: [open a draft advisory](https://github.com/'
pvr_line="${pvr_prefix}${repo}/security/advisories/new).${suffix}"

n=$(awk -v want="$pvr_line" '$0 == want { n++ } END { print n + 0 }' "$asset")
[ "$n" -eq 1 ] || die "expected the reporting line once in $asset, found $n: $pvr_line"
[ "$(grep -c '^Report vulnerabilities' "$asset")" -eq 1 ] || die "$asset has more than one reporting line"
grep -qxF -- '- Channel: GitHub private vulnerability reporting' "$answers" ||
  die "$answers does not default the channel to GitHub private vulnerability reporting"
echo "$check: $asset reports through GitHub private vulnerability reporting for $repo"

# Each channel's line, with the parts the skill fills in, as SKILL.md must
# name it in backticks.
templates=(
  "${pvr_prefix}<owner>/<repo>/security/advisories/new).${suffix}"
  "Report vulnerabilities privately by email to <address>.${suffix}"
  "Report vulnerabilities privately at <URL>.${suffix}"
)
for t in "${templates[@]}"; do
  grep -qF -- "\`$t\`" "$skill" || die "$skill does not name the reporting line \`$t\`"
done
echo "$check: $skill names the reporting line of every channel"

# The Scope section describes this repo only: it must be the last section,
# after a blank line, so the skill removes it and every line after it.
start=$(grep -nx '## Scope' "$asset" | cut -d: -f1)
[ -n "$start" ] || die "$asset has no '## Scope' heading"
[ "$(sed -n "$((start - 1))p" "$asset")" = "" ] || die "no blank line before '## Scope'"
[ "$(tail -n "+$((start + 1))" "$asset" | grep -c '^#')" -eq 0 ] || die "'## Scope' is not the last section of $asset"
grep -qF -- '`## Scope`' "$skill" || die "$skill does not name the section \`## Scope\`"
head -n "$((start - 2))" "$asset" | grep -q '^Report vulnerabilities' || die "removing Scope removes the reporting line"
echo "$check: a target repo's copy drops the Scope section whole"
