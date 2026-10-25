# Sourced by every scripts/ci check: `. "$(dirname "$0")/lib.sh"`.
#
# It moves to the repo root, so a check runs the same from any directory, loads
# the pinned tool versions from tools.env, and gives each check:
#   fail MSG...      report a failure and keep going (sets status=1)
#   die MSG [LOG]    report a failure, print LOG indented if given, and exit 1
#   finish MSG       print MSG when nothing failed, then exit with the status
#   mkwork           create $work, a temporary directory removed on exit
#   copy_fixture     mkwork, copy the fixture into $work and cd there
#   count_line F L   how many lines of file F equal L exactly
# Messages are prefixed with the check's file name.

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# shellcheck source=tools.env
. scripts/ci/tools.env

check=$(basename "$0" .sh)
status=0

fail() {
  echo "$check: $*" >&2
  status=1
}

die() {
  echo "$check: $1" >&2
  if [ -n "${2:-}" ]; then
    sed 's/^/  /' "$2" >&2
  fi
  exit 1
}

finish() {
  if [ "$status" -eq 0 ]; then
    echo "$check: $*"
  fi
  exit "$status"
}

mkwork() {
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
}

copy_fixture() {
  [ -f "$fixture/go.mod" ] || die "missing $fixture/go.mod"
  mkwork
  cp -R "$fixture/." "$work/"
  cd "$work"
}

count_line() {
  awk -v want="$2" '$0 == want { n++ } END { print n + 0 }' "$1"
}

# Pinned tools, run at the versions in tools.env.
yq() { go run "github.com/mikefarah/yq/v4@$YQ_VERSION" "$@"; }
actionlint() { go run "github.com/rhysd/actionlint/cmd/actionlint@$ACTIONLINT_VERSION" "$@"; }

# Shared paths, from the repo root.
fixture=testdata/fixture
fixture_ts=testdata/fixture-ts
setup_skill=skills/appsec-setup/SKILL.md
audit_skill=skills/appsec-audit/SKILL.md
verify_skill=skills/appsec-prove/SKILL.md
workflow_asset=skills/appsec-setup/assets/security.yml
dependabot_asset=skills/appsec-setup/assets/dependabot.yml
answers_asset=skills/appsec-setup/assets/appsec.md
policy_asset=skills/appsec-setup/assets/SECURITY.md
