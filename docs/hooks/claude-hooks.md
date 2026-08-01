---
type: Reference
title: Claude Code Hook Integration
description: Claude Code hook locations, events, and wk-agent-ops ownership boundaries.
tags: [hooks, claude-code, workflow, notifications]
timestamp: 2026-08-01T00:00:00+08:00
---

# Claude Code Hook Integration

本文件只描述 `wk-agent-ops` 實際安裝的 Claude Code hooks；Provider 的完整事件
目錄不在此複製，避免與 CLI 版本脫節。

## 設定位置

本專案的 user-level hooks 寫入 `~/.claude/settings.json`。安裝器只增刪自己擁有
的 command，不會覆蓋其他 hook groups。

## 本專案使用的事件

| 功能 | 事件 | Matcher | Script |
|---|---|---|---|
| OpenSpec branch compatibility | `PostToolUse` | `Bash` | `~/.config/wk-workflow/hooks/openspec-branch-creator.sh` |
| Telegram completion | `Stop` | 無 | `~/.config/ai-notify/hooks/telegram-notify.sh` |
| Telegram attention | `Notification` | 無 | `~/.config/ai-notify/hooks/telegram-notify.sh` |

OpenSpec hook 是 fail-soft 相容層；正式 branch-first contract 仍是 Agent 在建立或
繼續 change 前執行 `opsx-branch <change-id>`。Telegram hook 也是背景通知，不會
回傳批准或阻擋決策。

## 安裝與檢查

```bash
bash scripts/workflow/install.sh
bash scripts/notify/telegram/install.sh
```

在 Claude Code 內使用 `/hooks` 檢查載入狀態。重新註冊 Telegram hooks 可執行：

```bash
bash scripts/notify/telegram/update.sh fix-hooks
```

## 相關文件

- [Provider hook 總覽](/docs/hooks/index.md)
- [Telegram Notify](/docs/notify/telegram.md)
- [Workflow scripts](/scripts/workflow/README.md)
