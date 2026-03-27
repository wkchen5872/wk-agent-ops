---
name: git-commit-writer
description: >
  Generate and execute a Conventional Commits-formatted git commit. Works
  standalone or when called from openspec-commit. Adds scope when an openspec
  change is present; omits scope otherwise. Executes without confirmation.
license: MIT
compatibility: Requires git. Optional: openspec CLI.
metadata:
  author: wkchen
  version: "1.0"
---

# Git Commit Writer

Generate and execute a conventional git commit from staged changes.

Two modes:
- **With openspec change**: reads `proposal.md`, adds `(<change-id>)` scope
- **Without openspec change**: derives message from `git diff --cached` only, no scope

**No confirmation prompt — commits immediately.**

---

## Step 1 — Gather context (run in parallel)

```bash
git diff --cached --stat
git diff --cached
openspec list --json
```

Skip `openspec list` if the CLI is not available.

---

## Step 2 — Determine openspec context

**If called from `openspec-commit` with explicit context provided:**
- Use the given `archive_path` and `change_id` directly
- Read `<archive_path>/proposal.md` — focus on **Why** and **What Changes**

**If called standalone:**
- Check `openspec list --json`
- Exactly one active change → read `openspec/changes/<name>/proposal.md`
- Multiple active changes → use the first one
- No active changes → skip proposal, use git diff only

---

## Step 3 — Infer commit type

| Code nature | type |
|-------------|------|
| New feature / new capability | `feat` |
| Bug fix / correcting behavior | `fix` |
| Restructuring without behavior change | `refactor` |
| Documentation only | `docs` |
| Scripts, config, tooling, maintenance | `chore` |
| Adding or fixing tests | `test` |

---

## Step 4 — Format commit message

**With openspec change:**
```
<type>(<change-id>): <subject>

<body>
```

**Without openspec change:**
```
<type>: <subject>

<body>
```

Rules:
- `<subject>`: imperative mood, max 72 chars, no trailing period
  - With proposal: derived from **What Changes** section
  - Without proposal: derived from `git diff --cached --stat` summary
- `<body>`: 2–5 lines, what + why
  - With proposal: derived from **Why** + **What Changes**
  - Without proposal: summarized from diff content

---

## Step 5 — Execute

```bash
git add -A
git commit -m "<message>"
```

**Note:** `Co-Authored-By` is automatically added by Claude Code based on the current model.
Do NOT manually include it — let the system handle attribution.

On pre-commit hook failure: fix the issue and re-run `git commit`. Do NOT use `--no-verify`.

---

## Step 6 — Output result

```
💾 Commit: <short-hash> <type>[(<change-id>)]: <subject>
```
