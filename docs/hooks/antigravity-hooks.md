---
type: Reference
title: Antigravity CLI Hook Integration
description: Antigravity completion and approval notification integration plus branch-guard boundaries.
tags: [hooks, antigravity, workflow, notifications]
timestamp: 2026-08-01T00:00:00+08:00
---

# Antigravity CLI Hook Integration

Antigravity 目前只由 Telegram notification 使用原生 hook／status-line integration。
OpenSpec branch coordination 不安裝廣泛的 shell interception hook，而由 managed
Agent protocol 執行 `opsx-branch <change-id>`。

## 本專案使用的設定

| 功能 | 設定位置 | 事件／狀態 | 行為 |
|---|---|---|---|
| Completion／failure | `~/.gemini/config/hooks.json` | named `Stop` hook | 僅在 `fullyIdle=true` 時分類結果 |
| Approval observation | `~/.gemini/antigravity-cli/settings.json` | `statusLine.command` | 觀察 `tool_confirmation_pending` 的 false → true transition |
| OpenSpec branch guard | managed `docs/agent-protocol.md` | Agent action | branch 失敗即停止 OpenSpec action |

`Stop` 的 `terminationReason=model_stop` 會被分類為 completion；其他終止原因分類為
failure。Approval observer 只在 status-line slot 未被其他 command 使用時安裝；若
已有不同 command，安裝器會保留原設定並回報 conflict。

Status-line observer 以 session marker 去除重複通知。它只觀察等待狀態，不批准
tool call，也不改變 Antigravity 的執行決策。

## 安裝與狀態

Telegram installer 在偵測到 `agy` 或 Antigravity 設定目錄時自動嘗試註冊：

```bash
bash scripts/notify/telegram/install.sh
bash scripts/notify/telegram/update.sh status
```

狀態輸出分開顯示 completion 與 approval，因為兩者使用不同設定機制，且
`statusLine.command` 可能被其他工具占用。

## 相關文件

- [Provider hook 總覽](/docs/hooks/index.md)
- [Telegram Notify](/docs/notify/telegram.md)
- [OpenSpec、Git 與 Session 邊界](/docs/workflow/concepts.md)
