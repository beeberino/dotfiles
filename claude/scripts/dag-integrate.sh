#!/usr/bin/env bash
# Integrate a finished slice-worker's worktree branch into the DAG's target branch.
#
# Usage:
#   dag-integrate.sh <node-id> <worktree-path> <worktree-branch>
#
# Reads dag.json from CLAUDE_DAG_STATE_DIR (or ~/.claude/state) for
# `target_branch` and `repo_root`. Behavior:
#
#   - target_branch is null / main / master   → skip merge (exit 0, prints "skipped: <reason>")
#   - current branch != target_branch         → skip merge (exit 0, prints "skipped: <reason>")
#   - merge succeeds                          → exit 0, prints "merged" then a DIFFSTAT block
#   - merge conflicts                         → git merge --abort, exit 1
#
# On successful merge, the worktree is removed (`git worktree remove --force`).
# On any skip or conflict, the worktree is left in place for inspection.

set -euo pipefail

NODE_ID="${1:?usage: dag-integrate.sh <node-id> <worktree-path> <worktree-branch>}"
WORKTREE_PATH="${2:?missing worktree path}"
WORKTREE_BRANCH="${3:?missing worktree branch}"

STATE="${CLAUDE_DAG_STATE_DIR:-$HOME/.claude/state}"
DAG="$STATE/dag.json"

if [[ ! -f "$DAG" ]]; then
  echo "dag-integrate: no dag.json at $DAG" >&2
  exit 2
fi

target_branch=$(jq -r '.target_branch // "null"' "$DAG")
repo_root=$(jq -r '.repo_root // ""' "$DAG")

if [[ "$target_branch" == "null" || "$target_branch" == "main" || "$target_branch" == "master" ]]; then
  echo "skipped: target_branch is '$target_branch' (auto-merge disabled on main/master)"
  exit 0
fi

if [[ -z "$repo_root" || ! -d "$repo_root/.git" ]]; then
  echo "dag-integrate: repo_root invalid or not a git repo: $repo_root" >&2
  exit 2
fi

cd "$repo_root"

current_branch=$(git branch --show-current)
if [[ "$current_branch" != "$target_branch" ]]; then
  echo "skipped: current branch '$current_branch' != target '$target_branch'"
  exit 0
fi

if ! git rev-parse --verify "$WORKTREE_BRANCH" >/dev/null 2>&1; then
  echo "dag-integrate: worktree branch '$WORKTREE_BRANCH' not found in $repo_root" >&2
  exit 2
fi

diff_stat=$(git diff "$target_branch...$WORKTREE_BRANCH" --stat 2>/dev/null || true)

if git merge --no-ff --no-edit -m "Integrate slice $NODE_ID ($WORKTREE_BRANCH)" "$WORKTREE_BRANCH" >/dev/null 2>&1; then
  echo "merged: $WORKTREE_BRANCH into $target_branch"
  echo "---DIFFSTAT---"
  echo "$diff_stat"
  git worktree remove "$WORKTREE_PATH" --force >/dev/null 2>&1 || true
  git branch -D "$WORKTREE_BRANCH" >/dev/null 2>&1 || true
  exit 0
else
  git merge --abort >/dev/null 2>&1 || true
  echo "conflict: aborted merge of $WORKTREE_BRANCH into $target_branch" >&2
  exit 1
fi
