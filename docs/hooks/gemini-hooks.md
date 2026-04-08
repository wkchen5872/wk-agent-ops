# ⚓ Gemini CLI Hooks Guide

Hooks are scripts or programs that Gemini CLI executes at specific points in the agentic loop. They allow you to intercept, customize, or validate behavior without modifying the CLI’s source code.

---

## 📅 Hook Events

Hooks are triggered by specific events in Gemini CLI’s lifecycle.

| Event | When It Fires | Primary Impact | Common Use Cases |
| :--- | :--- | :--- | :--- |
| `SessionStart` | When a session begins | Inject Context | Initialize resources, load context |
| `SessionEnd` | When a session ends | Advisory | Clean up, save state |
| `BeforeAgent` | After user submits prompt, before planning | Block Turn / Context | Add context, validate prompts, block turns |
| `AfterAgent` | When agent loop ends | Retry / Halt | Review output, force retry or halt execution |
| `BeforeModel` | Before sending request to LLM | Block Turn / Mock | Modify prompts, swap models, mock responses |
| `AfterModel` | After receiving LLM response | Block Turn / Redact | Filter/redact responses, log interactions |
| `BeforeToolSelection` | Before LLM selects tools | Filter Tools | Filter available tools, optimize selection |
| `BeforeTool` | Before a tool executes | Block Tool / Rewrite | Validate arguments, block dangerous ops |
| `AfterTool` | After a tool executes | Block Result / Context | Process results, run tests, hide results |
| `PreCompress` | Before context compression | Advisory | Save state, notify user |
| `Notification` | When a system notification occurs | Advisory | Forward to desktop alerts, logging |

---

## 🛠️ Global Mechanics

### 1. The "Golden Rule" of JSON
Hooks communicate via `stdin` (Input) and `stdout` (Output).
- **Silence is Mandatory**: Your script **must not** print any plain text to `stdout` other than the final JSON object.
- **Pollution = Failure**: If `stdout` contains non-JSON text (like `echo` logs), parsing will fail.
- **Debug via Stderr**: Use `stderr` for **all** logging and debugging (e.g., `echo "debug" >&2`).

### 2. Exit Codes
| Exit Code | Label | Behavioral Impact |
| :--- | :--- | :--- |
| **0** | **Success** | The `stdout` is parsed as JSON. **Preferred code** for all logic. |
| **2** | **System Block** | **Critical Block**. The target action is aborted. `stderr` is used as the rejection reason. |
| **Other** | **Warning** | Non-fatal failure. A warning is shown, but interaction proceeds. |

---

## 🌍 Environment Variables

Hooks are executed with a sanitized environment containing:
- `GEMINI_PROJECT_DIR`: Absolute path to the project root.
- `GEMINI_SESSION_ID`: Unique ID for the current session.
- `GEMINI_CWD`: Current working directory.

---

## ⚙️ Configuration

Hooks are configured in `.gemini/settings.json` (Project) or `~/.gemini/settings.json` (User).

### Example Configuration
```json
{
  "hooks": {
    "BeforeTool": [
      {
        "matcher": "write_file|replace",
        "hooks": [
          {
            "name": "security-check",
            "type": "command",
            "command": "$GEMINI_PROJECT_DIR/hooks/security.sh",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

---

## 📝 Local Project Patterns (wk-agent-ops)

Refer to `docs/conventions.md` for our bash script standards.

### Background Hooks (Silent Fail)
Must exit 0 even on failure to avoid blocking the main flow.
```bash
#!/usr/bin/env bash
set -euo pipefail
# ... logic ...
some_command || true
exit 0
```

### Gate Hooks (Intentional Fail)
Must exit 2 (or 1 depending on CLI version) to block the action.
```bash
if [[ $security_risk -eq 1 ]]; then
    echo "❌ Security risk detected." >&2
    exit 2
fi
```

### Multi-Tool Compatibility
We often write hooks that detect if they are running under Gemini or Claude:
```bash
if [[ -n "${GEMINI_PROJECT_DIR:-}" ]]; then
    PROJECT_DIR="$GEMINI_PROJECT_DIR"
elif [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    PROJECT_DIR="$CLAUDE_PROJECT_DIR"
fi
```

---

## 🎮 Managing Hooks via CLI

Use these internal commands while chatting with Gemini:
- `/hooks panel`: View active hooks and their status.
- `/hooks enable-all` / `/hooks disable-all`: Global toggle.
- `/hooks enable <name>` / `/hooks disable <name>`: Toggle specific hooks.

---

## 📚 Existing Examples in this Repo
- `hooks/mempal_save_hook.sh`: An example of a "Stop" (or `AfterAgent`) hook that triggers a memory save cycle.
- `hooks/mempal_precompact_hook.sh`: Runs before context compression to preserve state.
