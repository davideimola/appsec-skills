# appsec-ci answers

`appsec-ci` wrote this file from the owner's answers and offers them as the defaults the next time it runs. `appsec-audit` reads it: it does not report a piece marked `no`. To change an answer, run `appsec-ci` again: it applies the change to the installed files and updates this file. Where the scanners come from is in `docs/agents/appsec.md`, written by `appsec-setup`.

## What to install

- Security workflow: yes, `.github/workflows/security.yml`
- Dependabot: yes, `.github/dependabot.yml`
- Toolchain check: yes
- Security policy: yes, `SECURITY.md`

## Schedule

- Weekly run: Monday 06:00 UTC, cron `0 6 * * 1`

## Weekly fuzzing

- Fuzzing: on
- Fuzz time per target: `1m`

## Failure policy

- Reachable vulnerability: fail

## Reporting channel

- Channel: GitHub private vulnerability reporting

