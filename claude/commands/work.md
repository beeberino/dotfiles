---
description: Merge pending DAG patches, then dispatch ready nodes as parallel slice-worker subagents
allowed-tools: Read, Write, Edit, Bash, Agent
---

You are the **DAG orchestrator**. One tick = merge → recompute → dispatch → collate → integrate.

## State directory

State lives at `~/.claude/state/` by default — outside any repo so PRD/DAG/patches survive across worktrees.

If the user passes a `--state-dir <path>` argument or sets `CLAUDE_DAG_STATE_DIR`, use that instead. Resolution order:

1. `--state-dir <path>` argument to `/work`
2. `$CLAUDE_DAG_STATE_DIR` environment variable
3. `$CLAUDE_PROJECT_DIR/.claude/state` if the user explicitly passed a project-relative directive (e.g. "use the project state dir")
4. `~/.claude/state` (default)

For the rest of this skill, treat `$STATE` as the resolved path. Hold it as a stable reference for the whole tick.

- PRD:       `$STATE/prd.md`
- DAG:       `$STATE/dag.json`
- Patches:   `$STATE/patches/*.json`
- Log:       `$STATE/dag-events.jsonl`
- Learnings: `$STATE/<repo-basename>/learnings.md` (where `<repo-basename>` is `basename` of `dag.json:.repo_root`)

If either prd.md or dag.json is missing, tell the user to run
`/grill-to-dag` first and stop.

## Steps

### 1. Merge pending patches
Run `CLAUDE_DAG_STATE_DIR=$STATE ~/.claude/scripts/dag-merge.sh`. It will:
- read every patch in `$STATE/patches/`
- apply node status / notes / new_nodes mutations
- write dag.json atomically
- move applied patches to `$STATE/patches/applied/<ts>/`

### 2. Recompute readiness
Read the merged dag.json. Promote any `blocked` node whose deps are
all `done` to `ready`. Write back if anything changed.

### 3. Decide what to do
- If any node is `failed` → surface a one-line summary per failure and
  STOP. The user decides whether to retry or rewrite.
- Else if no `ready` and no `in_progress` nodes → print "DAG drained"
  and STOP. (If invoked under `/loop`, the loop should end.)
- Else collect every `ready` node.

### 4. Dispatch (parallel)
For each ready node, in a **single message**, call the Agent tool with:
- `subagent_type: "slice-worker"`
- `isolation: "worktree"` (each worker gets its own git worktree)
- `description: "Implement slice <node-id>"`
- `prompt: <see below>`

Worker prompt template:
```
Codebase root: <dag.json:.repo_root>
Node id:       <node-id>
PRD path:      <STATE>/prd.md   (authoritative; read-only)
DAG path:      <STATE>/dag.json
Patch dir:     <STATE>/patches/

Read the PRD first, then locate your node in the DAG. Implement this
slice using the `tdd` skill, holding to the PRD's constraints,
non-goals, and glossary. Follow the protocol in your agent
definition. Emit your final patch JSON in a fenced ```json block as
your last message.
```

Substitute the resolved `$STATE` and `repo_root` into the worker prompt as absolute paths — the worker runs in a worktree and may not share `$CLAUDE_PROJECT_DIR` semantics.

Before dispatching, mark each dispatched node `in_progress` in the DAG
so concurrent ticks don't double-dispatch.

### 5. Collate
When all workers return, parse each one's final fenced ```json block.
For each, write it to `$STATE/patches/<node>-<unix-ts>.json`.
The next tick will merge them into dag.json.

### 6. Auto-integrate done workers
For each worker that returned `status: done`, in completion order, attempt to merge their worktree branch into the DAG's `target_branch`. Run:

```
CLAUDE_DAG_STATE_DIR=$STATE ~/.claude/scripts/dag-integrate.sh \
  <node-id> <worktree-path> <worktree-branch>
```

The script enforces three guards before touching anything:
- `dag.json:.target_branch` must be set and not `main` / `master` (auto-merge is disabled on those by design — set during `/grill-to-dag`).
- The user's current branch must equal `target_branch` (no auto-switching).
- The worktree branch must exist locally.

Outcomes:
- **Merged cleanly**: stdout starts with `merged:` followed by `---DIFFSTAT---` then `git diff --stat` output. The worktree is removed and the worker branch is deleted. Append a section to `$STATE/<repo-basename>/learnings.md` (see step 7).
- **Skipped**: stdout starts with `skipped:` and a reason. Don't treat as failure. Append learnings only (still valuable).
- **Conflict** (exit 1): stdout starts with `conflict:`. Mark the node `failed` by writing a follow-up patch to `$STATE/patches/<node>-conflict-<ts>.json` with `status: failed` and a `notes` entry quoting the conflict reason. The next tick will pick this up and stop the loop.

### 7. Append to learnings file
For each completed worker (merged OR skipped — not for conflicts), append to `$STATE/<repo-basename>/learnings.md`. Create the directory + file if missing.

Section format:
```markdown
## <node-id> — <short title from DAG>
*Integrated <ISO timestamp> · branch <worktree-branch> → <target_branch or "(skipped: reason)">*

### Summary
<diff stat block from dag-integrate.sh, or "skipped — no changes integrated">

### Learnings
- <each entry from patch.learnings, verbatim>

### Worker retro
- <each entry from patch.retro, verbatim>
```

Omit any subsection (`Summary`, `Learnings`, `Worker retro`) whose source is empty or missing — but keep the per-slice header so the file remains a complete index of integrated work.

### 8. Print a status table
Print: `node | result | worktree path | branch | integration` where `integration` is `merged` / `skipped` / `conflict` / `pending`.

### 9. Append to event log
For each dispatched / returned / integrated event, append one JSONL line to
`$STATE/dag-events.jsonl`:

```json
{"ts":"<iso>","node":"<id>","event":"dispatched|returned|merged|skipped|conflict","status":"...","worktree":"...","branch":"...","target":"..."}
```
