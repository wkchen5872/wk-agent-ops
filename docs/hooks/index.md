# Provider Hook Integrations

本目錄記錄 `wk-agent-ops` 實際安裝的 AI Provider hooks、設定 ownership 與必要的
runtime 啟用步驟，不複製各 CLI 的完整 hook API。

## 支援矩陣

| Provider | OpenSpec branch fallback | Telegram completion | Telegram attention | Handoff loop routing | 設定範圍 |
|---|---|---|---|---|---|
| [Claude Code](/docs/hooks/claude-hooks.md) | `PostToolUse` | `Stop` | `Notification` | `Stop` | user-level |
| [Codex](/docs/hooks/codex-hooks.md) | `PostToolUse` | `Stop` | `PermissionRequest`；同步問題 `PreToolUse` 檢查；非同步問題 `PostToolUse` 通知 | `Stop` | user-level；另需 trust + enable |
| [Antigravity](/docs/hooks/antigravity-hooks.md) | 無；使用 Agent guard | named `Stop` | `statusLine` observer | 無 | user-level |
| [Pi](/docs/hooks/pi-hooks.md) | 無 | global extension `agent_settled`（completion、failure） | `ui_prompt_start`（等待回應；無授權） | global extension `agent_settled`（另以 `project_trust` 信任交接 worktree） | user-level；已開啟的 Session 需 `/reload` |
| [GitHub Copilot CLI](/docs/hooks/copilot-hooks.md) | `postToolUse` | `sessionEnd`（opt-in） | `userPromptSubmitted`（opt-in） | 無 | repository-local |

## Hook families

### Workflow compatibility

`scripts/workflow/install.sh` 部署 OpenSpec branch fallback。
Branch fallback 只處理直接 CLI／legacy `openspec new change` 路徑；正式流程由
Agent-mediated `opsx-branch` guard 保證 branch-first。

### Handoff loop routing

`scripts/handoff/install.sh` 部署多 Agent 交接迴圈的 `Stop` hook（`handoff-route`）。
當支援的 Provider session 結束時，由 `handoff-route` 讀取 `.agent-handoff/` 紀錄並判定是否遞交至下一個角色（如實作轉審查、審查轉收尾）。完整流程見 [Agent Handoff](/docs/skills/agent-handoff.md)。

Pi 沒有 Stop hook 設定檔；同一個 installer 安裝 global extension `~/.pi/agent/extensions/wk-handoff.ts`，在 `agent_settled`（Pi 不再自動重試或續跑）時呼叫 `handoff-route`，subagent 停下時不觸發。它也處理 `project_trust`：只對已信任 repo 的交接 worktree 回答信任，且不保存決定。

### Notifications

`scripts/notify/telegram/install.sh` 部署單一 destination hook，再針對各 host runtime
註冊對應事件；Pi 改由 global extension `~/.pi/agent/extensions/ai-notify.ts` 轉送事件（見 [Pi Extension Integration](/docs/hooks/pi-hooks.md)）。所有 notification handlers 都是 fail-soft，不會批准、拒絕或阻擋
Provider action。完整事件分類與安裝方式見 [Telegram Notify](/docs/notify/telegram.md)。

## Ownership 原則

- User-level installer 只移除自己擁有的 command entries。
- Copilot files 位於 repository，安裝前需考慮是否提交給團隊。
- Codex 的 configured、trusted、enabled 是三個不同狀態。
- Antigravity approval observer 不覆蓋既有 `statusLine.command`。
- Pi extension 只覆寫或刪除第一行帶擁有標記的 `ai-notify.ts`。
- Hooks 是 compatibility／observation 層，不取代 portable Agent protocol。
