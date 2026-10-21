# Every file a skill writes is a CI-verified asset

A skill never writes configuration from scratch. Every file it can write already exists in the skill's `assets/` and is verified by this repo's CI: validated with `actionlint` and `zizmor`, every action pinned to a full SHA, and the workflow run against `testdata/fixture/`. The skill adapts the asset to the target repo. A model writing CI from scratch invents action versions and SHAs, which would make a supply chain skill ship supply chain bugs.

## Consequences

- The canonical `security.yml` also runs on this repo, and CI fails if the copy in `.github/workflows/` differs from the asset. A Dependabot bump to the pins therefore forces the asset to be synced in the same PR.
- The gosec and govulncheck versions the audit pins for `go run` are declared as `tool`s in the fixture's `go.mod` and required directly through its `tools.go`, so Dependabot tracks them too, and CI checks that each pair matches.
- This verifies the files, not the agent's behaviour. LLM-based evals of the skills are out of scope for v1.
