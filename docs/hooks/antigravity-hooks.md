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
| Completion／failure | `~/.gemini/config/hooks.json` | named `Stop` hook | 僅在 `fullyIdle=true` 時分類結果（`NO_TOOL_CALL` 或 `model_stop` 為成功；`USER_CANCELED` 靜默；其餘為 Task Stopped） |
| Approval observation | `~/.gemini/antigravity-cli/settings.json` | `statusLine.command` | 觀察 `tool_confirmation_pending: true`，套用 30 秒延遲確認與無識別碼合併政策 |
| OpenSpec branch guard | managed `docs/agent-protocol.md` | Agent action | branch 失敗即停止 OpenSpec action |

`Stop` 的 `terminationReason` 在 `NO_TOOL_CALL`（`agy` 1.5.10+）與舊版 `model_stop` 且背景工作結束（`fullyIdle=true`）時分類為 Task Complete；`USER_CANCELED` 靜默不通知；其餘終止原因分類為 Task Stopped 並附帶乾淨的原因標籤。

Approval observer 透過狀態列進行 30 秒延遲確認。實測發現 Antigravity 在等待確認時回報 `tool_confirmation_pending: true`，但等待期間不持續回報；一旦核准或拒絕，該欄位在 0.2～2 秒內直接消失（從不回傳 false），且按 Esc 取消時不會觸發 `Stop`。Hook 以欄位消失作為解除證據，並對無請求 ID 的重複訊號進行合併；已通知之等待需滿 600 秒（`NOTIFY_AUTHORIZATION_REARM_SECONDS`）後的新訊號才重新武裝。若 status-line slot 已被其他指令使用，安裝器會保留原設定並回報 conflict。

## 安裝與狀態

```bash
bash scripts/notify/telegram/install.sh
bash scripts/notify/telegram/update.sh status
```

狀態輸出分開顯示 completion 與 approval，因為兩者使用不同設定機制，且
`statusLine.command` 可能被其他工具占用。

## 相關文件

- [Provider hook 總覽](/docs/hooks/index.md)
- [Telegram Notify 操作手冊](/docs/notify/telegram.md)
- [Notify Hooks 架構手冊](/docs/notify/architecture.md)
- [AI CLI 通知架構與延遲授權流程圖 (SVG)](/docs/diagrams/notify-architecture.svg)
- [OpenSpec、Git 與 Session 邊界](/docs/workflow/concepts.md)
