# Issue Tracker: GitHub

This repository's canonical issue tracker is GitHub Issues for
`liu-qingyuan/Git-Symphony`. Use the GitHub CLI (`gh`) for issue operations.

There is no local Markdown issue tracker for this workflow. Do not create or use
`.scratch/` as an issue tracker unless the user explicitly changes this
configuration.

## Conventions

- Create an issue:
  ```bash
  gh issue create --title "..." --body "..."
  ```
- Read an issue, including comments:
  ```bash
  gh issue view <number> --comments
  ```
- List open issues with labels and comments:
  ```bash
  gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'
  ```
- Add a comment:
  ```bash
  gh issue comment <number> --body "..."
  ```
- Add or remove labels:
  ```bash
  gh issue edit <number> --add-label "..."
  gh issue edit <number> --remove-label "..."
  ```
- Close an issue:
  ```bash
  gh issue close <number> --comment "..."
  ```

Run these commands from inside the repository so `gh` infers
`liu-qingyuan/Git-Symphony` from `git remote`.

## Language Convention

Issue titles, bodies, comments, and completion summaries default to Chinese.
Labels, commands, paths, code identifiers, configuration keys, and original
error text keep their original tokens.

## Pull Requests As Triage Surface

External PRs are not a request surface by default. `/triage-lqy` should triage
GitHub Issues, not pull requests, unless the user explicitly turns this on.

If this is later enabled, use:

```bash
gh pr view <number> --comments
gh pr diff <number>
gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments
gh pr comment <number> --body "..."
gh pr edit <number> --add-label "..."
gh pr edit <number> --remove-label "..."
gh pr close <number>
```

When listing external PRs for triage, keep only `CONTRIBUTOR`,
`FIRST_TIME_CONTRIBUTOR`, or `NONE` author associations. Exclude `OWNER`,
`MEMBER`, and `COLLABORATOR`.

GitHub issues and PRs share the same number space. If a bare `#42` may refer to
either one, try `gh pr view 42` first when PR triage is enabled, then fall back
to `gh issue view 42`.

## Skill Phrases

When a skill says "publish to the issue tracker", create a GitHub issue.

When a skill says "fetch the related ticket", run:

```bash
gh issue view <number> --comments
```
