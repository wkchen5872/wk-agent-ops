## Context

`scripts/telegram-notify/hook.sh` 目前以 ✅/⚠️ 作為狀態圖示，Tool 與 Project 合併在同一行，Event 獨立置底。新格式將狀態改為 🟢/🔴 色彩信號，各欄位各佔一行，訊息與 `#EventName` tag 合併在最後一行。

## Goals / Non-Goals

**Goals:**
- 統一兩種通知（TASK COMPLETE / Action Required）的排版結構
- 以色彩信號圖示（🟢/🔴）取代語意圖示（✅/⚠️）
- 訊息行末附加 `#HookEventName` tag（取代獨立 Event 欄位）
- 提供固定 fallback 文案（Task Complete: `Process finished successfully`；Action Required: `Waiting for user interaction...`）

**Non-Goals:**
- 不更動 NOTIFY_LEVEL 過濾邏輯
- 不更動工具偵測邏輯（GEMINI_PROJECT_DIR 優先）
- 不更動 Telegram API 呼叫方式

## Decisions

### 訊息結構

```
{STATUS_ICON} **{TITLE}**

🤖 {TOOL_NAME}
📂 {PROJECT_NAME}
⏰ {TIMESTAMP}

{MESSAGE} #{HOOK_EVENT_NAME}
```

- `{STATUS_ICON}` = 🟢（TASK COMPLETE）or 🔴（Action Required）
- `{TITLE}` = `TASK COMPLETE` or `Action Required`
- `{MESSAGE}` fallback：TASK COMPLETE → `Process finished successfully`；Action Required → `Waiting for user interaction...`
- `{HOOK_EVENT_NAME}` 從 stdin JSON `hook_event_name` 取得，fallback 為大寫化的 EVENT_TYPE

### Markdown bold 格式

Telegram `parse_mode=Markdown` 支援 `**text**` 作為粗體，標題使用雙星號。

## Risks / Trade-offs

- [Markdown 解析] `**TASK COMPLETE**` 需 Telegram v2 Markdown（已設定 `parse_mode=Markdown`）→ 若出現解析問題可改 `parse_mode=MarkdownV2` 並跳脫特殊字元
- [空 PROJECT_NAME] 若兩個 PROJECT_DIR 皆為空，📂 行只顯示圖示無文字 → 可接受（bug indicator）

## Migration Plan

1. 更新 `scripts/telegram-notify/hook.sh` 訊息組裝邏輯
2. 部署至 `~/.config/ai-notify/hooks/telegram-notify.sh`
3. 手動觸發測試訊息確認格式正確
