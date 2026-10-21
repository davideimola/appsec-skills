# Reference examples quote the fixture byte for byte

A skill's reference example (code an agent copies the shape of, such as `verify-with-fuzz`'s deny-by-default authorization and its fuzz property) lives in `skills/<name>/references/*.md` as fenced `go` blocks. Each block follows a marker line, `<!-- fixture: <path> -->`, and must equal `testdata/fixture/<path>` byte for byte. `scripts/ci/check-reference-examples.sh` fails on any difference, so the example in the skill is the code CI proves (for the authorization pair, `scripts/ci/check-fuzz-catches-vulnerable.sh`).

## Considered Options

- **Pointing the skill at `testdata/fixture/`**: rejected. An installed skill is only its own folder, so the target repo has no fixture to read.
- **Copying the `.go` files into the skill folder**: rejected. A skill folder installed inside a Go module would turn them into a package that `go build ./...`, `go vet` and `govulncheck` pick up in the target repo.
- **A hand-written example in prose**: rejected. It would drift from the proven code, which ADR 0002 rules out for anything a skill copies.

## Consequences

- Changing the fixture code a reference quotes means changing the reference in the same PR.
- A reference file that must quote the fixture is listed in the script's `required` array, so deleting its blocks fails CI too.
