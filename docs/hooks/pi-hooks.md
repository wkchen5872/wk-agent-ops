---
type: Reference
title: Pi Extension Integration
description: How Telegram notifications reach Pi through a managed global extension, which sessions notify, and how it is installed and removed.
tags: [hooks, pi, notifications, telegram]
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-19T17:44:06+08:00 }
---

# Pi Extension Integration

Pi 沒有可登記指令的 hook 設定檔，只能用 extension。`~/.pi/agent/extensions/*.ts` 會在 Pi 啟動時自動載入
（`PI_CODING_AGENT_DIR` 可改變 `~/.pi/agent` 這個根目錄）。本專案為 Pi 安裝兩個彼此獨立的 extension：

| 檔案 | 安裝者 | 用途 |
|---|---|---|
| `ai-notify.ts` | `scripts/notify/telegram/install.sh`、`update.sh fix-hooks` | Telegram 通知（本文件） |
| `wk-handoff.ts` | `scripts/handoff/install.sh` | 交接迴圈路由，見 [Agent Handoff](/docs/skills/agent-handoff.md) |

## 通知事件對應

extension（來源 `scripts/notify/pi/ai-notify.ts`）只做事件轉接，以背景程序呼叫共用的
`~/.config/ai-notify/hooks/telegram-notify.sh <event> Pi`；分類、開關、範本與隱私規則都在通知腳本與
`scripts/notify/telegram/events.tsv`。

| Pi 事件 | 條件 | 送出的事件 | 通知 |
|---|---|---|---|
| `agent_settled` | 未中止，最後一則 assistant 回覆不是錯誤 | `pi-stop`，`stop_reason=completed` | 🟢 Task Complete（工作結束） |
| `agent_settled` | 最後一則 assistant 回覆以錯誤結束 | `pi-stop`，`stop_reason=error` | 🔴 Task Stopped，原因 `error`（異常停止） |
| `agent_settled` | 使用者中止（例如 Esc） | `pi-stop`，`stop_reason=aborted` | 不通知 |
| `ui_prompt_start` | 執行中（`agent_start` 到 `agent_settled` 之間） | `pi-question` | 🟡 Waiting for Your Response（等待回應） |

- `agent_end` 之後 Pi 仍可能自動重試、壓縮後重試或接續佇列訊息，所以只在 `agent_settled` 送出；
  重試成功只會有一則工作結束，不會先送異常停止。
- `ui_prompt_start` 涵蓋 `ctx.ui.select/confirm/input/editor/custom`，例如 pstack `ask_user_question` 的選單。
  Pi 會把重疊的提示合併成一段，所以同一段等待只送一則。閒置時自己打開的選單不通知。
- 送出的 JSON 只有 `hook_event_name`、`session_id`、`cwd`、`stop_reason` 與 `model`（`ctx.model.id`，沒有時省略）。
  提示內容、選項、回答與錯誤原文都不會離開 Pi。
- Telegram 標題帶 Pi Session ID 的前八碼，例如 `(#c0ffee12)`；工具行顯示當下的 model，例如 `🤖 Pi (gpt-6.1-sol)`。
- 不支援授權要求（Pi 沒有授權機制）；只用文字提問、沒有開 UI 的情況不偵測。

## 哪些 session 會通知

只有互動的主 session：`ctx.mode` 為 `tui`，且環境沒有 `PI_SUBAGENT_PARENT_SESSION`。不用 `ctx.hasUI`，因為 RPC 模式的 `hasUI` 也是真，即使驅動它的客戶端沒有任何畫面。

| 執行方式 | 通知 |
|---|---|
| Pi TUI（包含 Xirp 前景與背景開啟的 session，皆為不帶模式參數的 `pi`） | 會 |
| `pi -p`（print）、`--mode json`、`--mode rpc` | 不會（`ctx.mode` 不是 `tui`） |
| pstack subagent（`pi --mode rpc`，帶 `PI_SUBAGENT_PARENT_SESSION`） | 不會 |

通知在 detached 子程序中執行，Pi 不等待；通知腳本不存在、啟動失敗或 Telegram 失敗都被吞掉，不影響 Pi。

## 安裝、更新與移除

前置條件：已執行過 Telegram 通知 installer，且機器上有 `pi` 指令或 Pi agent 目錄。

1. 在 repo 根目錄安裝或修復：

   ```bash
   bash scripts/notify/telegram/update.sh fix-hooks
   ```

   預期輸出包含 `✓ Installed Pi extension at …/extensions/ai-notify.ts (run /reload in open Pi sessions)`。
   重跑只會留下一份與來源相同的檔案。
2. 已開啟的 Pi session 執行 `/reload`（或重開）才會載入。
3. 確認狀態：

   ```bash
   bash scripts/notify/telegram/update.sh status
   ```

   `Pi:` 一行為下列之一：`registered`、`not registered`（偵測到 Pi 但尚未安裝）、`not detected`、
   `unavailable (existing ai-notify.ts is a link or lacks the ownership marker)`。

擁有標記是檔案第一行 `// managed by wk-agent-ops ai-notify`。installer 只覆寫或刪除帶標記的一般檔案；
同名但沒有標記的檔案，以及任何符號連結（包含斷鏈與指向帶標記檔案的連結），都保留不動，連結的目的檔也不會被寫入，
安裝時在 stderr 警告，`status` 顯示 `unavailable`。

移除：`bash scripts/notify/telegram/uninstall.sh` 會刪除帶標記的 `ai-notify.ts`，同目錄其他 extension 不動。
也可以手動刪除該檔案後在 Pi 執行 `/reload`。

## 常見問題

**Pi 完成一輪卻沒有通知**

- `update.sh status` 的 `Pi:` 不是 `registered` → 執行 `fix-hooks`，再 `/reload`。
- 用 `pi -p` 或 subagent 執行 → 設計上不通知。
- 按了 Esc → 中止不通知。
- `NOTIFY_COMPLETION=false` 或 `NOTIFY_LEVEL=attention_required` → 工作結束不送，見 [Telegram Notify](/docs/notify/telegram.md)。

**`status` 顯示 `unavailable`**

`~/.pi/agent/extensions/ai-notify.ts` 是你自己的檔案或符號連結。改名或移走後重跑 `fix-hooks`。
