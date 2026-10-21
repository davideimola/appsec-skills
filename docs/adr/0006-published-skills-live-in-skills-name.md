# Published skills live in `skills/<name>/`, and nowhere else holds a skill file

Every published skill is a folder `skills/<name>/` with `SKILL.md` at its root, plus its own `assets/`, `references/` and `scripts/` when it needs them. The folder name equals the skill's `name`. No `SKILL.md` exists anywhere else in the repo, and CI (`scripts/ci/check-skills-folder.sh`) fails if one does. `npx skills add` walks `skills/` and about thirty agent folders (`.claude/skills/`, `.agents/skills/`, …) up to three levels deep, so any stray `SKILL.md`, such as a `skill-creator` workspace snapshot or a maintainer's development skill, would be offered for install.

## Consequences

- `go-security-audit` and `verify-with-fuzz` go in `skills/go-security-audit/` and `skills/verify-with-fuzz/`. The Claude Code marketplace manifest lists the same folders explicitly.
- `skill-creator` workspaces and evals stay outside the repo (for example in a scratch directory), and evals run on a copy of the fixture.
- Development skills for this repo are installed in the maintainer's user folder, not committed here.
- CI scripts live in `scripts/ci/` and run the same way locally and in CI.
