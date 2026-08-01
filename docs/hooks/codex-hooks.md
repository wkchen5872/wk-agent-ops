---
type: Reference
title: Codex Hook Integration
description: Codex hook registration, runtime enablement, and wk-agent-ops event mappings.
tags: [hooks, codex, workflow, notifications]
timestamp: 2026-08-01T00:00:00+08:00
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
| Telegram approval request | `PermissionRequest` | 無 | `~/.config/ai-notify/hooks/telegram-notify.sh` |

OpenSpec compatibility hook 會正規化 Codex payload、忽略失敗的 tool execution，並
把 Git 操作交給 `opsx-branch`。它是安全網；Agent-mediated branch guard 才是
`new`、`ff`、`continue` 的正式成功條件。

Telegram 的 `PermissionRequest` handler 只送出 action-required 通知並回傳 neutral
結果，不會代替使用者批准或拒絕。

## 檢查與修復

```bash
bash scripts/notify/telegram/update.sh status
bash scripts/notify/telegram/update.sh fix-hooks
```

`status` 只能確認 owned commands 已寫入，無法讀取 `/hooks` 的 trust 與 checkbox
狀態。重新註冊後需重新啟動 Codex session，再檢查 `/hooks`。

## 相關文件

- [Provider hook 總覽](/docs/hooks/index.md)
- [Telegram Notify](/docs/notify/telegram.md)
- [Workflow scripts](/scripts/workflow/README.md)
