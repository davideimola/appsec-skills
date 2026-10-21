# Security policy

## Reporting a vulnerability

Report vulnerabilities privately through GitHub private vulnerability reporting: [open a draft advisory](https://github.com/davideimola/go-security-skills/security/advisories/new). Please do not open a public issue.

In scope: anything in this repo that could make an agent write something unsafe into a target repo, such as a canonical asset with a weak permission or an unpinned action, a skill instruction that leads an agent to skip a check or edit files it should not touch, or a flaw in this repo's own CI.

Include the skill and file involved, what an agent did or could be led to do, and how to reproduce it. Fixes ship on `main`; there are no release branches.
