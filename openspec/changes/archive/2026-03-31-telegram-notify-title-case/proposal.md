## Why

`TASK COMPLETE` 全大寫標題在視覺上過於強烈，與 `Action Required` 的首字大寫格式不一致。統一改為 `Task complete`，讓兩種通知的標題格式一致。

## What Changes

- `hook.sh` 中的 `🟢 **TASK COMPLETE**` 改為 `🟢 **Task complete**`

## Capabilities

### New Capabilities

_(none)_

### Modified Capabilities

- `telegram-notify-hook`: TASK COMPLETE 標題格式由全大寫改為首字大寫

## Impact

- `scripts/telegram-notify/hook.sh`
- `~/.config/ai-notify/hooks/telegram-notify.sh`（需部署更新版本）
