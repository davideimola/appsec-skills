# Go security skills

Agent Skills that bring the practices of the talk "Securing Go for Production" into a Go repo, and prove that what they write works.

## Skills and what they touch

**Target repo**:
The repo a skill is run in, owned by whoever installed the skills.
_Avoid_: user repo, consumer repo, project

**Canonical asset**:
A file shipped with a skill that the skill copies and adapts into the target repo, never writing it from scratch. Its correctness is proven in this repo before it ships.
_Avoid_: template, snippet, example config

**Adapted values**:
The only lines of a canonical asset a skill may change in the target repo, listed in the skill. Elsewhere the asset keeps the values of this repo, which runs it (ADR 0007).
_Avoid_: placeholders, variables, parameters

**Setup answers**:
What the target repo's owner chose when `go-security-setup` asked, saved in the target repo's **answers file**, `docs/agents/go-security.md`. The audit leaves out what the answers opt out of.
_Avoid_: config, settings, preferences

**Fixture**:
The small Go module that exists only so canonical assets and reference examples can be proven to work.
_Avoid_: example app, sample service, demo

## The loop

**The loop**:
Analyze, find, test, verify, fix: the order in which a security problem moves from suspicion to fix.
_Avoid_: workflow, pipeline, process

**Finding**:
One problem the audit reports, with its severity, evidence, hypothesis and suggested fix.
_Avoid_: issue, alert, vulnerability (a vulnerability is one kind of finding)

**Signal**:
Tool output that may point at a problem, such as a gosec issue. It becomes a finding only once the code at its `file:line` confirms it; otherwise it is dismissed with the reason the code gives.
_Avoid_: alert, false positive (that is a dismissed signal)

**Context**:
The vulnerabilities `govulncheck` knows in packages and modules the code requires but does not call, reported as one unreachable count and never as findings.
_Avoid_: unreachable findings, low-severity findings

**Hypothesis**:
What a finding claims is wrong, before a failing test confirms it.
_Avoid_: guess, suspicion

**Evidence**:
What makes a finding checkable by someone else: tool output, a `file:line`, or a failing test.
_Avoid_: proof

**Logic finding**:
A finding about who may do what or what input is trusted, which needs a failing test before any fix.
_Avoid_: business-logic bug

**Mechanical fix**:
A fix that only changes a version, a default or a configuration value, applied after confirmation without a test first.
_Avoid_: quick fix, trivial fix

**Accepted risk**:
A finding the target repo's owner chose not to fix, recorded with a reason and a review date.
_Avoid_: ignore, suppression, waiver
