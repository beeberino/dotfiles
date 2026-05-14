---
description: Convert the current grill-me conversation into a PRD + a DAG of thin vertical slices
allowed-tools: Read, Write, Edit, Bash
argument-hint: "[optional: path to existing notes file]"
---

You have just completed (or are wrapping up) a `/grill-me` session.
Produce **two** artifacts from the resolved decisions:

1. `$STATE/prd.md` — the source-of-truth product spec workers will review against.
2. `$STATE/dag.json` — the execution plan derived from the PRD.

## State directory

State lives at `~/.claude/state/` by default — outside any repo so PRD/DAG/patches survive across worktrees.

Resolve `$STATE` in this order:

1. `--state-dir <path>` argument to `/grill-to-dag`
2. `$CLAUDE_DAG_STATE_DIR` environment variable
3. `$CLAUDE_PROJECT_DIR/.claude/state` if the user explicitly asked for project-relative state
4. `~/.claude/state` (default)

Use the same resolved `$STATE` for both files and the patches directory.

Write the PRD **first**, then derive the DAG from it. Every slice's
acceptance criterion must trace back to something in the PRD.

## Slice rules
- Each slice is **user-visible**, **independently testable**, and
  **shippable on its own**. If two slices must merge together to be
  testable, they're one slice.
- Each slice has exactly one acceptance criterion expressed as
  observable behaviour (HTTP, UI, CLI output, file on disk).
- Reject slices estimated >1 day. Split them.
- `deps` only when a slice literally cannot be exercised without the
  other slice landed first. Shared file paths are NOT a dependency.

## PRD shape (`prd.md`)
Keep it tight — workers will re-read this constantly. No marketing
prose. Use these H2 sections in order; omit a section only if grilling
genuinely produced nothing for it.

```markdown
# <Feature title>

## Problem
<2–4 sentences: the situation today and why it's a problem. The "why".>

## Goals
- <Outcome, not feature. e.g. "Operators can revoke a session in <5s">

## Non-goals
- <Explicitly out of scope. Future work goes here, not in goals.>

## Users / actors
- <Who triggers this, who is affected>

## Constraints
- <Tech, perf, compliance, deadline, existing systems we must not break>

## Glossary
- **<Term>**: <Definition as agreed during grilling>

## System-level acceptance criteria
- <Observable behaviour at the whole-feature level. Slice-level
  acceptance criteria in dag.json are subsidiary to these.>

## Open questions
- <Anything grilling did NOT resolve. Workers must fail-fast if they
  hit one of these — the human resolves before re-running.>
```

## Schema
```json
{
  "version": 1,
  "created_at": "<ISO 8601>",
  "target_branch": "<branch name or null>",
  "repo_root": "<absolute path>",
  "nodes": {
    "<kebab-case-id>": {
      "title": "<one line, imperative>",
      "acceptance": "<observable behaviour>",
      "deps": ["<other-id>", "..."],
      "status": "ready | blocked",
      "notes": []
    }
  }
}
```

`status` is `ready` when `deps: []`, otherwise `blocked`. The
orchestrator promotes blocked → ready as deps complete.

`target_branch` and `repo_root` capture the integration target for
auto-merge by `/work`:

- `repo_root` = absolute path to the repo (`git rev-parse --show-toplevel`).
- `target_branch` = the branch checked out at PRD-creation time. **Set to `null`** if the current branch is `main` or `master` — auto-merge is disabled in that case.

## Steps
1. Ensure `$STATE/patches/` exists (`mkdir -p`). The orchestrator and workers rely on it.
2. If `prd.md` or `dag.json` already exist in `$STATE`, stop and ask the user before overwriting either.
3. Capture integration target: run `git rev-parse --show-toplevel` and `git branch --show-current` from the user's working directory. If the branch is `main` or `master`, set `target_branch: null`. Otherwise use the captured branch name.
4. Draft `prd.md` from the grill conversation. Show it to the user and wait for confirmation before continuing.
5. Draft the DAG so every node's `acceptance` traces to a system-level criterion or constraint in the PRD. Validate every `deps` reference exists as a node id. Include `target_branch` and `repo_root` at the top level.
6. Write both files.
7. Print a summary: PRD section count, target branch (or "auto-merge disabled" if null), then a table of DAG nodes (id | status | deps | title).

If `$1` is provided, treat it as a path to additional notes to fold in
alongside the conversation context.
