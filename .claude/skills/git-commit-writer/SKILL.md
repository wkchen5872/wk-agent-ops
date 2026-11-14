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
  version: "1.7"
---

# Git Commit Writer

Create one conventional commit from the completed worktree.

**No confirmation prompt — invocation authorizes final staging and commit.**

## Optional input

The caller may provide:

```text
archive_path=<exact archived change directory>
change_id=<OpenSpec change id without date prefix>
tool_name=<executing agent tool>
assisting_model=<current root-session model>
commit_repository=<host/owner/repo of the repository being committed>
github_references=<list of: url=<Issue or PR URL> evidence=<how it was confirmed>>
```

When archive_path and change_id are provided, use them directly. They are a
pair: if only one is provided, stop and report the invalid input.

`tool_name` identifies the collaborating tool, such as `Codex` or `Claude Code`.
`assisting_model` is optional. Record the most specific model name actually
known for the current collaborating root session. Accept `GPT-5`, `GPT-5.6`, or `GPT-6`;
do not invent a variant, version, or context size to make the name more precise.
Preserve a user-supplied model name for this work verbatim; otherwise use the
model name available in the current runtime context automatically.
Apply the same rule to later standalone commits in that session while the root
model remains unchanged. You MUST NOT ask the user to repeat it or provide a
more precise model name just to commit.

Provider-native documentation and commit subagents MUST NOT replace or make root-session attribution ambiguous.
This records current collaboration, not original code authorship. Pre-existing
changes, another implementation session, or a commit-only root session MUST NOT
cause omission of a known current model. After a root model switch, use the
currently known model; do not reuse a stale name from before the switch.
Tool names such as `OpenAI Codex` are not model names. Only when no model name
is known for the current root session, omit `AI-Assisted-By` and report the omission;
do not block the commit. A known `GPT-5` MUST be recorded, not omitted.
You MUST NOT guess attribution from environment variables, documentation,
session logs, Git history, or the commit-only agent's identity.

`assisting_model` is Git attribution metadata only. It identifies the known
current root-session collaboration model, at the available precision.
It MUST NOT select or override this writer's runtime model or reasoning effort.

### GitHub references

`github_references` lists GitHub Issues and PRs that the staged work directly
addressed, each with evidence that confirms it: this session's user
instruction, a Handoff `issue`/`pull-request` line that was read, or a read
Issue or PR that names this work. Without the input, use only associations
already confirmed in this session; never scan GitHub, and never infer one from
a branch name or from an Issue number a proposal merely mentions.

- Only directly addressed work is kept. Links that are background (for example
  completed Issues a proposal cites as context), `references`, or `depends-on`
  targets are dropped unless separately confirmed as directly addressed.
- Unknown, ambiguous, or conflicting targets are omitted and reported; they
  never block an otherwise authorized commit, and an optional reference is
  never a reason to ask the user again or to log in.
- `commit_repository` comes from the caller, or from the confirmed `origin`
  remote (`git remote get-url origin`) without changing it. When it is unknown,
  keep only targets given as full URLs; a bare number is never attached to a
  guessed repository.

Format one line, `Refs: #19, #20`:

- A target in the commit repository on the same host is `#N`; anything else is
  its full HTTPS URL (`https://<host>/<owner>/<repo>/issues/<N>` or
  `/pull/<N>`).
- Deduplicate by host, owner, repository, and number — a `#N` and a URL for
  the same target count once. List local `#N` in ascending order, then
  external URLs in lexical order.
- Use `Refs:` only — never `Closes` or `Fixes`, or any keyword that would
  change Issue or PR state.
- References apply only to an already authorized, nonempty commit; never amend,
  rewrite, or create an empty commit to add or update a reference — a PR
  created later appears only in a future commit that is needed anyway.

Replayable cases are in [references/acceptance-cases.md](references/acceptance-cases.md).

---

## Step 1 — Validate optional OpenSpec input

### Explicit context

When archive_path and change_id are provided, verify the exact archive before
staging:

```bash
if [ ! -d "$archive_path" ]; then
  echo "❌ Archive not found: $archive_path"
  exit 1
fi
```

Keep the verified pair as explicit context. Never replace an invalid explicit
path with auto-detection. Do not resolve standalone context yet.

### Attribution context

Preserve supplied attribution values. For standalone use, identify the executing
tool and resolve the optional model name using the rules above. A missing model
name or variant is not a staging or commit gate. Never substitute a tool name
for an unknown model.

---

## Step 2 — Stage and gather the final diff

Stage all changes before inspecting the commit content:

```bash
git add -A

if git diff --cached --quiet; then
  echo "ℹ️ Nothing to commit"
  exit 0
fi

git diff --cached --name-only
git diff --cached --stat
git diff --cached
```

---

## Step 3 — Resolve OpenSpec context

### Explicit context

When the pair from Step 1 is valid, use it directly and read
`<archive_path>/proposal.md`, focusing on **Why** and **What Changes**.

### Standalone context resolution

Only when explicit context is absent, inspect the current branch, active
changes, and final staged paths:

```bash
git branch --show-current
openspec list --json
git diff --cached --name-only
```

Build a candidate set using exact path components, never substring matching:

- An active change is associated only when it appears in `openspec list --json`
  and either the branch is exactly `feature/<change-id>` or a staged path is
  beneath `openspec/changes/<change-id>/`.
- An archive is associated only when a staged path is beneath its exact
  `openspec/changes/archive/<archive-directory>/` directory. Derive its change
  ID only after that directory is associated.

The number of active changes does not create an association.
A sole active change without either association is not context.

Resolve the filtered set:

- **Zero associated candidates** — use only the staged diff and omit the
  OpenSpec scope. Do not read an unrelated proposal.
- **One associated candidate** — use its change ID and proposal as context.
- **Multiple associated candidates** — ask the user to select one when the host
  supports interaction; otherwise stop and list them. Never choose the first.

---

## Step 4 — Infer commit type

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

## Step 5 — Format the message

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
- When confirmed references exist, add the `Refs:` line from "GitHub
  references" as the first trailer, right before the attribution trailers.

---

## Step 6 — Commit

Build the co-author trailer from this strict verified mapping:

| `tool_name` | Trailer |
|---|---|
| `Codex` | `Co-Authored-By: Codex <noreply@openai.com>` |
| `Claude Code` | `Co-Authored-By: Claude Code <noreply@anthropic.com>` |

Unmapped tools use `Co-Authored-By: <tool_name>` without an email. Preserve the
tool name and MUST NOT guess an address. When the current root-session model is known,
follow it immediately with the model trailer:

```bash
git commit -m "<message>

Refs: <references>
<resolved Co-Authored-By trailer>
AI-Assisted-By: <assisting_model>"
```

Omit the `Refs:` line when no reference is confirmed — never write an empty
value or a placeholder.

When the model is unknown, omit the entire `AI-Assisted-By` line, not an empty
value or placeholder, and mention the omission in the result.

If a pre-commit hook fails:

1. Read the failure output and fix the in-scope issue.
2. **Re-run `git add -A`** so hook or formatter changes enter the commit.
3. Confirm `git diff --cached` still contains the intended change.
4. Retry `git commit` without `--no-verify`.

---

## Step 7 — Output

```bash
git log -1 --format='%h %s'
```

Report:

```text
💾 Commit: <short-hash> <type>(<change_id>): <subject>
```

Omit `(<change_id>)` when no OpenSpec context exists. Report the references
written, and any that were omitted as unknown, conflicting, or background.
