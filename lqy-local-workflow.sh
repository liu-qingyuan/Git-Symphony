#!/usr/bin/env bash

# Deploy local AI workflow files into an existing checkout or git worktree.
# The script keeps Codex/Matt/Ralph/GitNexus workflow files local by updating
# each target worktree's git exclude file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT_NAME="$(basename "$0")"
DEFAULT_GIT_NAME="${LOCAL_WORKFLOW_GIT_NAME:-liu-qingyuan}"
DEFAULT_GIT_EMAIL="${LOCAL_WORKFLOW_GIT_EMAIL:-2981185462@qq.com}"
COMMAND_TIMEOUT_SECONDS="${LOCAL_WORKFLOW_COMMAND_TIMEOUT_SECONDS:-300}"

WORKFLOW_PATHS=(
  ".codex"
  "docs/agents"
  ".agents"
  "skills-lock.json"
)

EXCLUDE_PATTERNS=(
  ".gitnexus/"
  ".claude/"
  ".codex/config.toml"
  ".codex/matt-pocock-workflow.md"
  ".codex/gitnexus-workflow.md"
  "docs/agents/"
  ".agents/"
  "skills-lock.json"
)

usage() {
  cat <<EOF
usage: $SCRIPT_NAME [-h] {deploy,worktree} ...

Deploy local Codex/Ralph/GitNexus workflow files for any git repository.
GitNexus pure indexing runs by default and can be disabled with --no-gitnexus-index.

commands:
  deploy     Deploy into an existing repo or linked worktree.
  worktree   Create a git worktree and deploy local workflow files.

examples:
  Deploy into an existing checkout or worktree:
    $SCRIPT_NAME deploy /path/to/project-worktree --template-repo /path/to/project

  Deploy without refreshing the GitNexus index:
    $SCRIPT_NAME deploy /path/to/project-worktree --no-gitnexus-index

  Refresh an existing local workflow deployment:
    $SCRIPT_NAME deploy /path/to/project-worktree --force

  Create a new issue worktree and deploy local workflow files:
    $SCRIPT_NAME worktree /path/to/project-issue-123 --branch issue-123 --base origin/main

options:
  -h, --help  Show this help message.
EOF
}

deploy_usage() {
  cat <<EOF
usage: $SCRIPT_NAME deploy [target] [options]

Copy local AI workflow files into an existing checkout or linked worktree.

arguments:
  target                     Target repo/worktree path. Defaults to current directory.

options:
  --template-repo PATH        Source checkout with local workflow files.
                              Default: LOCAL_WORKFLOW_TEMPLATE_REPO, then current git repo.
  --managed-path PATH         Copy an additional workflow path. Repeatable.
  --no-default-managed-paths  Clear default managed paths before --managed-path entries.
  --exclude-pattern PATTERN   Add a git info/exclude pattern. Repeatable.
  --no-default-exclude-patterns
                              Clear default exclude patterns before custom entries.
  --force                    Overwrite managed workflow files if they already exist.
  --skip-git-identity        Do not set repository-local git user.name/user.email.
  --git-name NAME            Git user.name to set. Default: $DEFAULT_GIT_NAME
  --git-email EMAIL          Git user.email to set. Default: $DEFAULT_GIT_EMAIL
  --command-timeout SECONDS   Timeout for long-running CLI commands. Default: $COMMAND_TIMEOUT_SECONDS
  --gitnexus-index           Run GitNexus pure indexing after deployment. Default.
  --no-gitnexus-index        Skip GitNexus indexing.
  --gitnexus-name NAME       GitNexus repo alias. Default: target directory name.
  -h, --help                 Show this help message.

examples:
  $SCRIPT_NAME deploy .
  $SCRIPT_NAME deploy /path/to/worktree --template-repo /path/to/source
  $SCRIPT_NAME deploy /path/to/worktree --force
  $SCRIPT_NAME deploy /path/to/worktree --no-gitnexus-index
EOF
}

