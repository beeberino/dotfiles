#!/usr/bin/env bash
# SubagentStop hook: append a JSONL telemetry line per subagent run.
# Reads hook payload on stdin (Claude Code passes JSON to hook commands).
# Cheap audit trail — does not touch dag.json.

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
LOG="$PROJECT_ROOT/.claude/state/dag-events.jsonl"

# No-op if this project doesn't use the DAG workflow.
[[ -d "$PROJECT_ROOT/.claude/state" ]] || exit 0

mkdir -p "$(dirname "$LOG")"

payload=$(cat || true)
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Best-effort enrichment; payload schema may evolve, so don't fail on missing keys.
jq -nc --arg ts "$ts" --argjson payload "${payload:-null}" '
  {ts: $ts, event: "subagent_stop", payload: $payload}
' >> "$LOG" 2>/dev/null || echo "{\"ts\":\"$ts\",\"event\":\"subagent_stop\"}" >> "$LOG"
