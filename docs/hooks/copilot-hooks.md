# 🐙 GitHub Copilot Hooks Guide

Hooks allow you to execute custom shell commands at strategic points in a Copilot agent's workflow. They enable context-aware automation, such as programmatically approving/denying tool executions, scanning for secrets, or logging interactions for auditing.

---

## 📅 Hook Events

| Event | When it fires | Primary Impact |
| :--- | :--- | :--- |
| `sessionStart` | When a new session begins or resumes | Initialize environment, log startup |
| `sessionEnd` | When the session completes or is terminated | Cleanup, archive logs, notify |
| `userPromptSubmitted` | When a user submits a prompt | Audit logging, usage analysis |
| `preToolUse` | Before a tool call (bash, edit, view) | **Approve or deny** tool executions |
| `postToolUse` | After a tool completes (success or failure) | Log results, monitor metrics |
| `agentStop` | When the main agent finishes responding | Finalize turn |
| `subagentStop` | When a subagent completes | Handle subagent results |
| `errorOccurred` | When an error occurs | Log errors for debugging, notify |

---

## 🛠️ Global Mechanics

### 1. Communication (JSON Input)
Hooks receive detailed JSON information about agent actions via `stdin`.

### 2. Decision Making (Exit Codes)
- **Exit 0**: Success. The operation proceeds.
- **Non-zero Exit**: Failure or Block. Depending on the hook type, this may block the operation (especially in `preToolUse`).

---

## ⚙️ Configuration

Hooks are defined in JSON files located in `.github/hooks/*.json`.

### Configuration Schema
```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      {
        "type": "command",
        "bash": "./scripts/security-check.sh",
        "powershell": "./scripts/security-check.ps1",
        "cwd": "scripts",
        "timeoutSec": 15
      }
    ]
  }
}
```

| Property | Required | Description |
| :--- | :--- | :--- |
| `type` | Yes | Must be `"command"`. |
| `bash` | Yes (Unix) | Command or path to the script. |
| `powershell` | Yes (Win) | Command or path to the script. |
| `cwd` | No | Working directory relative to repo root. |
| `env` | No | Additional environment variables. |
| `timeoutSec` | No | Default is 30 seconds. |

---

## 📝 Local Project Patterns (wk-agent-ops)

### Tool Detection
Our hooks should be compatible across different AI CLIs:
```bash
if [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${GITHUB_COPILOT_CLI:-}" ]]; then
    TOOL_NAME="GitHub Copilot"
elif [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    TOOL_NAME="Claude Code"
elif [[ -n "${GEMINI_PROJECT_DIR:-}" ]]; then
    TOOL_NAME="Gemini CLI"
fi
```

### Silence and Logging
- Send logs/debug info to `stderr` or a log file.
- Avoid polluting `stdout` if the tool expects clean output.

---

## 🛡️ Security & Performance
- **Validate Input**: Sanitize any data processed by hooks.
- **Escape Commands**: Use proper shell escaping to prevent injection.
- **Timeouts**: Keep execution under 5 seconds to ensure responsiveness.
- **No Secrets**: Never log sensitive tokens or passwords.
