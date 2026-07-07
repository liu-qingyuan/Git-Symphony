# Matt Pocock Workflow for Codex

This repository runs Matt Pocock engineering workflow skills through Codex first.
Do not use Claude Code-specific assumptions unless the user explicitly asks for
Claude Code behavior.

## Configuration Files

- `docs/agents/issue-tracker.md` defines the canonical issue tracker.
- `docs/agents/triage-labels.md` defines the triage label vocabulary.
- `docs/agents/domain.md` defines domain-document discovery rules.

These files are shared workflow configuration for this repository. Keep them in
git so future clones know which issue tracker, triage labels, and domain-doc
layout the engineering workflow expects.

## Local Versus Remote

The canonical issue tracker is GitHub Issues for `liu-qingyuan/Git-Symphony`.
There is no local `.scratch/` issue tracker for this workflow.

Creating or editing GitHub issues changes remote repository state. It does not
create a git diff, but it is still a remote action. Use `gh issue ...` commands
only when the workflow requires publishing to the issue tracker or the user
explicitly asks for a remote issue operation.

## Agent Preference

When a Matt Pocock skill mentions an agent, interpret it as Codex unless the
user names another agent. Prefer Codex CLI/project configuration over
Claude-specific files for this workflow.
