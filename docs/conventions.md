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
- [Gemini CLI Hooks Guide](hooks/gemini-hooks.md)
- [Claude Code Hooks Guide](hooks/claude-hooks.md)
- [GitHub Copilot Hooks Guide](hooks/copilot-hooks.md)

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
# Priority: Gemini → Claude Code → fallback PWD
if [[ -n "${GEMINI_PROJECT_DIR:-}" ]]; then
    TOOL_NAME="Gemini CLI"
    PROJECT_DIR="$GEMINI_PROJECT_DIR"
elif [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    TOOL_NAME="Claude Code"
    PROJECT_DIR="$CLAUDE_PROJECT_DIR"
else
    TOOL_NAME="AI CLI"
    PROJECT_DIR="$(pwd)"
fi
```

---

## 4. Install Script Patterns

**Idempotency** — running install.sh twice must produce the same result:
```bash
# Always safe: rsync overwrites with identical content
rsync -a --itemize-changes "$SRC/" "$DST/"

# No-overwrite: only on first install (AGENTS.md, docs/)
if [[ ! -f "$TARGET/AGENTS.md" ]]; then
    cp "$COMMON/AGENTS.md" "$TARGET/AGENTS.md"
fi

# No-overwrite via rsync flag
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
- ❌ **No direct edits to `.claude/`, `.agent/`** — these are install targets; edit `template/` instead
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