worktree_usage() {
  cat <<EOF
usage: $SCRIPT_NAME worktree path [options]

Create a git worktree from the template repo, then deploy local AI workflow files.

arguments:
  path                       New worktree path.

options:
  --template-repo PATH        Source checkout with local workflow files.
                              Default: LOCAL_WORKFLOW_TEMPLATE_REPO, then current git repo.
  --managed-path PATH         Copy an additional workflow path. Repeatable.
  --no-default-managed-paths  Clear default managed paths before --managed-path entries.
  --exclude-pattern PATTERN   Add a git info/exclude pattern. Repeatable.
  --no-default-exclude-patterns
                              Clear default exclude patterns before custom entries.
  --branch NAME              New local branch name for the worktree.
  --base REF                 Base ref for the worktree. Default: origin/main
  --force                    Overwrite managed workflow files if they already exist.
  --skip-git-identity        Do not set repository-local git user.name/user.email.
  --git-name NAME            Git user.name to set. Default: $DEFAULT_GIT_NAME
  --git-email EMAIL          Git user.email to set. Default: $DEFAULT_GIT_EMAIL
  --command-timeout SECONDS   Timeout for long-running CLI commands. Default: $COMMAND_TIMEOUT_SECONDS
  --gitnexus-index           Run GitNexus pure indexing after deployment. Default.
  --no-gitnexus-index        Skip GitNexus indexing.
  --gitnexus-name NAME       GitNexus repo alias. Default: target directory name.
  -h, --help                 Show this help message.

examples:
  $SCRIPT_NAME worktree /path/to/project-issue-123 --branch issue-123
  $SCRIPT_NAME worktree /path/to/project-spike --branch spike/local-models --base origin/main
  $SCRIPT_NAME worktree /path/to/project-docs --branch docs/local --no-gitnexus-index
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

# Resolve the workflow source repo late so the same script can bootstrap any repo.
resolve_template_repo() {
  local requested="$1"
  if [[ -n "$requested" ]]; then
    git_toplevel "$requested"
    return
  fi

  if [[ -n "${LOCAL_WORKFLOW_TEMPLATE_REPO:-}" ]]; then
    git_toplevel "$LOCAL_WORKFLOW_TEMPLATE_REPO"
    return
  fi

  if git -C "$PWD" rev-parse --show-toplevel >/dev/null 2>&1; then
    git_toplevel "$PWD"
    return
  fi

  die "template repo not found; run inside a git repo, set LOCAL_WORKFLOW_TEMPLATE_REPO, or pass --template-repo"
}

# Enforce a bounded runtime for slow external commands without requiring GNU timeout.
run_with_timeout() {
  local seconds="$1"
  shift
  perl -e 'alarm shift; exec @ARGV' "$seconds" "$@"
}

validate_timeout_seconds() {
  local seconds="$1"
  [[ "$seconds" =~ ^[1-9][0-9]*$ ]] || die "--command-timeout requires a positive integer"
}

git_toplevel() {
  local path="$1"
  git -C "$path" rev-parse --show-toplevel
}

git_path() {
  local repo="$1"
  local relative_git_path="$2"
  local result
  result="$(git -C "$repo" rev-parse --git-path "$relative_git_path")"
  case "$result" in
    /*) printf '%s\n' "$result" ;;
    *) printf '%s\n' "$repo/$result" ;;
  esac
}

copy_managed_path() {
  local source_repo="$1"
  local target_repo="$2"
  local relative_path="$3"
  local force="$4"
  local source="$source_repo/$relative_path"
  local target="$target_repo/$relative_path"

  if [[ ! -e "$source" ]]; then
    printf 'skip missing template path: %s\n' "$relative_path"
    return
  fi

  if [[ -e "$target" ]]; then
    if [[ "$force" != "1" ]]; then
      die "$target already exists; rerun with --force to overwrite managed workflow files"
    fi
    rm -rf "$target"
  fi

  mkdir -p "$(dirname "$target")"
  if [[ -d "$source" ]]; then
    cp -R "$source" "$target"
  else
    cp -p "$source" "$target"
  fi
  printf 'copied %s\n' "$relative_path"
}

ensure_exclude_patterns() {
  local repo="$1"
  local exclude_path
  exclude_path="$(git_path "$repo" "info/exclude")"
  mkdir -p "$(dirname "$exclude_path")"
  touch "$exclude_path"

  local additions=()
  local pattern
  for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    if ! grep -Fxq "$pattern" "$exclude_path"; then
      additions+=("$pattern")
    fi
  done

  if [[ "${#additions[@]}" -eq 0 ]]; then
    printf 'exclude already configured: %s\n' "$exclude_path"
    return
  fi

  {
    printf '\n# Local AI workflow files\n'
    for pattern in "${additions[@]}"; do
      printf '%s\n' "$pattern"
    done
  } >>"$exclude_path"
  printf 'updated exclude: %s\n' "$exclude_path"
}

set_git_identity() {
  local repo="$1"
  local name="$2"
  local email="$3"
  git -C "$repo" config user.name "$name"
  git -C "$repo" config user.email "$email"
  printf 'set git identity: %s <%s>\n' "$name" "$email"
}

current_branch_or_commit() {
  local repo="$1"
  local branch
  branch="$(git -C "$repo" branch --show-current)"
  if [[ -n "$branch" ]]; then
    printf '%s\n' "$branch"
  else
    printf 'detached-%s\n' "$(git -C "$repo" rev-parse --short HEAD)"
  fi
}

gitnexus_runner() {
  local source_repo="$1"
  local runner="$source_repo/.gitnexus/run.cjs"
  if [[ -f "$runner" ]]; then
    printf 'node\0%s\0' "$runner"
  elif command -v gitnexus >/dev/null 2>&1; then
    printf 'gitnexus\0'
  elif command -v npx >/dev/null 2>&1; then
    printf 'npx\0gitnexus\0'
  else
    die "GitNexus runner not found; install gitnexus or pass --no-gitnexus-index"
  fi
}

run_gitnexus_index() {
  local source_repo="$1"
  local target_repo="$2"
  local repo_name="$3"
  local branch
  branch="$(current_branch_or_commit "$target_repo")"

  printf 'running GitNexus pure index for %s branch %s\n' "$repo_name" "$branch"
  printf 'GitNexus analyze uses --index-only, so it will not update AGENTS.md, CLAUDE.md, or skills.\n'

  local runner_parts=()
  while IFS= read -r -d '' part; do
    runner_parts+=("$part")
  done < <(gitnexus_runner "$source_repo")

  run_with_timeout "$COMMAND_TIMEOUT_SECONDS" "${runner_parts[@]}" analyze \
    --index-only \
    --name "$repo_name" \
    --branch "$branch" \
    "$target_repo"
}

deploy_workflow() {
  local target="."
  local template_repo=""
  local force="0"
  local skip_git_identity="0"
  local git_name="$DEFAULT_GIT_NAME"
  local git_email="$DEFAULT_GIT_EMAIL"
  local gitnexus_index="1"
  local gitnexus_name=""

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -h|--help)
        deploy_usage
        exit 0
        ;;
      --template-repo)
        [[ "$#" -ge 2 ]] || die "--template-repo requires a path"
        template_repo="$2"
        shift 2
        ;;
      --managed-path)
        [[ "$#" -ge 2 ]] || die "--managed-path requires a path"
        WORKFLOW_PATHS+=("$2")
        shift 2
        ;;
      --no-default-managed-paths)
        WORKFLOW_PATHS=()
        shift
        ;;
      --exclude-pattern)
        [[ "$#" -ge 2 ]] || die "--exclude-pattern requires a pattern"
        EXCLUDE_PATTERNS+=("$2")
        shift 2
        ;;
      --no-default-exclude-patterns)
        EXCLUDE_PATTERNS=()
        shift
        ;;
      --force)
        force="1"
        shift
        ;;
      --skip-git-identity)
        skip_git_identity="1"
        shift
        ;;
      --git-name)
        [[ "$#" -ge 2 ]] || die "--git-name requires a value"
        git_name="$2"
        shift 2
        ;;
      --git-email)
        [[ "$#" -ge 2 ]] || die "--git-email requires a value"
        git_email="$2"
        shift 2
        ;;
      --command-timeout)
        [[ "$#" -ge 2 ]] || die "--command-timeout requires seconds"
        validate_timeout_seconds "$2"
        COMMAND_TIMEOUT_SECONDS="$2"
        shift 2
        ;;
      --gitnexus-index)
        gitnexus_index="1"
        shift
        ;;
      --no-gitnexus-index)
        gitnexus_index="0"
        shift
        ;;
      --gitnexus-name)
        [[ "$#" -ge 2 ]] || die "--gitnexus-name requires a value"
        gitnexus_name="$2"
        shift 2
        ;;
      --*)
        die "unknown deploy option: $1"
        ;;
      *)
        target="$1"
        shift
        ;;
    esac
  done

  local source_repo
  local target_repo
  source_repo="$(resolve_template_repo "$template_repo")"
  target_repo="$(git_toplevel "$target")"
  if [[ -z "$gitnexus_name" ]]; then
    gitnexus_name="$(basename "$target_repo")"
  fi

  printf 'template repo: %s\n' "$source_repo"
  printf 'target repo:   %s\n' "$target_repo"

  local relative_path
  for relative_path in "${WORKFLOW_PATHS[@]}"; do
    copy_managed_path "$source_repo" "$target_repo" "$relative_path" "$force"
  done

  ensure_exclude_patterns "$target_repo"

  if [[ "$skip_git_identity" != "1" ]]; then
    set_git_identity "$target_repo" "$git_name" "$git_email"
  fi

  if [[ "$gitnexus_index" == "1" ]]; then
    run_gitnexus_index "$source_repo" "$target_repo" "$gitnexus_name"
  else
    printf 'skipped GitNexus index\n'
  fi

  printf 'local workflow deployment complete\n'
}

create_worktree() {
  local path=""
  local template_repo=""
  local branch=""
  local base="origin/main"
  local force="0"
  local skip_git_identity="0"
  local git_name="$DEFAULT_GIT_NAME"
  local git_email="$DEFAULT_GIT_EMAIL"
  local gitnexus_index="1"
  local gitnexus_name=""

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -h|--help)
        worktree_usage
        exit 0
        ;;
      --template-repo)
        [[ "$#" -ge 2 ]] || die "--template-repo requires a path"
        template_repo="$2"
        shift 2
        ;;
      --managed-path)
        [[ "$#" -ge 2 ]] || die "--managed-path requires a path"
        WORKFLOW_PATHS+=("$2")
        shift 2
        ;;
      --no-default-managed-paths)
        WORKFLOW_PATHS=()
        shift
        ;;
      --exclude-pattern)
        [[ "$#" -ge 2 ]] || die "--exclude-pattern requires a pattern"
        EXCLUDE_PATTERNS+=("$2")
        shift 2
        ;;
      --no-default-exclude-patterns)
        EXCLUDE_PATTERNS=()
        shift
        ;;
      --branch)
        [[ "$#" -ge 2 ]] || die "--branch requires a name"
        branch="$2"
        shift 2
        ;;
      --base)
        [[ "$#" -ge 2 ]] || die "--base requires a ref"
        base="$2"
        shift 2
        ;;
      --force)
        force="1"
        shift
        ;;
      --skip-git-identity)
        skip_git_identity="1"
        shift
        ;;
      --git-name)
        [[ "$#" -ge 2 ]] || die "--git-name requires a value"
        git_name="$2"
        shift 2
        ;;
      --git-email)
        [[ "$#" -ge 2 ]] || die "--git-email requires a value"
        git_email="$2"
        shift 2
        ;;
      --command-timeout)
        [[ "$#" -ge 2 ]] || die "--command-timeout requires seconds"
        validate_timeout_seconds "$2"
        COMMAND_TIMEOUT_SECONDS="$2"
        shift 2
        ;;
      --gitnexus-index)
        gitnexus_index="1"
        shift
        ;;
      --no-gitnexus-index)
        gitnexus_index="0"
        shift
        ;;
      --gitnexus-name)
        [[ "$#" -ge 2 ]] || die "--gitnexus-name requires a value"
        gitnexus_name="$2"
        shift 2
        ;;
      --*)
        die "unknown worktree option: $1"
        ;;
      *)
        [[ -z "$path" ]] || die "worktree accepts exactly one path"
        path="$1"
        shift
        ;;
    esac
  done

  [[ -n "$path" ]] || die "worktree path is required"

  local source_repo
  source_repo="$(resolve_template_repo "$template_repo")"

  printf 'creating worktree: %s\n' "$path"
  if [[ -n "$branch" ]]; then
    run_with_timeout "$COMMAND_TIMEOUT_SECONDS" git -C "$source_repo" worktree add -b "$branch" "$path" "$base"
  else
    run_with_timeout "$COMMAND_TIMEOUT_SECONDS" git -C "$source_repo" worktree add "$path" "$base"
  fi

  local deploy_args=("$path" "--template-repo" "$source_repo" "--git-name" "$git_name" "--git-email" "$git_email" "--gitnexus-name" "$gitnexus_name")
  if [[ "$force" == "1" ]]; then
    deploy_args+=("--force")
  fi
  if [[ "$skip_git_identity" == "1" ]]; then
    deploy_args+=("--skip-git-identity")
  fi
  if [[ "$gitnexus_index" == "0" ]]; then
    deploy_args+=("--no-gitnexus-index")
  fi

  deploy_workflow "${deploy_args[@]}"
}

main() {
  if [[ "$#" -eq 0 ]]; then
    usage
    exit 1
  fi

  case "$1" in
    -h|--help)
      usage
      ;;
    deploy)
      shift
      deploy_workflow "$@"
      ;;
    worktree)
      shift
      create_worktree "$@"
      ;;
    *)
      die "unknown command: $1"
      ;;
  esac
}

main "$@"
