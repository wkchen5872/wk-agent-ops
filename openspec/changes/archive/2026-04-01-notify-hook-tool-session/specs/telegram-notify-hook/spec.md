## MODIFIED Requirements

### Requirement: 工具偵測以 CLI 參數為主、環境變數為輔
hook.sh SHALL 優先以 `$2` 參數取得 TOOL_NAME；`$2` 為空時才 fallback 到環境變數偵測（`GEMINI_PROJECT_DIR` → `GITHUB_COPILOT_SESSION_ID` / event name → `CLAUDE_PROJECT_DIR` → "AI CLI"）。

#### Scenario: $2 參數帶入 tool name
- **WHEN** hook.sh 以 `bash hook.sh sessionEnd "Copilot CLI"` 呼叫
- **THEN** TOOL_NAME="Copilot CLI"，不進行 env var 偵測

#### Scenario: $2 為空，fallback 到 env var（Gemini）
- **WHEN** hook.sh 以 `bash hook.sh AfterAgent` 呼叫（無 $2），`GEMINI_PROJECT_DIR` 存在
- **THEN** TOOL_NAME="Gemini CLI"

#### Scenario: $2 為空，fallback 到 event name（Copilot）
- **WHEN** hook.sh 以 `bash hook.sh sessionEnd` 呼叫（無 $2），env var 皆未設定
- **THEN** TOOL_NAME="Copilot CLI"（由 event name `sessionend` 判定）

#### Scenario: $2 為空，fallback 到 Claude
- **WHEN** hook.sh 以 `bash hook.sh stop` 呼叫（無 $2），`CLAUDE_PROJECT_DIR` 存在
- **THEN** TOOL_NAME="Claude Code"

---

### Requirement: registry.sh 在 hook 指令中帶入 tool name
`register_hook()` 產生的 Claude/Gemini bash 指令 SHALL 包含對應 tool name 作為第二參數。`register_hook_copilot()` 產生的 bash 指令 SHALL 包含 `"Copilot CLI"` 作為第二參數。

#### Scenario: register_hook 產生帶 tool name 的指令（Claude）
- **WHEN** `register_hook` 以 Claude hook path 呼叫
- **THEN** `~/.claude/settings.json` 中的指令包含 `"Claude Code"` 作為第二參數，格式為 `bash "..." stop "Claude Code"`

#### Scenario: register_hook_copilot 產生帶 tool name 的指令
- **WHEN** `register_hook_copilot` 被呼叫
- **THEN** `.github/hooks/hooks.json` 中的 sessionEnd bash 指令包含 `"Copilot CLI"` 作為第二參數

#### Scenario: 重複呼叫 idempotent（含 tool name）
- **WHEN** `register_hook_copilot` 被呼叫兩次
- **THEN** `.github/hooks/hooks.json` 中 sessionEnd 只有一條指令，不重複

---

### Requirement: hook.sh 通知標題帶入 session 識別
hook.sh SHALL 在 Task Complete 與 Action Required 的標題行帶入 session 識別。Session 識別來源依序為：stdin JSON `.session_id`、stdin JSON `.sessionId`、env var `GITHUB_COPILOT_SESSION_ID` 前 8 字元。若為 UUID 格式（含 `-`），顯示前 8 字元加 `#` 前綴；否則直接顯示。無 session 資訊時標題不附加括號。

#### Scenario: Claude session_id 顯示
- **WHEN** stdin JSON 包含 `"session_id": "abc123def456"`, TOOL_NAME=Claude Code, EVENT_TYPE=stop
- **THEN** 標題行為 `🟢 **Task Complete** (#abc123de)`

#### Scenario: Copilot sessionId 顯示
- **WHEN** stdin JSON 包含 `"sessionId": "copilot-xyz"`, TOOL_NAME=Copilot CLI
- **THEN** 標題行為 `🟢 **Task Complete** (copilot-xyz)`（非 UUID 格式，直接顯示）

#### Scenario: 無 session 資訊
- **WHEN** stdin JSON 無 session 欄位，env var 亦無
- **THEN** 標題行為 `🟢 **Task Complete**`（無括號）

#### Scenario: GITHUB_COPILOT_SESSION_ID fallback
- **WHEN** stdin JSON 無 session 欄位，`GITHUB_COPILOT_SESSION_ID=abc12345xyz` 存在
- **THEN** 標題行包含 `(#abc12345)`（取前 8 字元）
