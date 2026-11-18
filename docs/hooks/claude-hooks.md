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
| Handoff loop routing | `Stop` | 無 | `~/.config/wk-workflow/handoff/handoff-route` |
| Telegram completion | `Stop` | 無 | `~/.config/ai-notify/hooks/telegram-notify.sh` |
| Telegram attention | `Notification` | 無 | `~/.config/ai-notify/hooks/telegram-notify.sh` |

OpenSpec hook 是 fail-soft 相容層；正式 branch-first contract 仍是 Agent 在建立或
繼續 change 前執行 `opsx-branch <change-id>`。Handoff hook 負責在交接輪次結束時進行路由判斷與下一輪分派。

Telegram hook 是背景通知，不會回傳批准或阻擋決策。實作細節與分流規則如下：
- `Notification` 的 `permission_prompt` 進入 **30 秒延遲確認**；以 transcript 尾端未完成之 `tool_use.id` 為身分，30 秒後若已有結果則靜默。
- **特例**：Claude 執行 `AskUserQuestion` 提問工具時，型態亦標為 `permission_prompt`。Hook 會自動向後解析未完成呼叫，若為提問則立即以 `notification:question` 送出，不延遲。
- `idle_prompt`、`agent_needs_input` 等歸類為等待回應，立即送出；登入或額度資訊類（`auth_*`、`quota_*`）則靜默過濾。
- Claude Code 原生在詢問前有約 6 秒的內部緩衝，外部無法消除。

## 安裝與檢查

```bash
bash scripts/workflow/install.sh
bash scripts/handoff/install.sh
bash scripts/notify/telegram/install.sh
```

在 Claude Code 內使用 `/hooks` 檢查載入狀態。重新註冊 Telegram hooks 可執行：

```bash
bash scripts/notify/telegram/update.sh fix-hooks
```

## 相關文件

- [Provider hook 總覽](/docs/hooks/index.md)
- [Telegram Notify 操作手冊](/docs/notify/telegram.md)
- [Notify Hooks 架構手冊](/docs/notify/architecture.md)
- [AI CLI 通知架構與延遲授權流程圖 (SVG)](/docs/diagrams/notify-architecture.svg)
- [Agent Handoff 手冊](/docs/skills/agent-handoff.md)
- [Workflow scripts](/scripts/workflow/README.md)
- [Handoff scripts](/scripts/handoff/README.md)
