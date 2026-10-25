# Security policy

## Reporting a vulnerability

Report vulnerabilities privately through GitHub private vulnerability reporting: [open a draft advisory](https://github.com/davideimola/appsec-skills/security/advisories/new). Please do not open a public issue.

Include what is affected, how to reproduce the problem, and what an attacker could do with it.

## Scope

Anything in this repo that could make an agent write something unsafe into a target repo is in scope: a canonical asset with a weak permission or an unpinned action, a skill instruction that leads an agent to skip a check or edit files it should not touch, or a flaw in this repo's own CI. Name the skill and file involved, and what an agent did or could be led to do. Fixes ship on `main`; there are no release branches.
