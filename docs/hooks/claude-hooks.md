# 🤖 Claude Code Hooks Guide

Hooks are user-defined shell commands executed at specific points in the Claude Code lifecycle. They provide deterministic control over Claude Code's behavior, allowing you to enforce project rules, automate repetitive tasks, and integrate with existing tools.

---

## 📅 Hook Events

| Event | When it fires | Primary Impact |
| :--- | :--- | :--- |
| `SessionStart` | When a session begins or resumes | Inject context |
| `UserPromptSubmit` | Before Claude processes a user prompt | Context injection / Block |
| `PreToolUse` | Before a tool call executes | Block tool / Rewrite args |
| `PermissionRequest` | When a permission dialog appears | Auto-approve/deny |
| `PostToolUse` | After a tool call succeeds | Trigger follow-up (e.g., format) |
| `PostToolUseFailure` | After a tool call fails | Handle errors |
| `Notification` | When Claude Code sends a notification | Forward to OS/Desktop |
| `Stop` | When Claude finishes responding | Block stop to force work (e.g., save) |
| `InstructionsLoaded` | When `CLAUDE.md` or rules are loaded | Initial setup |
| `ConfigChange` | When a config file changes | Audit / React |
| `CwdChanged` | When working directory changes | Update environment (e.g., direnv) |
| `FileChanged` | When a watched file changes | React to file edits |
| `PreCompact` / `PostCompact` | Before/After context compaction | Save state / Re-inject context |
| `SessionEnd` | When a session terminates | Cleanup |

---

## 🛠️ Global Mechanics

### 1. Communication (Stdin/Stdout)
- **Input**: Claude Code passes event-specific JSON to your script's `stdin`.
- **Output (Exit 0)**: Operation continues. Any text on `stdout` is added to Claude's context (for `UserPromptSubmit`, `SessionStart`, etc.).
- **Output (Exit 2)**: Operation is **blocked**. Text on `stderr` is shown to Claude as feedback.
- **Structured JSON**: For advanced control, exit 0 and print a JSON object to `stdout`.

### 2. The "Silence" Rule
If your shell config (`.zshrc` / `.bashrc`) prints text (like "Shell ready"), it will pollute the hook's output and break JSON parsing. 
**Fix**: Wrap `echo` statements in an interactivity check:
```bash
if [[ $- == *i* ]]; then
  echo "Interactive shell message"
fi
```

---

## ⚙️ Configuration

Hooks are configured in `.claude/settings.json` (Project) or `~/.claude/settings.json` (User).

### Example: Auto-format after edits
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | xargs npx prettier --write"
          }
        ]
      }
    ]
  }
}
```

---

## 📝 Local Project Patterns (wk-agent-ops)

### Infinite Loop Prevention (Stop Hook)
When using a `Stop` hook to force extra work, you MUST check the `stop_hook_active` flag to avoid infinite loops.

```bash
#!/usr/bin/env bash
INPUT=$(cat)
IS_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active')

if [ "$IS_ACTIVE" = "true" ]; then
  echo "{}" # Allow stop
  exit 0
fi

# ... your logic to block and force more work ...
echo '{"decision": "block", "reason": "Please save your work first."}'
```

### Multi-Tool Compatibility
Our hooks often detect the environment:
```bash
if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    TOOL_NAME="Claude Code"
    PROJECT_DIR="$CLAUDE_PROJECT_DIR"
elif [[ -n "${GEMINI_PROJECT_DIR:-}" ]]; then
    TOOL_NAME="Gemini CLI"
    PROJECT_DIR="$GEMINI_PROJECT_DIR"
fi
```

---

## 🌍 Advanced Hook Types
- **`type: "prompt"`**: Single-turn LLM evaluation (Haiku by default) for decision making.
- **`type: "agent"`**: Multi-turn subagent with tool access for validation (e.g., run tests before allowing stop).
- **`type: "http"`**: POST event data to a remote URL.

---

## 🎮 Management
- `/hooks`: View all active hooks and their status.
- `disableAllHooks: true`: Disable all hooks via config.
