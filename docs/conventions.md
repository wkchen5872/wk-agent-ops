---
type: Reference
title: wk-agent-ops Coding Conventions
description: Bash, installer, hook, and workflow implementation conventions.
tags: [conventions, bash, hooks, installers]
timestamp: 2026-08-01T00:00:00+08:00
---

# 📝 wk-agent-ops Coding Conventions

*This file defines the "Muscle Memory" for AI agents working in this repo. These conventions apply to bash scripts, install logic, hooks, and workflow tooling.*

---

## 1. Bash Script Standards

Every script must start with:
```bash
#!/usr/bin/env bash
set -euo pipefail
```

**Why `set -euo pipefail`:**
- `-e`: exit on any error
- `-u`: error on unbound variable (use `${VAR:-default}` or `${ARR[@]+"${ARR[@]}"}` for empty arrays)
- `-o pipefail`: catch failures in piped commands

**Root detection:**
```bash
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
SOURCE_REPO="$(cd "$(dirname "$0")/../.." && pwd)"  # for install.sh-style scripts
```

---

## 2. Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Script files | `kebab-case.sh` | `telegram-notify.sh` |
| Local variables | `snake_case` | `target_dir` |
| Constants / env | `UPPER_SNAKE_CASE` | `PROJECT_ROOT`, `NOTIFY_LEVEL` |
| Directories (template) | `kebab-case` | `pre-commit-quality-gate` |
| OpenSpec change IDs | `kebab-case` | `tdd-enforcement-gate` |

---

## 3. Hook Script Patterns

*For the definitive technical specifications, see:*
- [Provider Hook Integrations](/docs/hooks/index.md)
- [Claude Code](/docs/hooks/claude-hooks.md)
- [Codex](/docs/hooks/codex-hooks.md)
- [Antigravity](/docs/hooks/antigravity-hooks.md)
- [GitHub Copilot CLI](/docs/hooks/copilot-hooks.md)

### Background hooks (notification, logging) — Silent Fail
```bash
# MUST exit 0 even on failure — never block the AI CLI main flow
some_command || true
exit 0
```

### Gate hooks (pre-commit) — Intentional Fail
```bash
# MUST exit 1 to block commit on failure
if [[ $tests_failed -eq 1 ]]; then
    echo "❌ Tests failed." >&2
    exit 1
fi
```

### Tool detection (multi-tool compatibility)
```bash
# Prefer a normalized payload cwd; use Provider env vars only as fallbacks.
PROJECT_DIR="${PAYLOAD_CWD:-${CLAUDE_PROJECT_DIR:-${PWD}}}"
```

---

## 4. Install Script Patterns

**Idempotency** — running install.sh twice must produce the same result:
```bash
# Always safe: rsync overwrites with identical content
rsync -a --itemize-changes "$SRC/" "$DST/"

# Seed (no-overwrite): only on first install (AGENTS.md, project-fill docs)
if [[ ! -f "$TARGET/AGENTS.md" ]]; then
    cp "$COMMON/AGENTS.md" "$TARGET/AGENTS.md"
fi

# Seed docs via rsync flag; managed docs (shared standards) are overwritten separately
rsync -a --ignore-existing "$COMMON/docs/" "$TARGET/docs/"
```

**Empty array guard** (required when using `set -u`):
```bash
# ❌ Fails with set -u when array is empty
for item in "${MY_ARRAY[@]}"; do ...

# ✓ Safe with set -u
for item in "${MY_ARRAY[@]+"${MY_ARRAY[@]}"}"; do ...
```

---

## 5. Prohibited Patterns

- ❌ **No hardcoded absolute paths** — use `PROJECT_ROOT`, `SOURCE_REPO`, or relative paths
- ❌ **No direct edits to `.claude/`, `.agents/`** — these are install targets; edit `template/` instead
- ❌ **No modifying third-party skills** — put overrides in `template/common/.claude/rules/`
- ❌ **No `echo` to stdout in background hooks** — use log files or stderr only
- ❌ **No `curl` or network calls in pre-commit hooks** — hooks must be fast and offline

---

## 6. Output / UX Conventions

Use consistent emoji prefixes for terminal output:

| Prefix | Meaning |
|--------|---------|
| `✓` | Success |
| `❌` | Failure / blocked |
| `⚠️` | Warning (non-blocking) |
| `ℹ️` | Informational / skipped |
| `🔧` | Installing / configuring |
| `🧪` | Running tests |

Error messages go to **stderr** (`>&2`); status/progress goes to **stdout**.
