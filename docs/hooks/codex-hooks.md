---
type: Reference
title: Codex Hook Integration
description: Codex hook registration, runtime enablement, and wk-agent-ops event mappings.
tags: [hooks, codex, workflow, notifications]
timestamp: 2026-11-16T00:00:00+08:00
---

# Codex Hook Integration

## 設定位置與兩階段啟用

`wk-agent-ops` 將 Codex hooks 寫入 `~/.codex/hooks.json`。寫入成功只代表
configured；每個 hook 還必須在 Codex `/hooks` 面板中：

1. 顯示為 `Trusted`。
2. 將 `[ ] Hook 1` 切換為 `[x] Hook 1`。

面板會自動保存狀態。未信任或未勾選時，設定檔存在但 command 不會執行。

## 本專案使用的事件

| 功能 | 事件 | Matcher | Script |
|---|---|---|---|
| OpenSpec branch compatibility | `PostToolUse` | `Bash` | `~/.config/wk-workflow/hooks/openspec-branch-creator.sh` |
| Handoff loop routing | `Stop` | 無 | `~/.config/wk-workflow/handoff/handoff-route` |
| Telegram completion | `Stop` | 無 | `~/.config/ai-notify/hooks/telegram-notify.sh` |
| Telegram approval request + opt-in inspection | `PermissionRequest` | 無 | `~/.config/ai-notify/hooks/telegram-notify.sh` |
| Structured-question inspection | `PreToolUse` | `^(request_user_input|request_user_input_async)$` | `~/.config/ai-notify/hooks/telegram-notify.sh` |
| Async question posted | `PostToolUse` | `^request_user_input_async$` | `~/.config/ai-notify/hooks/telegram-notify.sh` |

OpenSpec compatibility hook 會正規化 Codex payload、忽略失敗的 tool execution，並
把 Git 操作交給 `opsx-branch`。它是安全網；Agent-mediated branch guard 才是
`new`、`ff`、`continue` 的正式成功條件。

Handoff loop routing hook 在輪次結束時判定交接狀態。若 roles 設定為遠端 PR 交付，`scripts/handoff/install.sh` 會額外提供 `~/.codex/handoff-net.config.toml` 網路沙盒 profile，讓收尾角色在必要時獲取對外網路權限進行 git push 與 PR 建立。

Telegram 的 `PermissionRequest` 不再當下發出即時通知（徹底消除 auto_review 在 5～10 秒內放行時產生的 99.5% 假警報），而是啟動按需檢查器並套用 **30 秒延遲確認**：
- **Daemon 可連線且載入該 Session**：監聽 `waitingOnApproval` 旗標；若在 30 秒內自動放行則安靜結束，超過 30 秒仍未解除才發送確認等待通知。
- **Daemon 不可用或 CLI 啟動的 Session（回報 `notLoaded`）**：保留請求等待 30 秒後探針讀取 Session 紀錄（`rollout-*-<session_id>.jsonl`）；若已有執行輸出或任務結束則靜默，若仍無結果則發送「Approval Status Unknown（無法確認）」通知。

同步問題由 PreToolUse 啟動檢查；非同步問題由 PostToolUse 在確認 `accepted=true` 後立即發送「Waiting for Your Response」（表示題目已送出，Codex 仍可繼續工作，不需 daemon）。所有 handler 均回傳 neutral `{}`，絕不干預或批准工具執行。按需檢查器不使用 LaunchAgent，同 session 共用程序，輪次結束自動退出，並自動清理超過 7 天的過期狀態檔。此外，Codex hook 輸入之 payload 帶有必填 `model` 欄位，檢查器會將其快取在 `state/codex-<24 hex>.model.json`，於 Telegram 通知送出時自動載入，顯示為 `🤖 Codex (gpt-6.1-terra)` 等原始模型 ID。

## 顯示名稱

`/hooks` 以 handler 的 `statusMessage` 作為名稱，未填時顯示 `Unnamed hook`。
本專案註冊的六個 handler 使用以下預設名稱：

| 功能 | 事件 | 預設 `statusMessage` | 安裝或修復入口（從本 repo 根目錄執行） |
|---|---|---|---|
| Telegram 完成 | `Stop` | `Telegram 完成通知` | `bash scripts/notify/telegram/install.sh`、`update.sh fix-hooks` |
| Telegram 操作確認與檢查 | `PermissionRequest` | `Telegram 操作確認與等待檢查` | 同上 |
| Telegram 同步問題檢查 | `PreToolUse` | `Telegram 同步問題等待檢查` | 同上 |
| Telegram 非同步問題 | `PostToolUse` | `Telegram 非同步問題通知` | 同上 |
| OpenSpec 分支相容 hook | `PostToolUse` | `OpenSpec 規劃分支檢查` | `bash scripts/workflow/openspec-branch-creator/install.sh` |
| Agent 交接 | `Stop` | `Agent 交接派送` | `bash scripts/handoff/install.sh` |

`statusMessage` 與 `type`、`command` 放在同一個 handler 物件，而不是 matcher group：

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.config/wk-workflow/handoff/handoff-route\"",
            "timeout": 10,
            "statusMessage": "Agent 交接派送"
          }
        ]
      }
    ]
  }
}
```

- 一般安裝與重跑：只在相同事件、相同 command 的本工具 handler 名稱缺少、為 null、
  空字串或純空白時補上預設值；非空白的自訂名稱、其他欄位與第三方 hooks 保留，不新增重複項目。
- `update.sh fix-hooks`：先移除再重建 Telegram handler，因此自訂名稱會重設為預設值；其他 hooks 保留。
- 只有 Codex handler 寫入此欄位；Claude Code、Antigravity 與 Copilot 的註冊格式不變。
- 新增或改變名稱會改變 hook 定義。重新開啟 Codex session，在 `/hooks` 核對名稱、重新信任並確認勾選；
  安裝程式不修改 trust 或啟用狀態。

## 檢查與修復

```bash
bash scripts/notify/telegram/update.sh status
bash scripts/notify/telegram/update.sh fix-hooks
```

`status` 可確認 owned commands、依賴與 daemon 連線；無法讀取 `/hooks` 的 trust 與 checkbox
狀態，也不把連線成功等同於人工等待端到端驗收。重新註冊後需重新啟動 Codex session，再檢查 `/hooks`。

## 相關文件

- [Provider hook 總覽](/docs/hooks/index.md)
- [Agent Handoff 手冊](/docs/skills/agent-handoff.md)
- [Telegram Notify](/docs/notify/telegram.md)
- [Workflow scripts](/scripts/workflow/README.md)
- [Handoff scripts](/scripts/handoff/README.md)
- [Codex hooks 官方文件](https://learn.chatgpt.com/docs/hooks)
- [Codex App Server](https://learn.chatgpt.com/docs/app-server)
