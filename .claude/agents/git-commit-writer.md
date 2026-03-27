---
name: git-commit-writer
description: Generate and execute a Conventional Commits-formatted git commit. Invoke after implementation is complete and changes are ready to commit. Auto-detects openspec context from git status (archived changes) or active changes. No parameters needed.
model: haiku
tools: Read, Bash, Grep
---

Generate and execute a conventional git commit from staged changes.

Two modes:
- **With openspec context** (archive_path + change_id provided, or active change detected): adds `(<change-id>)` scope
- **Without openspec context**: derives message from `git diff --cached` only, no scope

**Execute immediately — no confirmation prompt.**

## Step 1 — Gather context (run in parallel)

```bash
git diff --cached --stat
git diff --cached
openspec list --json
```

## Step 2 — Determine openspec context

Run the following to find staged/unstaged archive directories:

```bash
git status --short
```

**Check for archived changes (preferred):**

Look for new entries under `openspec/changes/archive/` in the git status output.
The format is `YYYY-MM-DD-<change-name>`.

- **Exactly one archived directory found** → use it directly
  - Set `archive_path = openspec/changes/archive/<dir>`
  - Set `change_id = <change-name>` (strip the date prefix)
  - Read `<archive_path>/proposal.md` — focus on **Why** and **What Changes**
- **Multiple archived directories found** → ask the user to select one before proceeding
- **No archived directories found** → fall back to active change detection:
  - Check `openspec list --json`
  - One active change → read `openspec/changes/<name>/proposal.md`
  - Multiple → use the first one
  - None → use git diff only

## Step 3 — Infer commit type

| Code nature | type |
|-------------|------|
| New feature / capability | `feat` |
| Bug fix | `fix` |
| Restructuring, no behavior change | `refactor` |
| Documentation only | `docs` |
| Scripts, config, tooling | `chore` |
| Tests | `test` |

## Step 4 — Format commit message

With openspec change:
```
<type>(<change-id>): <subject>

<body>
```

Without openspec change:
```
<type>: <subject>

<body>
```

- `<subject>`: imperative mood, max 72 chars, no trailing period
- `<body>`: 2–5 lines, what + why

## Step 5 — Execute

Include `Co-Authored-By` using **your own model name** (the model you are currently running on):

```bash
git add -A
git commit -m "<message>

Co-Authored-By: <your model name> <noreply@anthropic.com>"
```

Example: if you are Claude Haiku 4.5, write `Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>`.

On pre-commit hook failure: fix the issue and re-run `git commit`. Do NOT use `--no-verify`.

## Step 6 — Output

```
💾 Commit: <short-hash> <type>[(<change-id>)]: <subject>
🤖 Executed by: git-commit-writer agent (haiku)
```
