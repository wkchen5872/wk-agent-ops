# Provider Hook Integrations

本目錄記錄 `wk-agent-ops` 實際安裝的 AI Provider hooks、設定 ownership 與必要的
runtime 啟用步驟，不複製各 CLI 的完整 hook API。

## 支援矩陣

| Provider | OpenSpec branch fallback | Telegram completion | Telegram attention | 設定範圍 |
|---|---|---|---|---|
| [Claude Code](/docs/hooks/claude-hooks.md) | `PostToolUse` | `Stop` | `Notification` | user-level |
| [Codex](/docs/hooks/codex-hooks.md) | `PostToolUse` | `Stop` | `PermissionRequest` | user-level；另需 trust + enable |
| [Antigravity](/docs/hooks/antigravity-hooks.md) | 無；使用 Agent guard | named `Stop` | `statusLine` observer | user-level |
| [GitHub Copilot CLI](/docs/hooks/copilot-hooks.md) | `postToolUse` | `sessionEnd`（opt-in） | `userPromptSubmitted`（opt-in） | repository-local |

Gemini CLI 不在目前 Provider matrix。Notification installer 只會清除它過去建立的
legacy entries，不會新增 Gemini notification hooks。`entropy-counter` 尚有獨立的
legacy Gemini registration；它不代表 workflow 或 notification 的 Provider 支援。

## Hook families

### Workflow compatibility

`scripts/workflow/install.sh` 部署 OpenSpec branch fallback 與 entropy counter。
Branch fallback 只處理直接 CLI／legacy `openspec new change` 路徑；正式流程由
Agent-mediated `opsx-branch` guard 保證 branch-first。

### Notifications

`scripts/notify/telegram/install.sh` 部署單一 destination hook，再針對各 host runtime
註冊對應事件。所有 notification handlers 都是 fail-soft，不會批准、拒絕或阻擋
Provider action。完整事件分類與安裝方式見 [Telegram Notify](/docs/notify/telegram.md)。

## Ownership 原則

- User-level installer 只移除自己擁有的 command entries。
- Copilot files 位於 repository，安裝前需考慮是否提交給團隊。
- Codex 的 configured、trusted、enabled 是三個不同狀態。
- Antigravity approval observer 不覆蓋既有 `statusLine.command`。
- Hooks 是 compatibility／observation 層，不取代 portable Agent protocol。
