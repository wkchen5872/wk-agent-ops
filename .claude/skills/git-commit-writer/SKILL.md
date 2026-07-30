---
name: git-commit-writer
description: >
  Stage the completed worktree, generate a Conventional Commits message, and
  execute the commit. Uses explicit OpenSpec archive context when supplied and
  auto-detects context only for standalone use.
license: MIT
compatibility: "Requires git. Optional: openspec CLI."
metadata:
  author: wkchen
  version: "1.3"
---

# Git Commit Writer

Create one conventional commit from the completed worktree.

**No confirmation prompt — invocation authorizes final staging and commit.**

## Optional input

The caller may provide:

```text
archive_path=<exact archived change directory>
change_id=<OpenSpec change id without date prefix>
```

When archive_path and change_id are provided, use them directly. They are a
pair: if only one is provided, stop and report the invalid input.

---

## Step 1 — Resolve OpenSpec context

### Explicit context

Verify the exact archive before staging:

```bash
if [ ! -d "$archive_path" ]; then
  echo "❌ Archive not found: $archive_path"
  exit 1
fi
```

Read `<archive_path>/proposal.md`, focusing on **Why** and **What Changes**.
Never replace an invalid explicit path with an auto-detected archive.

### Standalone fallback

Only when explicit context is absent:

```bash
git status --short
openspec list --json
```

Resolution priority:

1. Exactly one uncommitted directory under `openspec/changes/archive/`
2. Exactly one active OpenSpec change
3. No OpenSpec context → use the Git diff without a scope

If a level contains multiple candidates, ask the user to select when the host
supports interaction. Otherwise stop and list the candidates for the caller.
Never choose the first candidate.

---

## Step 2 — Stage and gather the final diff

Stage all changes before inspecting the commit content:

```bash
git add -A

if git diff --cached --quiet; then
  echo "ℹ️ Nothing to commit"
  exit 0
fi

git diff --cached --stat
git diff --cached
```

---

## Step 3 — Infer commit type

| Change nature | type |
|---|---|
| New feature or capability | `feat` |
| Bug fix | `fix` |
| Restructuring without behavior change | `refactor` |
| Documentation only | `docs` |
| Scripts, config, tooling, maintenance | `chore` |
| Tests | `test` |

Use both the staged diff and proposal when archive context exists. The staged
diff is authoritative for what the commit actually contains.

---

## Step 4 — Format the message

With OpenSpec context:

```text
<type>(<change_id>): <subject>

<body>
```

Without OpenSpec context:

```text
<type>: <subject>

<body>
```

Rules:

- Subject uses imperative mood, has at most 72 characters, and no trailing
  period.
- Body is 2–5 lines explaining what changed and why.
- Never claim a proposal item that is absent from the staged diff.

---

## Step 5 — Commit

Include `Co-Authored-By` using the current model's actual name:

```bash
git commit -m "<message>

Co-Authored-By: <current model name> <noreply@anthropic.com>"
```

If a pre-commit hook fails:

1. Read the failure output and fix the in-scope issue.
2. **Re-run `git add -A`** so hook or formatter changes enter the commit.
3. Confirm `git diff --cached` still contains the intended change.
4. Retry `git commit` without `--no-verify`.

---

## Step 6 — Output

```bash
git log -1 --format='%h %s'
```

Report:

```text
💾 Commit: <short-hash> <type>(<change_id>): <subject>
```

Omit `(<change_id>)` when no OpenSpec context exists.
