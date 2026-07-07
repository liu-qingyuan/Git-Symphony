# Git-Symphony

Git-Symphony is a small workflow repository for experimenting with GitHub issue
watching and Ralph-style agent orchestration.

The repository keeps the shared agent policy in git, while local generated
tooling state stays out of the remote.

## Shared Configuration

- `AGENTS.md` is the repository-level agent policy.
- `docs/agents/issue-tracker.md` defines the canonical issue tracker.
- `docs/agents/triage-labels.md` defines the triage label vocabulary.
- `docs/agents/domain.md` defines domain-document discovery rules.

The canonical issue tracker is GitHub Issues for
`liu-qingyuan/Git-Symphony`. External pull requests are not part of the triage
queue by default.

## Local State

These paths are intentionally ignored because they are generated or
machine-specific:

- `.gitnexus/`
- `.agents/`
- `.claude/`
- `.codex/`
- `CLAUDE.md`
- `skills-lock.json`

Regenerate local GitNexus state from a checkout with:

```bash
gitnexus analyze
```

## Local Workflow Helper

`lqy-local-workflow.sh` deploys local Codex/Ralph/GitNexus workflow files into
another checkout or git worktree.

```bash
./lqy-local-workflow.sh deploy /path/to/project-worktree --template-repo /path/to/template-repo
```

Create a new worktree and deploy the local workflow:

```bash
./lqy-local-workflow.sh worktree /path/to/project-issue-123 --branch issue-123 --base origin/main
```

The template repo is resolved in this order:

1. `--template-repo`
2. `LOCAL_WORKFLOW_TEMPLATE_REPO`
3. the current git repository

Pass `--no-gitnexus-index` to skip GitNexus indexing during deployment.
