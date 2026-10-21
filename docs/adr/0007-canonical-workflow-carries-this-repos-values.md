# The canonical workflow carries this repo's values

ADR 0002 requires this repo's `.github/workflows/security.yml` to be byte-identical to `skills/go-security-setup/assets/security.yml`, but this repo's Go module is `testdata/fixture`, not the root. So the asset is written with this repo's own values (default branch `main`, module list `testdata/fixture`) and is literally the workflow this repo runs. The skill documents those lines as its **adapted values** and changes only them in a target repo. The identity check stays a plain `cmp`, with no placeholders or normalisation, and every other line of the installed workflow is the line CI ran.

## Considered Options

- **Placeholders in the asset** (`{{MODULES}}`) **with a substituting identity check**: rejected. The asset would no longer be a valid workflow on its own, so `actionlint` and `zizmor` would lint something that never runs.
- **Asset scans the repo root `.`, plus a separate workflow for the fixture**: rejected. The run against the fixture would then not be the asset.

## Consequences

- A change to the asset is a change to this repo's CI in the same PR, and the reverse.
- Each new adapted value (schedule, fuzz duration, failure policy) must be a line this repo can also run with its own value, and it is added to the skill's adapted-values table.
