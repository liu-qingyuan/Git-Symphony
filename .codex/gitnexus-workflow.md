# GitNexus Workflow for Codex

This repository is indexed by GitNexus as `Git-Symphony`. Treat these workflow
rules as shared repository guidance; the `.gitnexus/` index itself is local
generated state.

## Always Do

- Run impact analysis before editing any Swift symbol. Before modifying a
  function, class, method, protocol, or property, inspect upstream impact and
  report the blast radius: direct callers, affected flows, and risk level.
- Run `detect_changes` before committing to verify the change scope matches the
  expected symbols and execution flows.
- Warn the user before proceeding if impact analysis reports HIGH or CRITICAL
  risk.
- Prefer GitNexus query/context tools for unfamiliar code paths when available;
  fall back to local `rg` and source inspection if the GitNexus tools are not
  available in the current Codex session.

## Never Do

- Do not edit a function, class, method, protocol, or property without first
  checking impact.
- Do not ignore HIGH or CRITICAL impact warnings.
- Do not rename symbols with plain find-and-replace when a graph-aware rename
  tool is available.
- Do not commit without checking detected changes.

## Resources

- `gitnexus://repo/Git-Symphony/context` for codebase overview and index freshness.
- `gitnexus://repo/Git-Symphony/clusters` for functional areas.
- `gitnexus://repo/Git-Symphony/processes` for execution flows.
- `gitnexus://repo/Git-Symphony/process/{name}` for step-by-step execution traces.

## Codex Skill Routing

- Use `gitnexus` for local GitNexus workflow routing.
- Use `gitnexus-exploring` for architecture or code-flow exploration.
- Use `gitnexus-impact-analysis` before risky edits.
- Use `gitnexus-debugging` when tracing failing behavior.
- Use `gitnexus-refactoring` for rename, extract, split, move, or restructure
  work.
- Use `gitnexus-pr-review` when reviewing PRs or change sets.
