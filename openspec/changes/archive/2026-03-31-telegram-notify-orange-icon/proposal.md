## Why

🔴 紅色圖示在視覺上過於緊迫，容易讓使用者誤以為發生嚴重錯誤。改用 🟠 橙色作為 Action Required 的狀態燈號，傳達「需要注意」而非「緊急警報」的語意。

## What Changes

- `hook.sh` 的 Action Required 標題由 `🔴 **Action Required**` 改為 `🟠 **Action Required**`

## Capabilities

### New Capabilities

_(none)_

### Modified Capabilities

- `telegram-notify-hook`: Action Required 狀態圖示由 🔴 改為 🟠

## Impact

- `scripts/telegram-notify/hook.sh`
- `~/.config/ai-notify/hooks/telegram-notify.sh`（需部署更新版本）
