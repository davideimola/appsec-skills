# Proven examples are generic, one reference per language

`appsec-prove` keeps its steps language-neutral and moves everything that depends on the language into one reference per language, `references/go.md` and `references/typescript.md`: where the tests go and their names, the two commands, the budget, how a failing input is kept, and the proven example. CI reads the commands from each reference's `## Commands` block, so the commands an agent runs are the ones CI runs on the fixture. A ```` ```go ```` quote is checked against `testdata/fixture/`, a ```` ```ts ```` quote against `testdata/fixture-ts/` (ADR 0009).

The example in both fixtures is `CanEditProject` / `canEditProject`: the project's owner or an admin of its organization may edit it, a project with no organization is denied to everyone, and an unassigned project has no owner way in. Its vulnerable version has two bugs, an owner check that matches a caller with no ID on an unassigned project, and a member let in where the admin role is required. It replaces `CanManageOrg`, the incident from the talk: an agent copies the shape of the example, and one real incident taught one bug in one data shape. The new one exercises what the blind runs in `docs/research/2026-10-25-ts-prove-feasibility/` showed agents miss: two relations (same org, same owner), a deny-all condition carried on every way in, and unresolved IDs on both the caller and the target.

## Considered Options

- **Keep the talk's incident**: rejected. Too specific to teach the method, and it ties the skill to one story.
- **A catalog of patterns (tenant isolation, ownership, role hierarchy, trusted input), each with its own fixture**: deferred. Each pattern costs a fixture and CI per language; they are added one at a time, trusted input first, since the skill's description promises it and no example covers it yet.
- **Prose only, no code example**: rejected by ADR 0009.

## Consequences

- The talk's demo lives in its own repository and is unaffected.
- ADR 0008 still holds with the new names: the vulnerable Go version sits behind `-tags vulnerable`, and the TypeScript one behind `VULNERABLE=1`.
- A new language means a reference with a `## Commands` block of two commands, a fixture, and a check that runs those commands.
