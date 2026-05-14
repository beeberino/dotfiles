#!/usr/bin/env bash
# Merge pending DAG patches into dag.json atomically.
#
# Usage:
#   dag-merge.sh                          # uses default state dir (~/.claude/state)
#   dag-merge.sh <project-root>           # uses <project-root>/.claude/state
#   CLAUDE_DAG_STATE_DIR=/path dag-merge.sh   # uses an explicit state dir
#
# Resolution order: CLAUDE_DAG_STATE_DIR env var → $1/.claude/state → ~/.claude/state.
#
# Reads every <STATE>/patches/*.json file, applies it to <STATE>/dag.json,
# and moves processed patches to <STATE>/patches/applied/<timestamp>/.
#
# Patch schema:
#   { "node": "<id>", "status": "...", "notes": [...], "new_nodes": {...} }

set -euo pipefail

if [[ -n "${CLAUDE_DAG_STATE_DIR:-}" ]]; then
  STATE="$CLAUDE_DAG_STATE_DIR"
elif [[ $# -ge 1 && -n "$1" ]]; then
  STATE="$1/.claude/state"
else
  STATE="$HOME/.claude/state"
fi

DAG="$STATE/dag.json"
PATCH_DIR="$STATE/patches"

if [[ ! -f "$DAG" ]]; then
  echo "dag-merge: no dag.json at $DAG" >&2
  exit 1
fi

shopt -s nullglob
patches=("$PATCH_DIR"/*.json)
if [[ ${#patches[@]} -eq 0 ]]; then
  echo "dag-merge: no patches"
  exit 0
fi

ts=$(date +%s)
applied_dir="$PATCH_DIR/applied/$ts"
mkdir -p "$applied_dir"

tmp=$(mktemp)
cp "$DAG" "$tmp"

for patch in "${patches[@]}"; do
  jq --slurpfile p "$patch" '
    ($p[0]) as $patch
    | .nodes[$patch.node].status = $patch.status
    | .nodes[$patch.node].notes  = ((.nodes[$patch.node].notes // []) + ($patch.notes // []))
    | (if ($patch.new_nodes // {}) == {} then .
       else .nodes = (.nodes + $patch.new_nodes)
       end)
  ' "$tmp" > "$tmp.next"
  mv "$tmp.next" "$tmp"
  mv "$patch" "$applied_dir/"
done

mv "$tmp" "$DAG"
echo "dag-merge: applied ${#patches[@]} patch(es) → $applied_dir"
