---
description: Run /hiive:retro, distill PRD/DAG/learnings/retro into an Obsidian note, then clear state for the next cycle
allowed-tools: Read, Write, Edit, Bash, Skill
---

You are the **DAG cleanup operator**. End-of-pipeline command that runs the Hiive session retrospective, distills the whole session — PRD, DAG, learnings, retro findings — into a single durable Obsidian note, and clears `~/.claude/state/` for the next cycle.

## State directory

Resolve `$STATE` the same way `/work` does — `--state-dir` arg, `$CLAUDE_DAG_STATE_DIR`, then `~/.claude/state/` (default).

Files this command touches:

- **Read**: `$STATE/prd.md`, `$STATE/dag.json`, `$STATE/dag-events.jsonl`, `$STATE/patches/applied/**/*.json`, `$STATE/<repo-basename>/learnings.md`
- **Write**: One Markdown file under `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Devault/Engineering/Sessions/`
- **Delete (only if cleanup proceeds)**: all read state files; the `patches/applied/` tree; the per-repo learnings file. The empty `$STATE/patches/` directory is **kept** for the next cycle.

## Step 1 — Refuse if pending

Read `$STATE/dag.json`. Compute the set of node statuses.

Refuse to proceed (print a numbered list of pending items, exit without modifying anything) if **any** of these is true:

- Any node has status `ready`, `blocked`, or `in_progress`
- Any pending patches exist at `$STATE/patches/*.json` (excluding the `applied/` subtree)

`failed` nodes are terminal — they do **not** block cleanup, but flag them prominently in the note.

If neither prd.md nor dag.json exists, print "Nothing to clean up — state is empty" and exit.

## Step 2 — Read everything

Read all of:

- `$STATE/prd.md` — full content
- `$STATE/dag.json` — extract `target_branch`, `repo_root`, every node (id, title, acceptance, status, notes, deps)
- `$STATE/dag-events.jsonl` — line-by-line; parse to recover per-node integration outcomes (`merged` / `skipped` / `conflict`) with timestamps
- `$STATE/patches/applied/**/*.json` — recover each applied patch's `learnings` and `retro` arrays (dag.json doesn't carry these — they're only in the patch files at integration time)
- `$STATE/<repo-basename>/learnings.md` if it exists — the running per-slice log; not parsed (the patches are the structured source) but fold in any sections that don't appear in the patches (e.g. integration summaries)

Compute `<repo-basename>` from `dag.json:.repo_root` via `basename`.

## Step 3 — Compose the Obsidian note

Filename: `<slug>-YYYY-MM-DD.md` where `<slug>` = the PRD's H1 title, lowercased, alphanumerics + hyphens only, truncated to 50 chars. Use `date +%Y-%m-%d` for the date.

Path: `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Devault/Engineering/Sessions/<slug>-YYYY-MM-DD.md`

If a file already exists at that path, append `-2`, `-3`, etc.

Note structure:

```markdown
---
title: <PRD H1>
date: <YYYY-MM-DD>
repo: <repo-basename>
target_branch: <target_branch or "(disabled)">
status: <"shipped" if all nodes done, otherwise "shipped-with-failures">
tags:
  - dag-session
  - <repo-basename>
---

# <PRD H1>

> *Distilled from `$STATE` on YYYY-MM-DD HH:MM*  
> *Repo: `<repo_root>` · Target branch: `<target_branch or "main/master — auto-merge disabled">`*

## Problem & Goals
<paste the PRD's Problem section verbatim>

<paste the PRD's Goals section verbatim>

## What shipped
<one subsection per node, ordered by dag-events.jsonl integration order; failed nodes appear in a separate section below>

### <node-id> — <node title>
**Acceptance:** <node.acceptance>
**Outcome:** <"merged" | "skipped: <reason>"> at <ISO ts from events>

#### Notes
<each item from node.notes as a bullet; omit the section if notes is empty>

(repeat per done node)

## Failed slices
<only if any failed nodes; otherwise omit this section>

### <node-id> — <title>
**Reason:** <first entry of node.notes, or "no reason recorded">
**Full notes:** <all node.notes as bullets>

## Learnings
<every learning from every applied patch's `learnings` array, deduplicated. Each as a bullet. If empty, write "_None recorded._">

## Worker process retros
<every entry from every applied patch's `retro` array. Group by node — one subsection per slice that produced retro entries. If no slice produced any, write "_No worker retros recorded._">

### <node-id>
- <each entry from that slice's patch.retro>

(repeat per slice; omit slices whose retro array is empty)

### Memories saved
<accepted items as bullets; "(none)" if user skipped>

### Tooling changes applied
<accepted items as bullets; "(none)" if user skipped>

### Org context gaps surfaced
<accepted items as bullets; "(none)" if user skipped>

### Things that worked well
<verbatim from retro>

### Feedback for next time
<verbatim from retro — the "feedback for the user" section>

### Proposed but skipped
<items the retro proposed that the user declined; "(none)" if everything was accepted>

"_Retro: $RETRO_SUMMARY_"

## Open questions from PRD
<paste the PRD's Open questions section if non-trivial; otherwise omit>

## Constraints & Non-goals (for posterity)
<paste the PRD's Constraints and Non-goals sections>
```

## Step 4 — Confirm with the user

Before deleting anything, show the user:

1. The path of the Obsidian note that will be written
2. A 1-line summary of what's about to be deleted (file count, learnings line count, applied patch count)
3. Whether worktrees will be swept (per Step 6)

Wait for user confirmation. Do not assume yes.

## Step 5 — Write the Obsidian note

Use the Write tool. If the parent directory `Devault/Engineering/Sessions/` doesn't exist, create it via Bash `mkdir -p` first.

If Write fails (iCloud permission errors are possible), surface the error and STOP — do not proceed to deletion.

## Step 6 — Sweep worktrees (conditional)

Only if **every** node has status `done` AND every node was successfully `merged` (per the events log — `skipped` does not count as merged):

For each remaining directory under `<repo_root>/.claude/worktrees/`:

- `cd <repo_root> && git worktree remove --force <path>`
- Best-effort: also `git branch -D worktree-agent-<id>` if the branch still exists.

If any node is `failed` or any integration was `skipped` / `conflict`, **leave worktrees untouched** so the user can inspect them.

## Step 7 — Delete state

Only if Step 6 succeeded:

```
rm -f $STATE/prd.md
rm -f $STATE/dag.json
rm -f $STATE/dag-events.jsonl
rm -rf $STATE/patches/applied
rm -f $STATE/<repo-basename>/learnings.md
rmdir $STATE/<repo-basename> 2>/dev/null || true
```

Keep `$STATE/patches/` (empty directory) so the next `/grill-to-dag` doesn't have to recreate it.

## Step 8 — Confirm

Print:

- Path of the written Obsidian note
- Files deleted (count)
- Worktrees swept (count, or "left in place: <reason>")
- Whether retro ran (and skill name) or was skipped
- Final reminder: state is now empty; next pipeline starts with `/grill-to-dag`
