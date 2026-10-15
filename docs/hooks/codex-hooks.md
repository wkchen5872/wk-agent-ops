---
type: Reference
title: Codex Hook Integration
description: Codex hook registration, runtime enablement, and wk-agent-ops event mappings.
tags: [hooks, codex, workflow, notifications]
timestamp: 2026-10-15T00:00:00+08:00
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
| Telegram completion | `Stop` | 無 | `~/.config/ai-notify/hooks/telegram-notify.sh` |
| Telegram approval request + opt-in inspection | `PermissionRequest` | 無 | `~/.config/ai-notify/hooks/telegram-notify.sh` |
| Structured-question inspection | `PreToolUse` | `^(request_user_input|request_user_input_async)$` | `~/.config/ai-notify/hooks/telegram-notify.sh` |
| Async question posted | `PostToolUse` | `^request_user_input_async$` | `~/.config/ai-notify/hooks/telegram-notify.sh` |

OpenSpec compatibility hook 會正規化 Codex payload、忽略失敗的 tool execution，並
把 Git 操作交給 `opsx-branch`。它是安全網；Agent-mediated branch guard 才是
`new`、`ff`、`continue` 的正式成功條件。

Telegram 的 `PermissionRequest` handler 有兩條獨立分支：依共用開關發送既有操作提醒，以及依 Codex 新開關按需檢查 daemon。同步問題的 PreToolUse 啟動檢查；非同步問題略過檢查，改由 PostToolUse 確認 `accepted=true` 後發送「Waiting for Your Response」。這表示題目已送出，Codex 仍可繼續工作。所有 handler 回傳 neutral 結果，不會批准、拒絕或回答。

按需檢查器不使用 LaunchAgent；同 session 共用程序，輪次結束退出。兩個新項目預設關閉，用 `update.sh types` 選擇。授權與同步問題僅涵蓋既有本機 daemon 的 session；非同步題目通知不依賴 daemon。一般文字問句不偵測。

## 檢查與修復

```bash
bash scripts/notify/telegram/update.sh status
bash scripts/notify/telegram/update.sh fix-hooks
```

`status` 可確認 owned commands、依賴與 daemon 連線；無法讀取 `/hooks` 的 trust 與 checkbox
狀態，也不把連線成功等同於人工等待端到端驗收。重新註冊後需重新啟動 Codex session，再檢查 `/hooks`。

## 相關文件

- [Provider hook 總覽](/docs/hooks/index.md)
- [Telegram Notify](/docs/notify/telegram.md)
- [Workflow scripts](/scripts/workflow/README.md)

# Citations

[1] [Codex hooks](https://learn.chatgpt.com/docs/hooks)
[2] [Codex App Server](https://learn.chatgpt.com/docs/app-server)
